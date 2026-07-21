import { promises as fs } from 'node:fs';
import path from 'node:path';
import type { StoredImage } from './imageEmbeddingTypes';
import { PrimarySubjectCropper } from './primarySubjectCropper';
import type { LocatorCandidate, PrimarySubjectPreviewArtifacts, PrimarySubjectResult } from './primarySubjectTypes';

type PreviewFileSystem = Pick<typeof fs, 'mkdir' | 'writeFile'>;

export class PrimarySubjectPreviewWriter {
  constructor(private readonly cropper: PrimarySubjectCropper, private readonly fileSystem: PreviewFileSystem = fs) {}
  async write(directory: string, sourceBasename: string, source: StoredImage, candidates: LocatorCandidate[], result: PrimarySubjectResult, overwrite: boolean): Promise<PrimarySubjectPreviewArtifacts> {
    await this.fileSystem.mkdir(directory, { recursive: true });
    const stem = safeStem(sourceBasename);
    const prepared = await this.cropper.orient(source);
    if (result.status === 'no_subject') return {};
    const refinement = result.diagnostics.refinement;
    const coarseBox = refinement?.coarsePixelBox ?? result.candidates.find((candidate) => candidate.selected)?.pixels;
    if (!coarseBox) throw new Error('Selected coarse box is required for previews');
    const coarseOverlay = `${stem}.coarse-subject-overlay.jpg`;
    const refinedOverlay = `${stem}.refined-subject-overlay.jpg`;
    await this.writeOne(path.join(directory, coarseOverlay), await this.cropper.refinementOverlay(prepared, coarseBox), overwrite);
    await this.writeOne(path.join(directory, refinedOverlay), await this.cropper.refinementOverlay(prepared, coarseBox, refinement?.refinedPixelBox), overwrite);
    const coarseExtension = result.previewCrops.coarse.mimeType === 'image/png' ? 'png' : 'jpg';
    const finalExtension = result.previewCrops.final.mimeType === 'image/png' ? 'png' : 'jpg';
    const coarseCrop = `${stem}.coarse-subject-crop.${coarseExtension}`;
    const finalCrop = `${stem}.subject-crop.${finalExtension}`;
    await this.writeOne(path.join(directory, coarseCrop), result.previewCrops.coarse.bytes, overwrite);
    await this.writeOne(path.join(directory, finalCrop), result.previewCrops.final.bytes, overwrite);
    const artifacts: PrimarySubjectPreviewArtifacts = { coarseOverlay, refinedOverlay, coarseCrop, crop: finalCrop };
    if (result.status === 'usable' && result.previewCrops.segmentation) {
      const segmentationMask = `${stem}.segmentation-mask.png`;
      const segmentedOverlay = `${stem}.segmented-overlay.jpg`;
      const segmentedSubject = `${stem}.segmented-subject.png`;
      await this.writeOne(path.join(directory, segmentationMask), result.previewCrops.segmentation.mask.bytes, overwrite);
      await this.writeOne(path.join(directory, segmentedOverlay), result.previewCrops.segmentation.overlay.bytes, overwrite);
      await this.writeOne(path.join(directory, segmentedSubject), result.previewCrops.segmentation.subject.bytes, overwrite);
      artifacts.segmentationMask = segmentationMask;
      artifacts.segmentedOverlay = segmentedOverlay;
      artifacts.segmentedSubject = segmentedSubject;
    }
    if (result.status === 'usable') {
      const extension = result.previewCrops.embeddingInput.mimeType === 'image/png' ? 'png' : 'jpg';
      const embeddingInput = `${stem}.embedding-input.${extension}`;
      await this.writeOne(path.join(directory, embeddingInput), result.previewCrops.embeddingInput.bytes, overwrite);
      artifacts.embeddingInput = embeddingInput;
    }
    if (result.status === 'usable') {
      const segmentationJson = `${stem}.segmentation.json`;
      const segmentation = result.diagnostics.segmentation;
      const safeDiagnostics = {
        method: segmentation?.method,
        model: segmentation?.modelVersion,
        promptVersion: segmentation?.promptVersion,
        foregroundAreaRatio: segmentation?.finalForegroundAreaRatio,
        connectedComponentCount: segmentation?.connectedComponentCount,
        tightBoundingBox: segmentation?.tightBoundingBox,
        imageWidth: segmentation?.sourceWidth,
        imageHeight: segmentation?.sourceHeight,
        outcome: segmentation?.status === 'segmented' ? 'segmented' : 'refined_crop_fallback',
        fallbackUsed: segmentation?.fallbackUsed ?? true,
        fallbackReason: segmentation?.fallbackReason,
        elapsedMs: segmentation?.elapsedMs,
      };
      await this.writeOne(path.join(directory, segmentationJson), Buffer.from(`${JSON.stringify(safeDiagnostics, null, 2)}\n`), overwrite);
      artifacts.segmentationJson = segmentationJson;
    }
    return artifacts;
  }
  private async writeOne(filePath: string, bytes: Buffer, overwrite: boolean): Promise<void> {
    await this.fileSystem.writeFile(filePath, bytes, { flag: overwrite ? 'w' : 'wx' });
  }
}

function safeStem(sourceBasename: string): string {
  const stem = path.parse(sourceBasename).name.replace(/[^a-zA-Z0-9._-]+/g, '-');
  return stem || 'image';
}
