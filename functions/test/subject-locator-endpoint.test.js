const test = require('node:test');
const assert = require('node:assert/strict');
const sharp = require('sharp');
const { PRIMARY_SUBJECT_CONFIG } = require('../lib/figureRecognition/primarySubjectConfig');
const { PrimarySubjectCropper } = require('../lib/figureRecognition/primarySubjectCropper');
const { PrimarySubjectCandidateSelector } = require('../lib/figureRecognition/primarySubjectCandidateSelector');
const { PrimarySubjectSuggestionService } = require('../lib/figureRecognition/primarySubjectSuggestionService');
const { SubjectLocatorTimeoutError } = require('../lib/figureRecognition/subjectLocatorEndpointTypes');
const { validateSubjectLocatorRequest } = require('../lib/figureRecognition/subjectLocatorRequestValidator');

async function fixture(width = 320, height = 240, orientation) {
  let pipeline = sharp({ create: { width, height, channels: 3, background: { r: 120, g: 80, b: 180 } } }).jpeg();
  if (orientation) pipeline = pipeline.withMetadata({ orientation });
  return { bytes: await pipeline.toBuffer(), mimeType: 'image/jpeg' };
}

function service(locator, timeoutMs = 1000) {
  const cropper = new PrimarySubjectCropper(PRIMARY_SUBJECT_CONFIG);
  return new PrimarySubjectSuggestionService(locator, cropper, new PrimarySubjectCandidateSelector(cropper, PRIMARY_SUBJECT_CONFIG), timeoutMs);
}

test('orients original bytes before locating and returns normalized oriented coordinates', async () => {
  const original = await fixture(120, 240, 6);
  let received;
  const result = await service({ async locate(image) {
    received = image;
    return { candidates: [{ bbox: [100, 200, 800, 700] }] };
  } }).suggest(original);
  const metadata = await sharp(received.bytes).metadata();
  assert.deepEqual([metadata.width, metadata.height], [240, 120]);
  assert.equal(result.status, 'suggestion');
  assert.deepEqual(result.rect, { left: 0.2, top: 0.1, width: 0.49999999999999994, height: 0.7000000000000001 });
  assert.deepEqual([result.orientedWidth, result.orientedHeight], [240, 120]);
  assert.equal(result.coordinateSpace, 'normalized_oriented_image');
});

test('passes all candidates through the existing deterministic selector', async () => {
  const result = await service({ async locate() { return { candidates: [
    { bbox: [0, 0, 200, 200] },
    { bbox: [250, 250, 750, 750] },
    { bbox: [800, 800, 1000, 1000] },
  ] }; } }).suggest(await fixture());
  assert.equal(result.status, 'suggestion');
  assert.equal(result.rect.left, 0.25);
  assert.equal(result.rect.top, 0.25);
  assert.equal(result.rect.width, 0.5);
  assert.equal(result.rect.height, 0.5);
  assert.deepEqual(Object.keys(result).sort(), ['coordinateSpace', 'locatorVersion', 'orientedHeight', 'orientedWidth', 'rect', 'selectorVersion', 'status', 'version']);
});

test('empty, malformed, and degenerate locator candidates become no_suggestion', async () => {
  for (const response of [
    { candidates: [] },
    { candidates: [{ bbox: [0, 0, 0, 100] }] },
    { candidates: [{ bbox: ['bad', 0, 100, 100] }] },
  ]) {
    const result = await service({ async locate() { return response; } }).suggest(await fixture());
    assert.equal(result.status, 'no_suggestion');
    assert.deepEqual(Object.keys(result).sort(), ['locatorVersion', 'orientedHeight', 'orientedWidth', 'selectorVersion', 'status', 'version']);
  }
});

test('timeout is a distinct recoverable failure', async () => {
  await assert.rejects(
    service({ async locate() { return new Promise(() => {}); } }, 1).suggest(await fixture()),
    SubjectLocatorTimeoutError,
  );
});

test('request validation accepts safe bytes and rejects unsafe MIME, payload, and dimensions', async () => {
  const image = await fixture();
  const valid = await validateSubjectLocatorRequest({ version: 1, image: { dataBase64: image.bytes.toString('base64'), mimeType: image.mimeType }, requestId: 'request-1' });
  assert.equal(valid.image.bytes.equals(image.bytes), true);
  await assert.rejects(validateSubjectLocatorRequest({ version: 1, image: { dataBase64: image.bytes.toString('base64'), mimeType: 'image/svg+xml' } }), { reason: 'unsupported_mime_type' });
  await assert.rejects(validateSubjectLocatorRequest({ version: 1, image: { dataBase64: '%%%=', mimeType: 'image/jpeg' } }), { reason: 'invalid_request' });
  const hugeDimensions = await fixture(10001, 5001);
  await assert.rejects(validateSubjectLocatorRequest({ version: 1, image: { dataBase64: hugeDimensions.bytes.toString('base64'), mimeType: 'image/jpeg' } }), { reason: 'image_dimensions_unsupported' });
});
