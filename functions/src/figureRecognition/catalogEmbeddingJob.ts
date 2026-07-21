import { createHash } from 'node:crypto';
import type { Timestamp } from '@google-cloud/firestore';
import { IMAGE_EMBEDDING_CONFIG } from './imageEmbeddingConfig';
import { ImageEmbeddingProvider } from './imageEmbeddingProvider';
import type {
  CatalogEmbeddingStore,
  CatalogFigure,
  CatalogFigureSource,
  CatalogImageResolver,
  EmbeddingMetadata,
  ExistingCatalogEmbedding,
} from './catalogEmbeddingTypes';

export type CatalogEmbeddingJobOptions = { limit?: number; figureId?: string; force?: boolean };
export type CatalogEmbeddingSummary = {
  scanned: number; embedded: number; metadataUpdated: number; skipped: number; failed: number; elapsedMs: number;
  missingImages: number; missingImageCount: number; missingImageFigureIds: string[]; missingImageFigureIdsTruncated?: true;
};
export type CatalogEmbeddingPlanSummary = {
  totalFigures: number;
  alreadyUpToDate: number;
  metadataOnlyUpdates: number;
  requiresEmbedding: number;
  missingImages: number;
  estimatedEmbeddingApiCalls: number;
  estimatedAiCostUsd: number;
  missingImageCount: number;
  missingImageFigureIds: string[];
  missingImageFigureIdsTruncated?: true;
};
export type CatalogEmbeddingPlanningProgress = {
  processed: number;
  total?: number;
  alreadyUpToDate: number;
  metadataOnlyUpdates: number;
  requiresEmbedding: number;
  missingImages: number;
  failed: number;
  elapsedMs: number;
};
type PlannedItem = { figure: CatalogFigure; metadata: EmbeddingMetadata; action: 'embedded' | 'metadataUpdated'; isNew: boolean };
export type CatalogEmbeddingPlan = { summary: CatalogEmbeddingPlanSummary; items: PlannedItem[] };
export type ProgressLog = { figureId: string; status: 'embedded' | 'metadataUpdated' | 'skipped' | 'failed' };

export class CatalogEmbeddingJob {
  constructor(
    private readonly source: CatalogFigureSource,
    private readonly images: CatalogImageResolver,
    private readonly store: CatalogEmbeddingStore,
    private readonly provider: ImageEmbeddingProvider,
    private readonly log: (entry: ProgressLog) => void = console.log,
    private readonly now: () => number = Date.now,
  ) {}

  async run(options: CatalogEmbeddingJobOptions): Promise<CatalogEmbeddingSummary> {
    const plan = await this.plan(options);
    return this.execute(plan);
  }

  async plan(
    options: CatalogEmbeddingJobOptions,
    pricePerImageUsd = IMAGE_EMBEDDING_CONFIG.estimatedPricePerImageUsd,
    onProgress?: (progress: CatalogEmbeddingPlanningProgress) => void,
  ): Promise<CatalogEmbeddingPlan> {
    if (!Number.isFinite(pricePerImageUsd) || pricePerImageUsd < 0) throw new Error('Per-image price must be a non-negative number');
    const startedAt = this.now();
    const summary: CatalogEmbeddingPlanSummary = {
      totalFigures: 0, alreadyUpToDate: 0, metadataOnlyUpdates: 0, requiresEmbedding: 0,
      missingImages: 0, estimatedEmbeddingApiCalls: 0, estimatedAiCostUsd: 0,
      missingImageCount: 0, missingImageFigureIds: [],
    };
    const items: PlannedItem[] = [];
    const emitProgress = (): void => {
      if (summary.totalFigures % 25 !== 0) return;
      onProgress?.({
        processed: summary.totalFigures,
        ...knownPlanningTotal(options),
        alreadyUpToDate: summary.alreadyUpToDate,
        metadataOnlyUpdates: summary.metadataOnlyUpdates,
        requiresEmbedding: summary.requiresEmbedding,
        missingImages: summary.missingImages,
        failed: 0,
        elapsedMs: Math.max(0, this.now() - startedAt),
      });
    };
    for await (const figure of this.selectFigures(options)) {
      if (options.limit !== undefined && summary.totalFigures >= options.limit) break;
      summary.totalFigures++;
      let image;
      try {
        image = await withTransientRetries(() => this.images.resolve(figure.imageKey));
      } catch {
        summary.missingImages++;
        summary.missingImageCount++;
        if (summary.missingImageFigureIds.length < 20) summary.missingImageFigureIds.push(figure.figureId);
        else summary.missingImageFigureIdsTruncated = true;
        emitProgress();
        continue;
      }
      const metadata = createMetadata(figure, image.objectPath, image.bytes);
      const existing = await withTransientRetries(() => this.store.get(figure.figureId));
      if (!options.force && isReusable(existing, metadata)) {
        if (metadataChanged(existing!.data, metadata)) {
          summary.metadataOnlyUpdates++;
          items.push({ figure, metadata, action: 'metadataUpdated', isNew: false });
        } else summary.alreadyUpToDate++;
      } else {
        summary.requiresEmbedding++;
        items.push({ figure, metadata, action: 'embedded', isNew: existing === null });
      }
      emitProgress();
    }
    summary.estimatedEmbeddingApiCalls = summary.requiresEmbedding;
    summary.estimatedAiCostUsd = summary.requiresEmbedding * pricePerImageUsd;
    return { summary, items };
  }

  async execute(plan: CatalogEmbeddingPlan): Promise<CatalogEmbeddingSummary> {
    const startedAt = this.now();
    const summary = {
      scanned: plan.summary.totalFigures, embedded: 0, metadataUpdated: 0,
      skipped: plan.summary.alreadyUpToDate, failed: plan.summary.missingImages, elapsedMs: 0,
      missingImages: plan.summary.missingImages,
      missingImageCount: plan.summary.missingImageCount,
      missingImageFigureIds: [...plan.summary.missingImageFigureIds],
      ...(plan.summary.missingImageFigureIdsTruncated ? { missingImageFigureIdsTruncated: true as const } : {}),
    };
    for (const item of plan.items) {
      try {
        if (item.action === 'metadataUpdated') {
          await withTransientRetries(() => this.store.updateMetadata(item.metadata));
          summary.metadataUpdated++;
        } else {
          const image = await withTransientRetries(() => this.images.resolve(item.figure.imageKey));
          const metadata = createMetadata(item.figure, image.objectPath, image.bytes);
          const result = await withTransientRetries(() => this.provider.embedStoredImage(image));
          await withTransientRetries(() => this.store.writeEmbedding(metadata, result.vector, item.isNew));
          summary.embedded++;
        }
        this.log({ figureId: item.figure.figureId, status: item.action });
      } catch {
        summary.failed++;
        this.log({ figureId: item.figure.figureId, status: 'failed' });
      }
    }
    summary.elapsedMs = Math.max(0, this.now() - startedAt);
    return summary;
  }

  private async *selectFigures(options: CatalogEmbeddingJobOptions): AsyncIterable<CatalogFigure> {
    if (options.figureId) {
      const figure = await this.source.get(options.figureId);
      if (!figure) throw new Error(`Figure ${options.figureId} not found`);
      yield figure;
      return;
    }
    for await (const page of this.source.pages(100)) for (const figure of page) yield figure;
  }

}

function knownPlanningTotal(options: CatalogEmbeddingJobOptions): { total?: number } {
  if (options.figureId) return { total: 1 };
  if (options.limit !== undefined) return { total: options.limit };
  return {};
}

function createMetadata(figure: CatalogFigure, imageObjectPath: string, bytes: Buffer): EmbeddingMetadata {
  return {
    figureId: figure.figureId, seriesId: figure.seriesId, brandId: figure.brandId, ipId: figure.ipId,
    isSecret: figure.isSecret, catalogModifiedAt: figure.catalogModifiedAt, imageObjectPath,
    contentHash: createHash('sha256').update(bytes).digest('hex'),
  };
}

function isReusable(existing: ExistingCatalogEmbedding | null, metadata: EmbeddingMetadata): boolean {
  if (!existing?.hasNativeVector || !existing.vector) return false;
  if (existing.vector.length !== IMAGE_EMBEDDING_CONFIG.outputDimension || !existing.vector.every(Number.isFinite)) return false;
  const d = existing.data;
  return d.contentHash === metadata.contentHash && d.embeddingSpace === IMAGE_EMBEDDING_CONFIG.embeddingSpace &&
    d.embeddingModel === IMAGE_EMBEDDING_CONFIG.model && d.embeddingLocation === IMAGE_EMBEDDING_CONFIG.location &&
    d.embeddingDimension === IMAGE_EMBEDDING_CONFIG.outputDimension && d.embeddingVersion === IMAGE_EMBEDDING_CONFIG.version;
}

function metadataChanged(data: Record<string, unknown>, metadata: EmbeddingMetadata): boolean {
  return data.figureId !== metadata.figureId || data.seriesId !== metadata.seriesId || data.brandId !== metadata.brandId ||
    data.ipId !== metadata.ipId || data.isSecret !== metadata.isSecret || data.imageObjectPath !== metadata.imageObjectPath ||
    timestampMillis(data.catalogModifiedAt) !== timestampMillis(metadata.catalogModifiedAt);
}

function timestampMillis(value: unknown): number | null {
  return value && typeof (value as Timestamp).toMillis === 'function' ? (value as Timestamp).toMillis() : null;
}

export async function withTransientRetries<T>(action: () => Promise<T>, sleep = defaultSleep, random = Math.random): Promise<T> {
  for (let attempt = 1; ; attempt++) {
    try { return await action(); } catch (error) {
      if (attempt >= 3 || !isTransient(error)) throw error;
      await sleep(200 * 2 ** (attempt - 1) + Math.floor(random() * 100));
    }
  }
}

function isTransient(error: unknown): boolean {
  const value = error as { code?: unknown; status?: unknown };
  const code = String(value?.code ?? '').toLowerCase().replaceAll('_', '-');
  const status = Number(value?.status ?? value?.code);
  return status === 408 || status === 429 || status >= 500 ||
    ['aborted', 'deadline-exceeded', 'resource-exhausted', 'unavailable', 'internal'].includes(code);
}
const defaultSleep = (milliseconds: number) => new Promise<void>((resolve) => setTimeout(resolve, milliseconds));
