/**
 * Market Intelligence — title normalization and exclude detection.
 *
 * Implements MATCHING_DESIGN.md Sections 3–4 (Steps 1–2 + global/per-figure excludes).
 * Pure functions only — no I/O, network, or side effects.
 */

/** Multi-word noise phrases removed with whole-phrase matching (longest first). */
export const MULTI_WORD_NOISE_PHRASES = Object.freeze([
  'free gift with purchase',
  'hard to find',
  'free shipping',
  'us fast shipping',
  'fast shipping',
  'us seller',
  'fast ship',
  'ship fast',
]);

/** Single-word noise tokens removed with whole-token matching after structural normalization. */
export const SINGLE_WORD_NOISE_TOKENS = Object.freeze([
  'new',
  'sealed',
  'bnib',
  'nib',
  'misb',
  'mib',
  'nrfb',
  'mint',
  'unopened',
  'shipping',
  'seller',
  'us',
  'rare',
  'htf',
  'limited',
  'exclusive',
  'authentic',
  'official',
  'genuine',
  'v1',
  'v2',
  'v3',
  'ver',
  'version',
]);

/** Global structural exclude phrases (substring match on normalized title). */
export const GLOBAL_MULTI_WORD_EXCLUDES = Object.freeze([
  'set of',
  'full case',
  'display case',
  'case of',
  '3d print',
  'digital file',
  'for parts',
  'not working',
]);

/** Global accessory exclude phrases (substring match on normalized title). */
export const ACCESSORY_MULTI_WORD_EXCLUDES = Object.freeze([
  'key chain',
  'phone strap',
  'pin only',
  'bag charm',
  'phone case',
]);

/** Global structural exclude tokens (word-boundary match on normalized title). */
export const GLOBAL_SINGLE_WORD_EXCLUDES = Object.freeze([
  'lot',
  'bundle',
  'custom',
  'bootleg',
  'fake',
  'replica',
  'inspired',
  'wholesale',
  'broken',
]);

/** Global accessory exclude tokens (word-boundary match on normalized title). */
export const ACCESSORY_SINGLE_WORD_EXCLUDES = Object.freeze([
  'keychain',
  'charm',
  'badge',
  'pendant',
  'lanyard',
]);

const SINGLE_WORD_NOISE_SET = new Set(SINGLE_WORD_NOISE_TOKENS);

const SORTED_MULTI_WORD_NOISE = [...MULTI_WORD_NOISE_PHRASES].sort(
  (a, b) => b.length - a.length,
);
const SORTED_GLOBAL_MULTI_WORD_EXCLUDES = [...GLOBAL_MULTI_WORD_EXCLUDES].sort(
  (a, b) => b.length - a.length,
);
const SORTED_ACCESSORY_MULTI_WORD_EXCLUDES = [
  ...ACCESSORY_MULTI_WORD_EXCLUDES,
].sort((a, b) => b.length - a.length);
const SORTED_PER_FIGURE_MULTI_CACHE = new Map();

const UNICODE_WRAPPER_CHARS =
  '\u3010\u3011\u300c\u300d\u300e\u300f\u3008\u3009\u300a\u300b';

const DECORATIVE_EDGE_PATTERN = new RegExp(
  `^[*~\\[\\](){}${UNICODE_WRAPPER_CHARS}|\\\\/]+|[*~\\[\\](){}${UNICODE_WRAPPER_CHARS}|\\\\/]+$`,
  'g',
);

const ORPHAN_PUNCTUATION_PATTERN = new RegExp(
  `^[*~\\[\\](){}${UNICODE_WRAPPER_CHARS}|\\\\/.]+$`,
);

/**
 * @typedef {'global' | 'accessory' | 'perFigure'} ExcludeScope
 */

/**
 * @typedef {Object} ExcludeMatch
 * @property {string} term
 * @property {ExcludeScope} scope
 */

/**
 * @typedef {Object} ExcludeOptions
 * @property {readonly string[]} [perFigureExcludes]
 * @property {readonly string[]} [globalExcludeOverrides]
 */

/**
 * Step 1 — structural normalization.
 * Lowercase ASCII, unify separators to spaces, collapse whitespace, trim.
 * Non-Latin characters (e.g. CJK) are preserved unchanged.
 *
 * @param {string} raw
 * @returns {string}
 */
export function structurallyNormalizeTitle(raw) {
  if (typeof raw !== 'string') return '';

  let result = '';
  for (let i = 0; i < raw.length; i += 1) {
    const code = raw.charCodeAt(i);
    if (isSeparator(code, raw, i)) {
      result += ' ';
      continue;
    }
    if (code >= 0x41 && code <= 0x5a) {
      result += String.fromCharCode(code + 0x20);
    } else if (code >= 0x61 && code <= 0x7a) {
      result += raw[i];
    } else {
      result += raw[i];
    }
  }

  return collapseWhitespace(result);
}

/**
 * Step 2 — remove condition, shipping, marketing, and version noise tokens.
 *
 * @param {string} structurallyNormalized
 * @returns {string}
 */
export function stripNoiseTokens(structurallyNormalized) {
  let text = structurallyNormalized;
  if (!text) return '';

  text = unwrapDecorativeTokensInText(text);

  for (const phrase of SORTED_MULTI_WORD_NOISE) {
    text = removePhraseAtWordBoundary(text, phrase);
  }

  text = unwrapDecorativeTokensInText(text);

  const kept = text
    .split(/\s+/)
    .filter((token) => token.length > 0)
    .map(unwrapDecorativeToken)
    .filter((token) => token.length > 0 && !isOrphanPunctuationToken(token))
    .filter((token, index, tokens) => !shouldRemoveNoiseToken(token, tokens, index));

  return cleanupOrphanPunctuation(kept.join(' '));
}

/**
 * Full title normalization (Sections 4 Steps 1–2).
 * Identity tokens (brand, figure, secret/chase/hidden/隐藏, size designators) are preserved
 * because they are not listed as noise tokens.
 *
 * @param {string} raw
 * @returns {string}
 */
export function normalizeMarketTitle(raw) {
  return stripNoiseTokens(structurallyNormalizeTitle(raw));
}

/**
 * Detect the first exclude term in a title (Section 3).
 * Runs on normalized lowercase text for consistent boundary matching.
 *
 * @param {string} rawOrNormalized — raw listing title or output of [normalizeMarketTitle]
 * @param {ExcludeOptions} [options]
 * @returns {ExcludeMatch | null}
 */
export function findExcludeTerm(rawOrNormalized, options = {}) {
  const normalized = normalizeForExcludeDetection(rawOrNormalized);
  if (!normalized) return null;

  const overrides = normalizeOverrideTerms(options.globalExcludeOverrides ?? []);

  const globalMatch = findGlobalExcludeTerm(normalized, overrides);
  if (globalMatch) return globalMatch;

  const perFigureExcludes = options.perFigureExcludes ?? [];
  return findPerFigureExcludeTerm(normalized, perFigureExcludes);
}

/**
 * @param {string} rawOrNormalized
 * @returns {boolean}
 */
export function isExcludedTitle(rawOrNormalized, options = {}) {
  return findExcludeTerm(rawOrNormalized, options) !== null;
}

/**
 * @param {string} normalized
 * @param {readonly string[]} overrides
 * @returns {ExcludeMatch | null}
 */
function findGlobalExcludeTerm(normalized, overrides) {
  for (const phrase of SORTED_GLOBAL_MULTI_WORD_EXCLUDES) {
    if (isOverridden(phrase, overrides)) continue;
    if (normalized.includes(phrase)) {
      return { term: phrase, scope: 'global' };
    }
  }

  for (const phrase of SORTED_ACCESSORY_MULTI_WORD_EXCLUDES) {
    if (isOverridden(phrase, overrides)) continue;
    if (normalized.includes(phrase)) {
      return { term: phrase, scope: 'accessory' };
    }
  }

  for (const token of GLOBAL_SINGLE_WORD_EXCLUDES) {
    if (isOverridden(token, overrides)) continue;
    if (hasWordBoundaryMatch(normalized, token)) {
      return { term: token, scope: 'global' };
    }
  }

  for (const token of ACCESSORY_SINGLE_WORD_EXCLUDES) {
    if (isOverridden(token, overrides)) continue;
    if (hasWordBoundaryMatch(normalized, token)) {
      return { term: token, scope: 'accessory' };
    }
  }

  return null;
}

/**
 * @param {string} normalized
 * @param {readonly string[]} perFigureExcludes
 * @returns {ExcludeMatch | null}
 */
function findPerFigureExcludeTerm(normalized, perFigureExcludes) {
  if (perFigureExcludes.length === 0) return null;

  const multiWord = sortedPerFigureMultiWord(perFigureExcludes);
  for (const phrase of multiWord) {
    if (normalized.includes(phrase)) {
      return { term: phrase, scope: 'perFigure' };
    }
  }

  for (const term of perFigureExcludes) {
    if (term.includes(' ')) continue;
    if (hasWordBoundaryMatch(normalized, term)) {
      return { term, scope: 'perFigure' };
    }
  }

  return null;
}

/**
 * @param {readonly string[]} perFigureExcludes
 * @returns {string[]}
 */
function sortedPerFigureMultiWord(perFigureExcludes) {
  const key = perFigureExcludes.join('\0');
  let cached = SORTED_PER_FIGURE_MULTI_CACHE.get(key);
  if (!cached) {
    cached = perFigureExcludes
      .map((term) => structurallyNormalizeTitle(term))
      .filter((term) => term.includes(' '))
      .sort((a, b) => b.length - a.length);
    SORTED_PER_FIGURE_MULTI_CACHE.set(key, cached);
  }
  return cached;
}

/**
 * @param {string} rawOrNormalized
 * @returns {string}
 */
function normalizeForExcludeDetection(rawOrNormalized) {
  const text = structurallyNormalizeTitle(rawOrNormalized);
  if (!text) return '';
  return text;
}

/**
 * @param {string} token
 * @param {readonly string[]} tokens
 * @param {number} index
 * @returns {boolean}
 */
function shouldRemoveNoiseToken(token, tokens, index) {
  if (!SINGLE_WORD_NOISE_SET.has(token)) return false;
  if (token === 'limited' && tokens[index + 1] === 'edition') {
    return false;
  }
  return true;
}

/**
 * @param {string} text
 * @returns {string}
 */
function unwrapDecorativeTokensInText(text) {
  return text
    .split(/\s+/)
    .filter(Boolean)
    .map(unwrapDecorativeToken)
    .filter((token) => token.length > 0 && !isOrphanPunctuationToken(token))
    .join(' ');
}

/**
 * @param {string} token
 * @returns {string}
 */
function unwrapDecorativeToken(token) {
  let value = token;
  let previous;
  do {
    previous = value;
    value = value.replace(DECORATIVE_EDGE_PATTERN, '');
  } while (value !== previous && value.length > 0);
  return value;
}

/**
 * @param {string} token
 * @returns {boolean}
 */
function isOrphanPunctuationToken(token) {
  return ORPHAN_PUNCTUATION_PATTERN.test(token);
}

/**
 * @param {string} text
 * @returns {string}
 */
function cleanupOrphanPunctuation(text) {
  if (!text) return '';

  const tokens = text
    .split(/\s+/)
    .filter(Boolean)
    .map(unwrapDecorativeToken)
    .filter((token) => token.length > 0 && !isOrphanPunctuationToken(token));

  return collapseWhitespace(tokens.join(' '));
}

/**
 * Remove a complete phrase bounded by whitespace — never partial token fragments.
 *
 * @param {string} text
 * @param {string} phrase
 * @returns {string}
 */
function removePhraseAtWordBoundary(text, phrase) {
  if (!phrase || !text) return text;

  const pattern = new RegExp(
    `(?:^|\\s)${escapeRegExp(phrase)}(?=\\s|$)`,
    'g',
  );
  let result = text;
  let changed = true;

  while (changed) {
    changed = false;
    const next = collapseWhitespace(result.replace(pattern, ' '));
    if (next !== result) {
      result = next;
      changed = true;
    }
  }

  return result;
}

/**
 * @param {string} text
 * @param {string} word
 * @returns {boolean}
 */
function hasWordBoundaryMatch(text, word) {
  if (!word) return false;
  const pattern = new RegExp(`\\b${escapeRegExp(word)}\\b`, 'i');
  return pattern.test(text);
}

/**
 * @param {readonly string[] | undefined} overrides
 * @returns {string[]}
 */
function normalizeOverrideTerms(overrides) {
  return overrides
    .map((term) => structurallyNormalizeTitle(term))
    .filter((term) => term.length > 0);
}

/**
 * @param {string} term
 * @param {readonly string[]} overrides
 * @returns {boolean}
 */
function isOverridden(term, overrides) {
  const normalizedTerm = structurallyNormalizeTitle(term);
  return overrides.some((override) => override === normalizedTerm);
}

/**
 * @param {number} code
 * @param {string} raw
 * @param {number} index
 * @returns {boolean}
 */
function isSeparator(code, raw, index) {
  if (code === 0x2f && isRatioSlash(raw, index)) {
    return false;
  }

  if (isUnicodeWrapperSeparator(code)) {
    return true;
  }

  return (
    code === 0x20 ||
    code === 0x2c ||
    code === 0x3a ||
    code === 0x3b ||
    code === 0x2d ||
    code === 0x5f ||
    code === 0x2f ||
    code === 0x7c ||
    code === 0xb7 ||
    code === 0x2022
  );
}

/**
 * @param {number} code
 * @returns {boolean}
 */
function isUnicodeWrapperSeparator(code) {
  return (
    code === 0x3010 ||
    code === 0x3011 ||
    code === 0x300c ||
    code === 0x300d ||
    code === 0x300e ||
    code === 0x300f ||
    code === 0x3008 ||
    code === 0x3009 ||
    code === 0x300a ||
    code === 0x300b
  );
}

/**
 * Preserve secret rarity ratios such as 1/144 during normalization.
 *
 * @param {string} raw
 * @param {number} index
 * @returns {boolean}
 */
function isRatioSlash(raw, index) {
  const prev = index > 0 ? raw[index - 1] : '';
  const next = index + 1 < raw.length ? raw[index + 1] : '';
  return /\d/.test(prev) && /\d/.test(next);
}

/**
 * @param {string} value
 * @returns {string}
 */
function collapseWhitespace(value) {
  return value.split(/\s+/).filter((part) => part.length > 0).join(' ');
}

/**
 * @param {string} value
 * @returns {string}
 */
function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
