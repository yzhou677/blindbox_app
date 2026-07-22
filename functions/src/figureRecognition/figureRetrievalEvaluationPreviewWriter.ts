import { promises as fs } from 'node:fs';
import path from 'node:path';
import type { StoredImage } from './imageEmbeddingTypes';
import type { PrimarySubjectPreviewArtifacts, PrimarySubjectResult } from './primarySubjectTypes';
import { PrimarySubjectPreviewWriter } from './primarySubjectPreviewWriter';

type PreviewFileSystem = Pick<typeof fs, 'mkdir' | 'stat' | 'writeFile'>;

export class FigureRetrievalEvaluationPreviewWriter {
  constructor(private readonly previews: PrimarySubjectPreviewWriter, private readonly fileSystem: PreviewFileSystem = fs) {}

  async write(root: string, caseId: string, source: StoredImage, result: PrimarySubjectResult, overwrite: boolean): Promise<PrimarySubjectPreviewArtifacts> {
    if (!safeCaseId(caseId)) throw new Error('Unsafe evaluation case ID');
    const directory = path.join(root, caseId);
    if (!overwrite) {
      try { await this.fileSystem.stat(directory); throw new Error(`Preview artifacts already exist for ${caseId}`); }
      catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
    }
    await this.fileSystem.mkdir(directory, { recursive: true });
    const candidates = result.status === 'no_subject' ? [] : result.candidates.map((candidate) => ({ box: candidate.normalized }));
    const artifacts = await this.previews.write(directory, caseId, source, candidates, result, overwrite);
    const diagnosticsName = `${caseId}.diagnostics.json`;
    await this.fileSystem.writeFile(path.join(directory, diagnosticsName), `${JSON.stringify(safeDiagnostics(caseId, result, artifacts), null, 2)}\n`, { flag: overwrite ? 'w' : 'wx' });
    return artifacts;
  }
}

function safeDiagnostics(caseId: string, result: PrimarySubjectResult, previews: PrimarySubjectPreviewArtifacts): Record<string, unknown> {
  const diagnostics = result.diagnostics;
  const selected = result.status === 'no_subject' ? undefined : result.candidates.find((candidate) => candidate.selected);
  const refinement = diagnostics.refinement;
  const segmentation = diagnostics.segmentation;
  return {
    caseId, isolationStatus: result.status, rejectionReason: result.status === 'usable' ? undefined : result.reason,
    sourceWidth: diagnostics.sourceWidth, sourceHeight: diagnostics.sourceHeight,
    cropWidth: diagnostics.cropWidth, cropHeight: diagnostics.cropHeight,
    sharpnessMetric: diagnostics.blurMetric, sharpnessThreshold: diagnostics.blurThreshold,
    detailMetric: diagnostics.detailMetric, detailThreshold: diagnostics.detailThreshold,
    combinedBlurPassed: diagnostics.combinedBlurPassed, subjectAreaRatio: diagnostics.subjectAreaRatio,
    normalizedBoundingBox: selected?.normalized, pixelBoundingBox: selected?.pixels,
    failedQualityChecks: diagnostics.failedChecks,
    refinement: refinement ? { attempted: refinement.attempted, accepted: refinement.accepted, reason: refinement.reason, coarseNormalizedBox: refinement.coarseNormalizedBox, refinedNormalizedBox: refinement.refinedNormalizedBox, coarsePixelBox: refinement.coarsePixelBox, refinedPixelBox: refinement.refinedPixelBox } : undefined,
    segmentation: segmentation ? { outcome: segmentation.status, fallbackUsed: segmentation.fallbackUsed, fallbackReason: segmentation.fallbackReason } : undefined,
    previewFilenames: { ...previews, diagnostics: `${caseId}.diagnostics.json` },
  };
}

function safeCaseId(value: string): boolean { return /^photo-[0-9]{4,}$/.test(value); }
