const assert = require('node:assert/strict');
const test = require('node:test');
const { logger } = require('firebase-functions');
const {
  measureScanStage,
  withScanTimingContext,
} = require('../lib/figureRecognition/scanTiming');

test('scan timing preserves correlation and closes success and failure timers safely', async () => {
  const entries = [];
  const originalDebug = logger.debug;
  logger.debug = (message, fields) => entries.push({ message, fields });
  try {
    await withScanTimingContext(
      { component: 'backend_locator', correlationId: 'scan-timing-test' },
      async () => {
        await measureScanStage('success_stage', async () => 'ok', {
          decodedBytesEstimate: 12,
        });
        await assert.rejects(
          measureScanStage('failure_stage', async () => {
            throw new Error('expected');
          }),
          /expected/,
        );
      },
    );
  } finally {
    logger.debug = originalDebug;
  }

  assert.deepEqual(
    entries.map(({ fields }) => fields.stage),
    ['success_stage', 'failure_stage'],
  );
  for (const { fields } of entries) {
    assert.equal(fields.correlationId, 'scan-timing-test');
    assert.equal(fields.component, 'backend_locator');
    assert.equal(Number.isFinite(fields.elapsedMs), true);
    const serialized = JSON.stringify(fields);
    for (const forbidden of [
      'dataBase64',
      'localPath',
      'exif',
      'token',
      'embedding',
      'prompt',
    ]) {
      assert.equal(serialized.includes(forbidden), false);
    }
  }
});
