/**
 * Market Intelligence — catalog figure matcher (Sprint 2 Step 2).
 *
 * Deterministic normalized-title → target-figure scoring with hard rejects.
 * Implements MATCHER_DESIGN_REVIEW.md Sections 2–6.
 *
 * Pure functions only — no I/O, network, or side effects.
 */

import { structurallyNormalizeTitle } from './_title_normalizer.mjs';
import { extractSeriesDistinctive } from './_search_term_derivation.mjs';

/** Global default acceptance threshold (MATCHER_DESIGN_REVIEW §6). */
export const DEFAULT_MATCH_THRESHOLD = 0.75;

/** Scoring weights — sum to 1.0 at full match. */
export const MATCH_WEIGHTS = Object.freeze({
  brandMatch: 0.15,
  seriesMatchFull: 0.3,
  seriesMatchPartial: 0.15,
  figureIdentity: 0.4,
  marketAliasBonus: 0.1,
  secretConsistentBonus: 0.05,
});

/** Secret/chase indicator tokens preserved by the normalizer. */
export const SECRET_INDICATOR_TOKENS = Object.freeze([
  'secret',
  'chase',
  'hidden',
  '隐藏',
]);

export const SECRET_INDICATOR_PHRASES = Object.freeze(['1/144', '1:72']);

/** Tier 1 product-type hard rejects (unconditional). */
export const PRODUCT_TYPE_TIER1 = Object.freeze([
  'storage bag',
  'pin only',
  'keychain',
  'key chain',
  'phone strap',
  'bag charm',
  'charm',
  'lanyard',
  'display case',
  'poster',
  'sticker',
  'mouse pad',
  'notebook',
  'wallet',
  'coin purse',
]);

/** Tier 2 product-type terms — reject when figure identity is weak. */
export const PRODUCT_TYPE_TIER2 = Object.freeze([
  'badge',
  'card',
  'folder',
  'towel',
]);

export const FIGURE_PRODUCT_NOUNS = Object.freeze(['figure', 'plush', 'vinyl']);

const SERIES_BOILERPLATE_PATTERN =
  /\b(blind box|vinyl plush pendant|vinyl plush|vinyl face|the monsters|pop mart|series|figure|toy|doll|plush|pendant)\b/g;


/**
 * @typedef {Object} MatcherMetadataOverrides
 * @property {readonly string[]} [marketAliases]
 * @property {number | null} [matchThreshold]
 */

/**
 * @typedef {Object} MatcherContext
 * @property {string} figureId
 * @property {string} seriesId
 * @property {string} brandId
 * @property {boolean} isSecret
 * @property {readonly string[]} brandTokens
 * @property {readonly string[]} figureNameTokens
 * @property {readonly string[]} catalogFigureAliasTokens
 * @property {readonly string[]} seriesAliasPhrases
 * @property {readonly string[]} ipAnchorTokens
 * @property {readonly string[]} siblingFigureTokens
 * @property {readonly { seriesId: string, phrases: readonly string[] }[]} conflictingSeries
 * @property {string} seriesDistinctivePhrase
 */

/**
 * @typedef {Object} MatcherSignals
 * @property {boolean} brandMatch
 * @property {boolean} seriesMatchFull
 * @property {boolean} seriesMatchPartial
 * @property {number} seriesMatchScore
 * @property {boolean} figureNameMatch
 * @property {boolean} marketAliasMatch
 * @property {boolean} figureIdentityMatch
 * @property {boolean} secretSignalConsistent
 * @property {readonly string[]} matchedMarketAliasTokens
 * @property {readonly string[]} matchedCatalogFigureTokens
 * @property {readonly string[]} matchedSiblingTokens
 */

/**
 * @typedef {Object} MatcherResult
 * @property {boolean} matched
 * @property {number} score
 * @property {readonly string[]} reasons
 * @property {string | null} rejectReason
 * @property {string | null} figureId
 * @property {MatcherSignals} signals
 * @property {number} effectiveThreshold
 */

/**
 * Build matcher context from catalog records (catalog-derived, not hand-authored).
 *
 * @param {object} params
 * @param {object} params.targetFigure — { id, displayName, seriesId, brandId, isSecret, aliases? }
 * @param {object} params.series — { id, displayName, aliases? }
 * @param {object} params.brand — { id, displayName, aliases? }
 * @param {object} [params.ip] — { id, displayName, aliases? }
 * @param {readonly object[]} params.siblingFigures — same-series figures excluding target
 * @param {readonly object[]} params.allSeries — catalog series rows for mismatch detection
 * @returns {MatcherContext}
 */
export function buildMatcherContext({
  targetFigure,
  series,
  brand,
  ip,
  siblingFigures,
  allSeries,
}) {
  const brandTokens = uniqueNormalizedTokens([
    brand.displayName,
    ...(brand.aliases ?? []),
    'pop mart',
    'popmart',
  ]);

  const figureNameTokens = tokenizeDisplayName(targetFigure.displayName);
  const catalogFigureAliasTokens = uniqueNormalizedTokens(
    targetFigure.aliases ?? [],
  );

  const seriesDistinctivePhrase = structurallyNormalizeTitle(
    extractSeriesDistinctive(series, ip ?? {}),
  );

  const seriesAliasPhrases = uniqueNormalizedPhrases([
    series.displayName,
    ...(series.aliases ?? []),
  ]);

  const ipAnchorTokens = uniqueNormalizedTokens([
    ip?.displayName,
    ...(ip?.aliases ?? []),
  ]);

  const siblingFigureTokens = uniqueNormalizedTokens(
    siblingFigures.flatMap((figure) => [
      figure.displayName,
      ...(figure.aliases ?? []),
    ]),
  );

  const conflictingSeries = (allSeries ?? [])
    .filter((row) => row.id !== series.id)
    .map((row) => ({
      seriesId: row.id,
      phrases: deriveDistinctiveSeriesPhrases(row),
    }))
    .filter((entry) => entry.phrases.length > 0);

  return {
    figureId: targetFigure.id,
    seriesId: series.id,
    brandId: brand.id,
    isSecret: Boolean(targetFigure.isSecret),
    brandTokens,
    figureNameTokens,
    catalogFigureAliasTokens,
    seriesAliasPhrases,
    ipAnchorTokens,
    siblingFigureTokens,
    conflictingSeries,
    seriesDistinctivePhrase,
  };
}

/**
 * Score a normalized listing title against a target catalog figure.
 *
 * @param {string} normalizedTitle — output of normalizeMarketTitle
 * @param {MatcherContext} context
 * @param {MatcherMetadataOverrides} [metadataOverrides]
 * @returns {MatcherResult}
 */
export function matchCatalogFigure(
  normalizedTitle,
  context,
  metadataOverrides = {},
) {
  const title = typeof normalizedTitle === 'string' ? normalizedTitle.trim() : '';
  const effectiveThreshold =
    metadataOverrides.matchThreshold ?? DEFAULT_MATCH_THRESHOLD;
  const marketAliasTokens = normalizeAliasList(
    metadataOverrides.marketAliases ?? [],
  );

  if (!title || !context?.figureId) {
    return buildResult({
      matched: false,
      score: 0,
      rejectReason: 'invalidInput',
      figureId: null,
      effectiveThreshold,
      reasons: ['invalidInput'],
      signals: emptySignals(),
    });
  }

  const tokens = tokenize(title);
  const targetFigureTokens = collectTargetFigureTokens(
    context,
    marketAliasTokens,
  );
  const matchedSiblingTokens = matchSiblingTokens(
    tokens,
    context.siblingFigureTokens,
  );
  const matchedTargetTokens = matchWholeTokens(tokens, targetFigureTokens);
  const targetFigureMatched = matchedTargetTokens.length > 0;

  const hardReject = detectHardReject({
    title,
    tokens,
    context,
    marketAliasTokens,
    targetFigureTokens,
    targetFigureMatched,
    matchedSiblingTokens,
  });

  if (hardReject) {
    return buildResult({
      matched: false,
      score: 0,
      rejectReason: hardReject,
      figureId: null,
      effectiveThreshold,
      reasons: buildHardRejectReasons(hardReject, {
        matchedSiblingTokens,
        matchedTargetTokens,
      }),
      signals: emptySignals(),
    });
  }

  const signals = computeSignals({
    title,
    tokens,
    context,
    marketAliasTokens,
    targetFigureMatched,
    matchedTargetTokens,
  });

  const score = computeScore(signals);
  const gateReasons = evaluateAcceptanceGates(signals);
  const matched =
    gateReasons.length === 0 && score >= effectiveThreshold;

  const reasons = buildScoreReasons({
    signals,
    score,
    effectiveThreshold,
    matched,
    gateReasons,
  });

  return buildResult({
    matched,
    score,
    rejectReason: matched
      ? null
      : gateReasons[0] ?? 'belowThreshold',
    figureId: matched ? context.figureId : null,
    effectiveThreshold,
    reasons,
    signals,
  });
}

/**
 * @param {object} params
 * @returns {MatcherResult}
 */
function buildResult(params) {
  return {
    matched: params.matched,
    score: roundScore(params.score),
    reasons: params.reasons,
    rejectReason: params.rejectReason,
    figureId: params.figureId,
    signals: params.signals,
    effectiveThreshold: params.effectiveThreshold,
  };
}

/**
 * @returns {MatcherSignals}
 */
function emptySignals() {
  return {
    brandMatch: false,
    seriesMatchFull: false,
    seriesMatchPartial: false,
    seriesMatchScore: 0,
    figureNameMatch: false,
    marketAliasMatch: false,
    figureIdentityMatch: false,
    secretSignalConsistent: false,
    matchedMarketAliasTokens: [],
    matchedCatalogFigureTokens: [],
    matchedSiblingTokens: [],
  };
}

/**
 * @param {object} params
 * @returns {string | null}
 */
function detectHardReject(params) {
  const {
    title,
    tokens,
    context,
    targetFigureTokens,
    targetFigureMatched,
    matchedSiblingTokens,
  } = params;

  if (detectSeriesMismatch(title, context)) {
    return 'seriesMismatch';
  }

  if (
    targetFigureMatched &&
    matchedSiblingTokens.length > 0
  ) {
    return 'crossFigureContamination';
  }

  if (
    !targetFigureMatched &&
    matchedSiblingTokens.length > 0
  ) {
    return 'wrongFigureName';
  }

  if (detectSecretMismatch(title, context.isSecret)) {
    return 'secretMismatch';
  }

  if (detectProductTypeTier1(title)) {
    return 'productTypeReject';
  }

  const figureNameMatch = hasFigureNameMatch(tokens, context);
  const marketAliasMatch = hasMarketAliasMatch(tokens, params.marketAliasTokens);
  const figureIdentityMatch = figureNameMatch || marketAliasMatch;

  if (detectProductTypeTier2(title, tokens, figureIdentityMatch)) {
    return 'productTypeReject';
  }

  return null;
}

/**
 * @param {string} title
 * @param {MatcherContext} context
 * @returns {boolean}
 */
function detectSeriesMismatch(title, context) {
  for (const entry of context.conflictingSeries) {
    for (const phrase of entry.phrases) {
      if (phrase.length < 3) continue;
      if (hasPhrase(title, phrase)) {
        return true;
      }
    }
  }
  return false;
}

/**
 * @param {string} title
 * @param {boolean} isSecret
 * @returns {boolean}
 */
function detectSecretMismatch(title, isSecret) {
  const hasSecret = titleHasSecretIndicator(title);
  if (isSecret) {
    return !hasSecret;
  }
  return hasSecret;
}

/**
 * @param {string} title
 * @returns {boolean}
 */
function detectProductTypeTier1(title) {
  return PRODUCT_TYPE_TIER1.some((term) => hasPhrase(title, term));
}

/**
 * @param {string} title
 * @param {readonly string[]} tokens
 * @param {boolean} figureIdentityMatch
 * @returns {boolean}
 */
function detectProductTypeTier2(title, tokens, figureIdentityMatch) {
  if (figureIdentityMatch) {
    return false;
  }

  if (PRODUCT_TYPE_TIER2.some((term) => hasPhrase(title, term))) {
    return true;
  }

  if (
    hasWholeToken(tokens, 'pin') &&
    !FIGURE_PRODUCT_NOUNS.some((noun) => hasWholeToken(tokens, noun))
  ) {
    return true;
  }

  return false;
}

/**
 * @param {object} params
 * @returns {MatcherSignals}
 */
function computeSignals(params) {
  const { title, tokens, context, marketAliasTokens, targetFigureMatched } =
    params;

  const brandMatch = context.brandTokens.some((token) =>
    hasBrandToken(title, token),
  );

  const seriesMatchFull = detectSeriesMatchFull(
    title,
    tokens,
    context,
    targetFigureMatched,
  );
  const seriesDistinctivePhrase = context.seriesDistinctivePhrase;
  const seriesMatchPartial =
    !seriesMatchFull &&
    (seriesDistinctivePhrase?.length ?? 0) >= 4 &&
    hasPhrase(title, seriesDistinctivePhrase);
  const seriesMatchScore = seriesMatchFull
    ? MATCH_WEIGHTS.seriesMatchFull
    : seriesMatchPartial
      ? MATCH_WEIGHTS.seriesMatchPartial
      : 0;

  const figureNameMatch = hasFigureNameMatch(tokens, context);
  const matchedCatalogFigureTokens = matchWholeTokens(tokens, [
    ...context.figureNameTokens,
    ...context.catalogFigureAliasTokens,
  ]);
  const matchedMarketAliasTokens = matchWholeTokens(tokens, marketAliasTokens);
  const marketAliasMatch = matchedMarketAliasTokens.length > 0;
  const figureIdentityMatch = figureNameMatch || marketAliasMatch;

  const secretSignalConsistent = context.isSecret
    ? titleHasSecretIndicator(title)
    : !titleHasSecretIndicator(title);

  return {
    brandMatch,
    seriesMatchFull,
    seriesMatchPartial,
    seriesMatchScore,
    figureNameMatch,
    marketAliasMatch,
    figureIdentityMatch,
    secretSignalConsistent,
    matchedMarketAliasTokens,
    matchedCatalogFigureTokens,
    matchedSiblingTokens: [],
  };
}

/**
 * @param {MatcherSignals} signals
 * @returns {number}
 */
function computeScore(signals) {
  let score = 0;

  if (signals.brandMatch) {
    score += MATCH_WEIGHTS.brandMatch;
  }

  score += signals.seriesMatchScore;

  if (signals.figureIdentityMatch) {
    score += MATCH_WEIGHTS.figureIdentity;
  }

  const extraMarketAliasTokens = signals.matchedMarketAliasTokens.filter(
    (token) => !signals.matchedCatalogFigureTokens.includes(token),
  );
  if (extraMarketAliasTokens.length > 0) {
    score += MATCH_WEIGHTS.marketAliasBonus;
  }

  if (signals.secretSignalConsistent) {
    score += MATCH_WEIGHTS.secretConsistentBonus;
  }

  return Math.min(score, 1);
}

/**
 * @param {MatcherSignals} signals
 * @returns {readonly string[]}
 */
function evaluateAcceptanceGates(signals) {
  const failures = [];

  if (!signals.brandMatch) {
    failures.push('gate:brandRequired');
  }

  if (!signals.seriesMatchFull) {
    failures.push('gate:fullSeriesRequired');
  }

  if (!signals.figureIdentityMatch) {
    failures.push('gate:figureIdentityRequired');
  }

  return failures;
}

/**
 * @param {string} title
 * @param {readonly string[]} tokens
 * @param {MatcherContext} context
 * @param {boolean} targetFigureMatched
 * @returns {boolean}
 */
function detectSeriesMatchFull(
  title,
  tokens,
  context,
  targetFigureMatched,
) {
  const phrase = context.seriesDistinctivePhrase;
  const phraseLen = phrase?.length ?? 0;

  const checkIpAnchor = () =>
    context.ipAnchorTokens.some((anchor) => {
      if (anchor.includes(' ')) {
        return hasPhrase(title, anchor);
      }
      return hasWholeToken(tokens, anchor);
    });

  if (phraseLen < 4) {
    // Distinctive too short to require — fall back to IP anchor + figure identity
    return checkIpAnchor() || targetFigureMatched;
  }

  if (!hasPhrase(title, phrase)) {
    return false;
  }

  const hasDistinctSeriesAlias = context.seriesAliasPhrases.some((p) =>
    hasPhrase(title, p),
  );

  if (checkIpAnchor() || hasDistinctSeriesAlias) {
    return true;
  }

  return targetFigureMatched;
}

/**
 * @param {readonly string[]} tokens
 * @param {MatcherContext} context
 * @returns {boolean}
 */
function hasFigureNameMatch(tokens, context) {
  const catalogTokens = [
    ...context.figureNameTokens,
    ...context.catalogFigureAliasTokens,
  ];
  return containsAnyWholeToken(tokens, catalogTokens);
}

/**
 * @param {readonly string[]} tokens
 * @param {readonly string[]} marketAliasTokens
 * @returns {boolean}
 */
function hasMarketAliasMatch(tokens, marketAliasTokens) {
  return containsAnyWholeToken(tokens, marketAliasTokens);
}

/**
 * @param {MatcherContext} context
 * @param {readonly string[]} marketAliasTokens
 * @returns {string[]}
 */
function collectTargetFigureTokens(context, marketAliasTokens) {
  return uniqueNormalizedTokens([
    ...context.figureNameTokens,
    ...context.catalogFigureAliasTokens,
    ...marketAliasTokens,
  ]);
}

/**
 * @param {readonly string[]} tokens
 * @param {readonly string[]} siblingTokens
 * @returns {string[]}
 */
function matchSiblingTokens(tokens, siblingTokens) {
  return siblingTokens.filter((token) => hasWholeToken(tokens, token));
}

/**
 * @param {readonly string[]} tokens
 * @param {readonly string[]} candidates
 * @returns {string[]}
 */
function matchWholeTokens(tokens, candidates) {
  return candidates.filter((token) => hasWholeToken(tokens, token));
}

/**
 * @param {readonly string[]} tokens
 * @param {readonly string[]} candidates
 * @returns {boolean}
 */
function containsAnyWholeToken(tokens, candidates) {
  return candidates.some((token) => hasWholeToken(tokens, token));
}

/**
 * @param {string} title
 * @returns {boolean}
 */
function titleHasSecretIndicator(title) {
  const tokens = tokenize(title);
  if (SECRET_INDICATOR_TOKENS.some((token) => hasWholeToken(tokens, token))) {
    return true;
  }
  return SECRET_INDICATOR_PHRASES.some((phrase) => title.includes(phrase));
}

/**
 * @param {string} title
 * @param {string} token
 * @returns {boolean}
 */
function hasBrandToken(title, token) {
  if (token.includes(' ')) {
    return hasPhrase(title, token);
  }
  return hasWholeToken(tokenize(title), token);
}

/**
 * @param {string} title
 * @param {string} phrase
 * @returns {boolean}
 */
function hasPhrase(title, phrase) {
  if (!phrase) return false;
  if (phrase.includes(' ')) {
    const pattern = new RegExp(
      `(?:^|\\s)${escapeRegExp(phrase)}(?:\\s|$)`,
    );
    return pattern.test(title);
  }
  return hasWholeToken(tokenize(title), phrase);
}

/**
 * @param {readonly string[]} tokens
 * @param {string} word
 * @returns {boolean}
 */
function hasWholeToken(tokens, word) {
  return tokens.includes(word);
}

/**
 * @param {string} value
 * @returns {readonly string[]}
 */
function tokenize(value) {
  return value.split(/\s+/).filter((part) => part.length > 0);
}

/**
 * @param {string} displayName
 * @returns {string[]}
 */
function tokenizeDisplayName(displayName) {
  return tokenize(structurallyNormalizeTitle(displayName));
}

/**
 * @param {readonly string[]} values
 * @returns {string[]}
 */
function uniqueNormalizedTokens(values) {
  const tokens = new Set();
  for (const value of values) {
    if (!value) continue;
    const normalized = structurallyNormalizeTitle(String(value));
    if (!normalized) continue;
    for (const token of tokenize(normalized)) {
      tokens.add(token);
    }
    if (normalized.includes(' ')) {
      tokens.add(normalized);
    }
  }
  return [...tokens];
}

/**
 * @param {readonly string[]} values
 * @returns {string[]}
 */
function uniqueNormalizedPhrases(values) {
  const phrases = new Set();
  for (const value of values) {
    const normalized = structurallyNormalizeTitle(String(value));
    if (normalized) {
      phrases.add(normalized);
    }
  }
  return [...phrases];
}

/**
 * @param {readonly string[]} values
 * @returns {string[]}
 */
function normalizeAliasList(values) {
  return uniqueNormalizedTokens(values);
}

/**
 * @param {object} series
 * @returns {string[]}
 */
function deriveDistinctiveSeriesPhrases(series) {
  const phrases = new Set();
  const sources = [series.displayName, ...(series.aliases ?? [])];

  for (const source of sources) {
    const normalized = structurallyNormalizeTitle(String(source));
    if (!normalized) continue;

    phrases.add(normalized);

    const distinctive = normalized
      .replace(SERIES_BOILERPLATE_PATTERN, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    if (distinctive.length >= 3) {
      phrases.add(distinctive);
    }

    if (distinctive.includes(' ')) {
      for (const part of distinctive.split(' ')) {
        if (part.length >= 5) {
          phrases.add(part);
        }
      }
    }
  }

  return [...phrases].filter((phrase) => phrase.length >= 3);
}

/**
 * @param {string} hardReject
 * @param {object} detail
 * @returns {string[]}
 */
function buildHardRejectReasons(hardReject, detail) {
  const reasons = [`hardReject:${hardReject}`];
  if (detail.matchedSiblingTokens?.length) {
    reasons.push(
      `matchedSiblingTokens:${detail.matchedSiblingTokens.join(',')}`,
    );
  }
  if (detail.matchedTargetTokens?.length) {
    reasons.push(
      `matchedTargetTokens:${detail.matchedTargetTokens.join(',')}`,
    );
  }
  return reasons;
}

/**
 * @param {object} params
 * @returns {string[]}
 */
function buildScoreReasons(params) {
  const { signals, score, effectiveThreshold, matched, gateReasons } = params;
  const reasons = [];

  if (signals.brandMatch) reasons.push('brandMatch');
  if (signals.seriesMatchFull) {
    reasons.push('seriesMatch:full');
  } else if (signals.seriesMatchPartial) {
    reasons.push('seriesMatch:partial');
  }
  if (signals.figureNameMatch) reasons.push('figureNameMatch');
  if (signals.marketAliasMatch) {
    reasons.push(
      `marketAliasMatch:${signals.matchedMarketAliasTokens.join(',')}`,
    );
  }
  if (signals.figureIdentityMatch) reasons.push('figureIdentityMatch');
  if (signals.secretSignalConsistent) reasons.push('secretSignalConsistent');

  reasons.push(`score=${roundScore(score)}`);
  reasons.push(`threshold=${effectiveThreshold}`);

  if (gateReasons.length > 0) {
    reasons.push(...gateReasons);
  }

  reasons.push(matched ? 'accepted' : 'rejected');
  return reasons;
}

/**
 * @param {number} score
 * @returns {number}
 */
function roundScore(score) {
  return Math.round(score * 1000) / 1000;
}

/**
 * @param {string} value
 * @returns {string}
 */
function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
