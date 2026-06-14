/**
 * Parse tools/market_intel/edge_case_titles.txt into structured test cases.
 *
 * Format:
 *   # --- section_name ---
 *   # @category=valid_sale @excluded=false @mustContain=pop mart|lucky
 *   Raw listing title (one per line)
 *
 * Directive keys:
 *   category, excluded, term, expected, mustContain, mustNotContain, overrides, subcategory, source
 *
 * Values use | as list separator. term=(none) means no exclude match expected.
 */

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
export const DEFAULT_CORPUS_PATH = join(__dirname, 'edge_case_titles.txt');

/**
 * @typedef {Object} EdgeCaseEntry
 * @property {string} raw
 * @property {string} category
 * @property {string} [subcategory]
 * @property {string} [source]
 * @property {boolean} excluded
 * @property {string | null} term
 * @property {string | undefined} expected
 * @property {string[]} mustContain
 * @property {string[]} mustNotContain
 * @property {string[]} overrides
 */

/**
 * @param {string} [path]
 * @returns {EdgeCaseEntry[]}
 */
export function loadEdgeCaseCorpus(path = DEFAULT_CORPUS_PATH) {
  const text = readFileSync(path, 'utf8');
  /** @type {EdgeCaseEntry[]} */
  const entries = [];
  /** @type {{ category: string, excluded: boolean }} */
  let sectionBase = {
    category: 'uncategorized',
    excluded: false,
  };
  /** @type {Partial<EdgeCaseEntry>} */
  let entryOverrides = {};

  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed) continue;

    if (trimmed.startsWith('# ---')) {
      const section = trimmed.replace(/^#\s*---\s*|\s*---\s*$/g, '');
      sectionBase = {
        category: section,
        excluded: false,
      };
      entryOverrides = {};
      continue;
    }

    if (trimmed.startsWith('# @')) {
      const parsed = parseDirectives(trimmed.slice(2).trim());
      if (parsed.category !== undefined) {
        sectionBase.category = parsed.category;
      }
      if (parsed.excluded !== undefined) {
        sectionBase.excluded = parsed.excluded;
      }
      entryOverrides = pickEntryOverrides(parsed);
      continue;
    }

    if (trimmed.startsWith('#')) continue;

    entries.push(buildEntry(trimmed, sectionBase, entryOverrides));
    entryOverrides = {};
  }

  return entries;
}

/**
 * @param {string} directiveText
 * @returns {Partial<EdgeCaseEntry>}
 */
function parseDirectives(directiveText) {
  /** @type {Partial<EdgeCaseEntry>} */
  const result = {};
  const segments = directiveText
    .split(/\s+(?=@)/)
    .map((segment) => segment.trim())
    .filter(Boolean);

  for (const segment of segments) {
    const clean = segment.replace(/^@+/, '');
    const eq = clean.indexOf('=');
    if (eq === -1) continue;
    const key = clean.slice(0, eq);
    const value = clean.slice(eq + 1).trim();

    switch (key) {
      case 'category':
      case 'subcategory':
      case 'source':
      case 'expected':
        result[key] = value;
        break;
      case 'excluded':
        result.excluded = value === 'true';
        break;
      case 'term':
        result.term = value === '(none)' ? null : value;
        break;
      case 'mustContain':
      case 'mustNotContain':
      case 'overrides':
        result[key] = splitList(value);
        break;
      default:
        break;
    }
  }

  return result;
}

/**
 * @param {string} value
 * @returns {string[]}
 */
function splitList(value) {
  return value
    .split('|')
    .map((part) => part.trim())
    .filter(Boolean);
}

/**
 * @param {Partial<EdgeCaseEntry>} parsed
 * @returns {Partial<EdgeCaseEntry>}
 */
function pickEntryOverrides(parsed) {
  return {
    subcategory: parsed.subcategory,
    source: parsed.source,
    term: parsed.term,
    expected: parsed.expected,
    mustContain: parsed.mustContain ?? [],
    mustNotContain: parsed.mustNotContain ?? [],
    overrides: parsed.overrides ?? [],
    ...(parsed.excluded !== undefined ? { excluded: parsed.excluded } : {}),
  };
}

/**
 * @param {string} raw
 * @param {{ category: string, excluded: boolean }} sectionBase
 * @param {Partial<EdgeCaseEntry>} entryOverrides
 * @returns {EdgeCaseEntry}
 */
function buildEntry(raw, sectionBase, entryOverrides) {
  return {
    raw,
    category: entryOverrides.category ?? sectionBase.category,
    subcategory: entryOverrides.subcategory,
    source: entryOverrides.source,
    excluded: entryOverrides.excluded ?? sectionBase.excluded ?? false,
    term: entryOverrides.term ?? null,
    expected: entryOverrides.expected,
    mustContain: [...(entryOverrides.mustContain ?? [])],
    mustNotContain: [...(entryOverrides.mustNotContain ?? [])],
    overrides: [...(entryOverrides.overrides ?? [])],
  };
}

/**
 * @param {EdgeCaseEntry} entry
 * @param {{ normalizeMarketTitle: Function, findExcludeTerm: Function }} fns
 * @returns {{ ok: boolean, errors: string[] }}
 */
export function evaluateEdgeCaseEntry(entry, fns) {
  const errors = [];
  const normalized = fns.normalizeMarketTitle(entry.raw);
  const options =
    entry.overrides.length > 0
      ? { globalExcludeOverrides: entry.overrides }
      : {};
  const match = fns.findExcludeTerm(entry.raw, options);
  const excluded = match !== null;

  if (entry.expected !== undefined && normalized !== entry.expected) {
    errors.push(`expected normalized "${entry.expected}", got "${normalized}"`);
  }

  if (entry.excluded !== excluded) {
    errors.push(`expected excluded=${entry.excluded}, got ${excluded}`);
  }

  if (entry.term !== null && match?.term !== entry.term) {
    errors.push(
      `expected exclude term "${entry.term}", got "${match?.term ?? '(none)'}"`,
    );
  }

  if (entry.term === null && match !== null && entry.excluded === false) {
    errors.push(`expected no exclude term, got "${match.term}"`);
  }

  for (const token of entry.mustContain) {
    if (!normalized.includes(token)) {
      errors.push(`normalized output missing "${token}"`);
    }
  }

  for (const token of entry.mustNotContain) {
    if (normalized.includes(token)) {
      errors.push(`normalized output should not contain "${token}"`);
    }
  }

  if (!normalized && entry.raw.trim().length > 0) {
    errors.push('normalized output is empty');
  }

  return { ok: errors.length === 0, errors, normalized, excluded, match };
}

/**
 * @param {EdgeCaseEntry[]} entries
 * @param {{ normalizeMarketTitle: Function, findExcludeTerm: Function }} fns
 */
export function summarizeCorpusCoverage(entries, fns) {
  /** @type {Map<string, { total: number, pass: number, fail: number, excluded: number, normalized: number }>} */
  const byCategory = new Map();

  for (const entry of entries) {
    const bucket = byCategory.get(entry.category) ?? {
      total: 0,
      pass: 0,
      fail: 0,
      excluded: 0,
      normalized: 0,
    };
    bucket.total += 1;

    const result = evaluateEdgeCaseEntry(entry, fns);
    if (result.ok) bucket.pass += 1;
    else bucket.fail += 1;
    if (result.excluded) bucket.excluded += 1;
    if (result.normalized.length > 0) bucket.normalized += 1;

    byCategory.set(entry.category, bucket);
  }

  return byCategory;
}
