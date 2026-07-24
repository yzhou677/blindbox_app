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

const { parseCatalogEmbeddingArgs, optionsForCatalogEmbeddingExecute, createStartupDiagnostic } = cliModule;
const { CatalogEmbeddingJob } = jobModule;
const { FirestoreCatalogFigureSource } = sourceModule;
const { FirebaseCatalogImageResolver } = resolverModule;
const { FirestoreCatalogEmbeddingStore } = storeModule;
const { FirebaseStorageImageReader } = readerModule;
const { createImageEmbeddingProvider } = providerModule;
const { IMAGE_EMBEDDING_CONFIG } = configModule;

let phase = 'startup';
let component = 'environment';
try {
  const projectId = process.env.GOOGLE_CLOUD_PROJECT?.trim();
  const storageBucket = process.env.FIREBASE_STORAGE_BUCKET?.trim();
  if (!projectId) throw new Error('GOOGLE_CLOUD_PROJECT is required');
  if (!storageBucket) throw new Error('FIREBASE_STORAGE_BUCKET is required');
  component = 'argument-parser';
  const options = parseCatalogEmbeddingArgs(process.argv.slice(2));
  component = 'firebase-admin';
  initializeApp({ projectId, storageBucket });
  component = 'firestore-client';
  const firestore = new Firestore({ projectId });
  component = 'storage-reader';
  const reader = new FirebaseStorageImageReader();
  component = 'embedding-provider';
  const provider = createImageEmbeddingProvider(projectId, { log: (entry) => console.log(JSON.stringify(entry)) });
  component = 'job-composition';
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
  phase = 'planning';
  console.log('Planning catalog embedding run...');
  const plan = await job.plan(
    options,
    pricePerImageUsd,
    (progress) => console.log(JSON.stringify({ phase: 'planning-progress', ...progress })),
  );
  component = 'pricing';
  console.log(JSON.stringify({ phase: 'plan', pricePerImageUsd, ...plan.summary }));
  const prompt = createInterface({ input: process.stdin, output: process.stdout });
  const answer = await prompt.question('Proceed with paid embedding requests and Firestore writes? Type y to continue: ');
  prompt.close();
  if (answer.trim().toLowerCase() !== 'y') {
    console.log(JSON.stringify({ phase: 'cancelled' }));
    process.exit(0);
  }
  phase = 'execution';
  const summary = await job.execute(plan, optionsForCatalogEmbeddingExecute(options));
  console.log(JSON.stringify(summary));
  if (summary.failed > 0) process.exitCode = 1;
} catch (error) {
  if (phase === 'startup') {
    console.log(JSON.stringify(createStartupDiagnostic(error, component)));
    process.exitCode = 1;
  } else {
  const errorCode = phase === 'startup' ? 'catalog-embedding-startup-failed' :
    phase === 'planning' ? 'catalog-embedding-planning-failed' : 'catalog-embedding-execution-failed';
  const message = phase === 'planning' ? 'Catalog embedding job failed while enumerating or planning the catalog' :
    'Catalog embedding job failed during execution';
  console.log(JSON.stringify({ success: false, errorCode, message }));
  process.exitCode = 1;
  }
}
