/** Sequential, resumable catalog embedding backfill. Uses ADC and persists native vectors only. */
import { initializeApp } from 'firebase-admin/app';
import { Firestore } from '@google-cloud/firestore';
import { createInterface } from 'node:readline/promises';
import cliModule from '../lib/figureRecognition/catalogEmbeddingCli.js';
import jobModule from '../lib/figureRecognition/catalogEmbeddingJob.js';
import sourceModule from '../lib/figureRecognition/catalogFigureSource.js';
import resolverModule from '../lib/figureRecognition/catalogImageResolver.js';
import storeModule from '../lib/figureRecognition/catalogEmbeddingStore.js';
import readerModule from '../lib/figureRecognition/firebaseStorageImageReader.js';
import providerModule from '../lib/figureRecognition/createImageEmbeddingProvider.js';
import configModule from '../lib/figureRecognition/imageEmbeddingConfig.js';

const { parseCatalogEmbeddingArgs } = cliModule;
const { CatalogEmbeddingJob } = jobModule;
const { FirestoreCatalogFigureSource } = sourceModule;
const { FirebaseCatalogImageResolver } = resolverModule;
const { FirestoreCatalogEmbeddingStore } = storeModule;
const { FirebaseStorageImageReader } = readerModule;
const { createImageEmbeddingProvider } = providerModule;
const { IMAGE_EMBEDDING_CONFIG } = configModule;

try {
  const projectId = process.env.GOOGLE_CLOUD_PROJECT?.trim();
  const storageBucket = process.env.FIREBASE_STORAGE_BUCKET?.trim();
  if (!projectId) throw new Error('GOOGLE_CLOUD_PROJECT is required');
  if (!storageBucket) throw new Error('FIREBASE_STORAGE_BUCKET is required');
  const options = parseCatalogEmbeddingArgs(process.argv.slice(2));
  initializeApp({ projectId, storageBucket });
  const firestore = new Firestore({ projectId });
  const reader = new FirebaseStorageImageReader();
  const provider = createImageEmbeddingProvider(projectId, { log: (entry) => console.log(JSON.stringify(entry)) });
  const job = new CatalogEmbeddingJob(
    new FirestoreCatalogFigureSource(firestore),
    new FirebaseCatalogImageResolver(reader),
    new FirestoreCatalogEmbeddingStore(firestore),
    provider,
    (entry) => console.log(JSON.stringify(entry)),
  );
  const configuredPrice = process.env.IMAGE_EMBEDDING_PRICE_PER_IMAGE_USD;
  const pricePerImageUsd = configuredPrice === undefined
    ? IMAGE_EMBEDDING_CONFIG.estimatedPricePerImageUsd
    : Number(configuredPrice);
  const plan = await job.plan(options, pricePerImageUsd);
  console.log(JSON.stringify({ phase: 'plan', pricePerImageUsd, ...plan.summary }));
  const prompt = createInterface({ input: process.stdin, output: process.stdout });
  const answer = await prompt.question('Proceed with paid embedding requests and Firestore writes? Type y to continue: ');
  prompt.close();
  if (answer.trim().toLowerCase() !== 'y') {
    console.log(JSON.stringify({ phase: 'cancelled' }));
    process.exit(0);
  }
  const summary = await job.execute(plan);
  console.log(JSON.stringify(summary));
  if (summary.failed > 0) process.exitCode = 1;
} catch {
  console.log(JSON.stringify({ scanned: 0, embedded: 0, metadataUpdated: 0, skipped: 0, failed: 1, elapsedMs: 0 }));
  process.exitCode = 1;
}
