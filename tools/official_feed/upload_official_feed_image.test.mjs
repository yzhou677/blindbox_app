import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, it } from 'node:test';
import { loadOfficialFeedImageBytes } from './upload_official_feed_image.mjs';

const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64',
);

const dirs = [];

afterEach(() => {
  for (const dir of dirs.splice(0)) rmSync(dir, { recursive: true, force: true });
});

function tempDir() {
  const dir = mkdtempSync(join(tmpdir(), 'shelfy_feed_image_'));
  dirs.push(dir);
  return dir;
}

describe('loadOfficialFeedImageBytes', () => {
  it('reads a local png without uploading', async () => {
    const dir = tempDir();
    const file = join(dir, 'figure.png');
    writeFileSync(file, PNG);
    let fetched = false;
    const loaded = await loadOfficialFeedImageBytes(file, {
      fetchImpl: async () => {
        fetched = true;
        throw new Error('fetch should not run for a local file');
      },
    });
    assert.equal(fetched, false);
    assert.equal(loaded.contentType, 'image/png');
    assert.deepEqual(loaded.bytes, PNG);
  });

  it('reads an https image from the response body without uploading', async () => {
    const loaded = await loadOfficialFeedImageBytes('https://example.com/figure.png', {
      fetchImpl: async (url) => {
        assert.equal(url, 'https://example.com/figure.png');
        return new Response(PNG, {
          status: 200,
          headers: { 'content-type': 'image/png' },
        });
      },
    });
    assert.equal(loaded.contentType, 'image/png');
    assert.deepEqual(loaded.bytes, PNG);
  });

  it('reports a missing local file', async () => {
    const missing = join(tempDir(), 'missing.png');
    await assert.rejects(
      () => loadOfficialFeedImageBytes(missing),
      (err) => {
        assert.match(err.message, /^Image file not found: /);
        assert.match(err.message, /missing\.png$/);
        return true;
      },
    );
  });

  it('reports a local file that is not an image', async () => {
    const dir = tempDir();
    const file = join(dir, 'notes.txt');
    writeFileSync(file, 'hello');
    await assert.rejects(
      () => loadOfficialFeedImageBytes(file),
      (err) => {
        assert.match(err.message, /^Not an image: /);
        assert.match(err.message, /notes\.txt$/);
        return true;
      },
    );
  });

  it('reports an https response that is not an image', async () => {
    await assert.rejects(
      () =>
        loadOfficialFeedImageBytes('https://example.com/page', {
          fetchImpl: async () =>
            new Response('<html>nope</html>', {
              status: 200,
              headers: { 'content-type': 'text/html' },
            }),
        }),
      /Not an image: https:\/\/example.com\/page/,
    );
  });

  it('keeps the download-failed error for a bad https response', async () => {
    await assert.rejects(
      () =>
        loadOfficialFeedImageBytes('https://example.com/missing.png', {
          fetchImpl: async () => new Response('nope', { status: 404 }),
        }),
      /download failed 404/,
    );
  });
});
