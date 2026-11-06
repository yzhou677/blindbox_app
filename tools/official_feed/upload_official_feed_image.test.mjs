import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, it } from 'node:test';
import {
  loadOfficialFeedImageBytes,
  officialFeedDownloadUrl,
} from './upload_official_feed_image.mjs';

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

  it('reads a local jpeg and a local webp', async () => {
    const dir = tempDir();
    const jpeg = Buffer.alloc(12, 0);
    jpeg[0] = 0xff;
    jpeg[1] = 0xd8;
    jpeg[2] = 0xff;
    const webp = Buffer.alloc(12, 0);
    webp.write('RIFF', 0);
    webp.write('WEBP', 8);
    const jpegFile = join(dir, 'figure.jpg');
    const webpFile = join(dir, 'figure.webp');
    writeFileSync(jpegFile, jpeg);
    writeFileSync(webpFile, webp);

    const jpegLoaded = await loadOfficialFeedImageBytes(jpegFile);
    const webpLoaded = await loadOfficialFeedImageBytes(webpFile);
    assert.equal(jpegLoaded.contentType, 'image/jpeg');
    assert.equal(webpLoaded.contentType, 'image/webp');
  });

  it('rejects an http URL', async () => {
    let fetched = false;
    await assert.rejects(
      () =>
        loadOfficialFeedImageBytes('http://example.com/figure.png', {
          fetchImpl: async () => {
            fetched = true;
            throw new Error('fetch should not run for http');
          },
        }),
      /Only https URLs are accepted: http:\/\/example.com\/figure.png/,
    );
    assert.equal(fetched, false);
  });

  it('builds the Firebase download URL', () => {
    assert.equal(
      officialFeedDownloadUrl(
        'blindbox-collection.firebasestorage.app',
        'official_feed/popmart_us/ig_abc.jpg',
        'token-1',
      ),
      'https://firebasestorage.googleapis.com/v0/b/blindbox-collection.firebasestorage.app/o/' +
        'official_feed%2Fpopmart_us%2Fig_abc.jpg?alt=media&token=token-1',
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
