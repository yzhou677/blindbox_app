/**
 * Catalog image QA severity for reason codes in
 * tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md.
 *
 * Failures block publish-series. Warnings do not.
 */

/** @typedef {'failure' | 'warning'} CatalogImageQaSeverity */

/** @type {ReadonlySet<string>} */
export const CATALOG_IMAGE_QA_FAILURE_CODES = Object.freeze(
  new Set([
    'PROMO_COMPOSITE',
    'LANDSCAPE_POSTER',
    'LIGHT_SOLID_BG',
    'MULTI_SUBJECT',
    'SMALL_SUBJECT',
    'MISSING_WEBP',
    'IMAGEKEY_MISMATCH',
    'SERIES_COVER_USED',
  ]),
);

/** @type {ReadonlySet<string>} */
export const CATALOG_IMAGE_QA_WARNING_CODES = Object.freeze(
  new Set(['LOW_RES', 'NON_WEBP']),
);

/**
 * @param {string} reasonCode
 * @returns {CatalogImageQaSeverity}
 */
export function catalogImageQaSeverity(reasonCode) {
  const code = reasonCode?.trim();
  if (!code) throw new Error('reasonCode is required');
  if (CATALOG_IMAGE_QA_WARNING_CODES.has(code)) return 'warning';
  if (CATALOG_IMAGE_QA_FAILURE_CODES.has(code)) return 'failure';
  throw new Error(`Unknown catalog image QA reason code: ${code}`);
}

/**
 * PROMO_COMPOSITE applies only to a full marketing poster or collage.
 * On-image title, logo, rarity, or SECRET text on a single figure is not enough.
 *
 * @param {{ isSingleFigure: boolean, isFullPosterOrCollage: boolean }} input
 * @returns {boolean}
 */
export function isPromoCompositeFinding(input) {
  if (!input || typeof input !== 'object') {
    throw new Error('isPromoCompositeFinding input is required');
  }
  return input.isFullPosterOrCollage === true && input.isSingleFigure !== true;
}
