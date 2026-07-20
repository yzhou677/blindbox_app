/**
 * One-object image embedding verification. The vector is never printed or persisted.
 *
 * Required environment:
 *   GOOGLE_CLOUD_PROJECT
 *   FIREBASE_STORAGE_BUCKET
 */
import { initializeApp } from 'firebase-admin/app';
import providerModule from '../lib/figureRecognition/createImageEmbeddingProvider.js';
import configModule from '../lib/figureRecognition/imageEmbeddingConfig.js';

const { createImageEmbeddingProvider } = providerModule;
const { IMAGE_EMBEDDING_CONFIG } = configModule;

const objectPath = process.argv[2];
const projectId = process.env.GOOGLE_CLOUD_PROJECT?.trim();
const storageBucket = process.env.FIREBASE_STORAGE_BUCKET?.trim();
let logged = false;

const logger = {
  log(entry) {
    logged = true;
    console.log(JSON.stringify(entry));
  },
};

try {
  if (!objectPath) throw new Error('Storage object path argument is required');
  if (!projectId) throw new Error('GOOGLE_CLOUD_PROJECT is required');
  if (!storageBucket) throw new Error('FIREBASE_STORAGE_BUCKET is required');

  initializeApp({ projectId, storageBucket });
  const provider = createImageEmbeddingProvider(projectId, logger);
  await provider.embedStorageObject(objectPath);
} catch {
  if (!logged) {
    logger.log({
      success: false,
      model: IMAGE_EMBEDDING_CONFIG.model,
      location: IMAGE_EMBEDDING_CONFIG.location,
      dimension: IMAGE_EMBEDDING_CONFIG.outputDimension,
      elapsedMs: 0,
    });
  }
  process.exitCode = 1;
}
