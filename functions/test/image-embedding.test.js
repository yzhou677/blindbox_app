'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  IMAGE_EMBEDDING_CONFIG,
} = require('../lib/figureRecognition/imageEmbeddingConfig');
const {
  FirebaseStorageImageReader,
  validateStorageObjectPath,
} = require('../lib/figureRecognition/firebaseStorageImageReader');
const {
  GoogleImageEmbeddingClient,
} = require('../lib/figureRecognition/googleImageEmbeddingClient');
const {
  ImageEmbeddingProvider,
} = require('../lib/figureRecognition/imageEmbeddingProvider');

describe('FirebaseStorageImageReader', () => {
  it('accepts an object path and reads bytes plus MIME type from the default bucket', async () => {
    const requested = [];
    const reader = new FirebaseStorageImageReader({
      file(path) {
        requested.push(path);
        return {
          async getMetadata() {
            return [{ contentType: 'image/jpeg' }];
          },
          async download() {
            return [Buffer.from('image')];
          },
        };
      },
    });

    const image = await reader.read('catalog/figures/example.jpg');
    assert.deepEqual(requested, ['catalog/figures/example.jpg']);
    assert.equal(image.mimeType, 'image/jpeg');
    assert.equal(image.bytes.toString(), 'image');
  });

  it('rejects URLs, foreign bucket URIs, and malformed paths', () => {
    for (const value of [
      'https://example.com/image.jpg',
      'gs://other-bucket/image.jpg',
      '/catalog/image.jpg',
      'catalog/../image.jpg',
      'catalog\\image.jpg',
    ]) {
      assert.throws(() => validateStorageObjectPath(value));
    }
  });
});

describe('GoogleImageEmbeddingClient', () => {
  it('uses Vertex embedContent input and explicitly requests 1024 dimensions', async () => {
    let request;
    const fakeSdk = {
      models: {
        async embedContent(input) {
          request = input;
          return { embeddings: [{ values: Array(1024).fill(0.25) }] };
        },
      },
    };
    const client = new GoogleImageEmbeddingClient(
      'blindbox-collection',
      IMAGE_EMBEDDING_CONFIG,
      fakeSdk,
    );

    const vector = await client.embed({
      bytes: Buffer.from('image'),
      mimeType: 'image/png',
    });

    assert.equal(vector.length, 1024);
    assert.equal(request.model, 'gemini-embedding-2');
    assert.equal(request.config.outputDimensionality, 1024);
    assert.equal(request.contents.parts[0].inlineData.mimeType, 'image/png');
    assert.equal(
      request.contents.parts[0].inlineData.data,
      Buffer.from('image').toString('base64'),
    );
  });
});

describe('ImageEmbeddingProvider', () => {
  it('returns an in-memory vector and logs metadata only', async () => {
    const logs = [];
    const provider = new ImageEmbeddingProvider(
      IMAGE_EMBEDDING_CONFIG,
      {
        async read(path) {
          assert.equal(path, 'catalog/figure.png');
          return { bytes: Buffer.from('private-image'), mimeType: 'image/png' };
        },
      },
      { async embed() { return Array(1024).fill(0.5); } },
      { log(entry) { logs.push(entry); } },
      (() => {
        const times = [100, 147];
        return () => times.shift();
      })(),
    );

    const result = await provider.embedStorageObject('catalog/figure.png');
    assert.equal(result.vector.length, 1024);
    assert.deepEqual(logs, [{
      success: true,
      model: 'gemini-embedding-2',
      location: 'us',
      dimension: 1024,
      elapsedMs: 47,
    }]);
    assert.equal(JSON.stringify(logs).includes('private-image'), false);
    assert.equal(JSON.stringify(logs).includes('0.5'), false);
  });

  it('rejects the wrong dimension and emits sanitized failure metadata', async () => {
    const logs = [];
    const provider = new ImageEmbeddingProvider(
      IMAGE_EMBEDDING_CONFIG,
      { async read() { return { bytes: Buffer.from('x'), mimeType: 'image/png' }; } },
      { async embed() { return [1, 2, 3]; } },
      { log(entry) { logs.push(entry); } },
      () => 10,
    );

    await assert.rejects(
      provider.embedStorageObject('catalog/figure.png'),
      /expected 1024, received 3/,
    );
    assert.deepEqual(logs, [{
      success: false,
      model: 'gemini-embedding-2',
      location: 'us',
      dimension: 1024,
      elapsedMs: 0,
    }]);
  });
});
