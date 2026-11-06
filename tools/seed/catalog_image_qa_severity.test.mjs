import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  catalogImageQaSeverity,
  isPromoCompositeFinding,
} from './catalog_image_qa_severity.mjs';

describe('catalogImageQaSeverity', () => {
  it('marks LOW_RES and NON_WEBP as warnings', () => {
    assert.equal(catalogImageQaSeverity('LOW_RES'), 'warning');
    assert.equal(catalogImageQaSeverity('NON_WEBP'), 'warning');
  });

  it('marks path and full-poster codes as failures', () => {
    assert.equal(catalogImageQaSeverity('MISSING_ASSET'), 'failure');
    assert.equal(catalogImageQaSeverity('IMAGEKEY_MISMATCH'), 'failure');
    assert.equal(catalogImageQaSeverity('PROMO_COMPOSITE'), 'failure');
    assert.equal(catalogImageQaSeverity('SERIES_COVER_USED'), 'failure');
  });

  it('rejects unknown codes', () => {
    assert.throws(() => catalogImageQaSeverity('SECRET_TEXT'), /Unknown catalog image QA reason code/);
  });
});

describe('isPromoCompositeFinding', () => {
  it('is true only for a full poster or collage that is not a single figure', () => {
    assert.equal(
      isPromoCompositeFinding({ isSingleFigure: false, isFullPosterOrCollage: true }),
      true,
    );
  });

  it('is false when the shot is still a single figure, even with on-image text', () => {
    assert.equal(
      isPromoCompositeFinding({ isSingleFigure: true, isFullPosterOrCollage: false }),
      false,
    );
    assert.equal(
      isPromoCompositeFinding({ isSingleFigure: true, isFullPosterOrCollage: true }),
      false,
    );
  });
});
