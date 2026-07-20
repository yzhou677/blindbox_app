import type { CatalogEmbeddingJobOptions } from './catalogEmbeddingJob';

export function parseCatalogEmbeddingArgs(args: string[]): CatalogEmbeddingJobOptions {
  const options: CatalogEmbeddingJobOptions = {};
  for (let index = 0; index < args.length; index++) {
    const arg = args[index];
    if (arg === '--force') options.force = true;
    else if (arg === '--limit') options.limit = positiveInteger(args[++index], '--limit');
    else if (arg === '--figure-id') {
      const value = args[++index];
      if (!value || value.startsWith('--')) throw new Error('--figure-id requires a value');
      options.figureId = value;
    } else throw new Error(`Unknown option: ${arg}`);
  }
  return options;
}

function positiveInteger(value: string | undefined, name: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) throw new Error(`${name} must be a positive integer`);
  return parsed;
}
