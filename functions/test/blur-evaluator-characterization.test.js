const assert = require('node:assert/strict');
const { describe, it } = require('node:test');
const sharp = require('sharp');
const {
  PrimarySubjectBlurEvaluator,
} = require('../lib/figureRecognition/primarySubjectBlurEvaluator');
const {
  PrimarySubjectCropper,
} = require('../lib/figureRecognition/primarySubjectCropper');
const {
  PRIMARY_SUBJECT_CONFIG,
} = require('../lib/figureRecognition/primarySubjectConfig');

async function checkerboard(width, height, format) {
  const data = Buffer.alloc(width * height * 3);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const value = ((x >> 3) + (y >> 3)) % 2 ? 255 : 0;
      data.fill(value, (y * width + x) * 3, (y * width + x) * 3 + 3);
    }
  }
  return sharp(data, { raw: { width, height, channels: 3 } })
    [format]()
    .toBuffer();
}

describe('production blur format characterization', () => {
  it('keeps finite deterministic metrics and outcomes for portrait and landscape JPEG, PNG, and WebP', async () => {
    const evaluator = new PrimarySubjectBlurEvaluator(
      new PrimarySubjectCropper(PRIMARY_SUBJECT_CONFIG),
    );
    for (const [width, height] of [
      [96, 160],
      [160, 96],
    ]) {
      for (const format of ['jpeg', 'png', 'webp']) {
        const bytes = await checkerboard(width, height, format);
        const mimeType = format === 'jpeg' ? 'image/jpeg' : `image/${format}`;
        const first = await evaluator.evaluateImage({ bytes, mimeType });
        const second = await evaluator.evaluateImage({ bytes, mimeType });
        assert.equal(Number.isFinite(first.laplacianVariance), true);
        assert.equal(Number.isFinite(first.sharpStats), true);
        assert.equal(first.laplacianVariance, second.laplacianVariance);
        assert.equal(first.sharpStats, second.sharpStats);
        assert.equal(first.quality, second.quality);
        assert.notEqual(first.quality, 'too_blurry');
      }
    }
  });
});
