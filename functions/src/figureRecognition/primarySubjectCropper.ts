import sharp from 'sharp';
import type { PrimarySubjectConfig } from './primarySubjectConfig';
import type { StoredImage } from './imageEmbeddingTypes';
import type { LocatorCandidate, NormalizedBoundingBox, PixelBoundingBox } from './primarySubjectTypes';

export type PreparedImage = { bytes: Buffer; width: number; height: number; hasAlpha: boolean };
export type PreparedCrop = { image: StoredImage; box: PixelBoundingBox; width: number; height: number; sharpness: number; gradientEnergy: number };

export class PrimarySubjectCropper {
  constructor(private readonly config: PrimarySubjectConfig) {}

  async orient(image: StoredImage): Promise<PreparedImage> {
    const result = await sharp(image.bytes).rotate().toBuffer({ resolveWithObject: true });
    if (!result.info.width || !result.info.height) throw new Error('Unable to determine oriented image dimensions');
    return { bytes: result.data, width: result.info.width, height: result.info.height, hasAlpha: result.info.channels === 2 || result.info.channels === 4 };
  }

  pixelBox(box: NormalizedBoundingBox, width: number, height: number, padded = true): PixelBoundingBox {
    if (box.xmin >= box.xmax || box.ymin >= box.ymax) throw new Error('Primary subject box is degenerate');
    let left = Math.floor((box.xmin / 1000) * width);
    let top = Math.floor((box.ymin / 1000) * height);
    let right = Math.ceil((box.xmax / 1000) * width);
    let bottom = Math.ceil((box.ymax / 1000) * height);
    if (padded) {
      const padX = (right - left) * this.config.paddingRatio;
      const padY = (bottom - top) * this.config.paddingRatio;
      left = Math.floor(left - padX); top = Math.floor(top - padY);
      right = Math.ceil(right + padX); bottom = Math.ceil(bottom + padY);
    }
    left = Math.max(0, left); top = Math.max(0, top);
    right = Math.min(width, right); bottom = Math.min(height, bottom);
    if (right <= left || bottom <= top) throw new Error('Primary subject box is degenerate');
    return { left, top, width: right - left, height: bottom - top };
  }

  async crop(prepared: PreparedImage, candidate: LocatorCandidate): Promise<PreparedCrop> {
    const box = this.pixelBox(candidate.box, prepared.width, prepared.height);
    return this.cropPixelBox(prepared, box);
  }

  async cropPixelBox(prepared: PreparedImage, box: PixelBoundingBox): Promise<PreparedCrop> {
    let pipeline = sharp(prepared.bytes).extract(box);
    if (Math.max(box.width, box.height) > this.config.maxProcessedDimension) {
      pipeline = pipeline.resize({ width: this.config.maxProcessedDimension, height: this.config.maxProcessedDimension, fit: 'inside', withoutEnlargement: true, kernel: 'lanczos3' });
    }
    const encoded = prepared.hasAlpha ? pipeline.png() : pipeline.jpeg({ quality: 92, chromaSubsampling: '4:4:4' });
    const result = await encoded.toBuffer({ resolveWithObject: true });
    const stats = await sharp(result.data).greyscale().stats();
    const grayscale = await sharp(result.data).greyscale().raw().toBuffer({ resolveWithObject: true });
    const gradientEnergy = meanAbsoluteGrayscaleGradient(grayscale.data, grayscale.info.width, grayscale.info.height);
    return { image: { bytes: result.data, mimeType: prepared.hasAlpha ? 'image/png' : 'image/jpeg' }, box, width: result.info.width, height: result.info.height, sharpness: stats.sharpness, gradientEnergy };
  }

  paddedPixelBox(box: PixelBoundingBox, ratio: number, sourceWidth: number, sourceHeight: number, containment?: PixelBoundingBox): PixelBoundingBox {
    const padX = box.width * ratio;
    const padY = box.height * ratio;
    const minLeft = containment?.left ?? 0;
    const minTop = containment?.top ?? 0;
    const maxRight = containment ? containment.left + containment.width : sourceWidth;
    const maxBottom = containment ? containment.top + containment.height : sourceHeight;
    const left = Math.max(minLeft, Math.floor(box.left - padX));
    const top = Math.max(minTop, Math.floor(box.top - padY));
    const right = Math.min(maxRight, Math.ceil(box.left + box.width + padX));
    const bottom = Math.min(maxBottom, Math.ceil(box.top + box.height + padY));
    if (right <= left || bottom <= top) throw new Error('Padded subject box is degenerate');
    return { left, top, width: right - left, height: bottom - top };
  }

  async overlay(prepared: PreparedImage, candidates: LocatorCandidate[], selectedIndex: number): Promise<Buffer> {
    const labels = candidates.map((candidate, index) => {
      const box = this.pixelBox(candidate.box, prepared.width, prepared.height, false);
      const selected = index === selectedIndex;
      const label = selected ? `Candidate ${index + 1} · Primary` : `Candidate ${index + 1}`;
      const colors = ['#00b0ff', '#ffca28', '#e040fb'];
      const color = selected ? '#00e676' : colors[index % colors.length];
      return `<rect x="${box.left}" y="${box.top}" width="${box.width}" height="${box.height}" fill="none" stroke="${color}" stroke-width="${Math.max(3, Math.round(prepared.width / 300))}"/><rect x="${box.left}" y="${box.top}" width="${Math.max(110, label.length * 16)}" height="30" fill="${color}"/><text x="${box.left + 6}" y="${box.top + 22}" font-family="sans-serif" font-size="20" fill="#111">${label}</text>`;
    }).join('');
    const svg = Buffer.from(`<svg width="${prepared.width}" height="${prepared.height}" xmlns="http://www.w3.org/2000/svg">${labels}</svg>`);
    return sharp(prepared.bytes).composite([{ input: svg }]).jpeg({ quality: 90 }).toBuffer();
  }

  async refinementOverlay(prepared: PreparedImage, coarse: PixelBoundingBox, refined?: PixelBoundingBox): Promise<Buffer> {
    const boxes = [svgBox(coarse, 'coarse', '#ffca28', prepared.width)];
    if (refined) boxes.push(svgBox(refined, 'refined', '#00e676', prepared.width));
    const svg = Buffer.from(`<svg width="${prepared.width}" height="${prepared.height}" xmlns="http://www.w3.org/2000/svg">${boxes.join('')}</svg>`);
    return sharp(prepared.bytes).composite([{ input: svg }]).jpeg({ quality: 90 }).toBuffer();
  }
}

function svgBox(box: PixelBoundingBox, label: string, color: string, sourceWidth: number): string {
  return `<rect x="${box.left}" y="${box.top}" width="${box.width}" height="${box.height}" fill="none" stroke="${color}" stroke-width="${Math.max(3, Math.round(sourceWidth / 300))}"/><rect x="${box.left}" y="${box.top}" width="${Math.max(100, label.length * 16)}" height="30" fill="${color}"/><text x="${box.left + 6}" y="${box.top + 22}" font-family="sans-serif" font-size="20" fill="#111">${label}</text>`;
}

/** Mean absolute horizontal/vertical grayscale gradient, evaluated at crop resolution. */
export function meanAbsoluteGrayscaleGradient(pixels: Buffer, width: number, height: number): number {
  if (width < 2 || height < 2 || pixels.length < width * height) return 0;
  let total = 0;
  let comparisons = 0;
  for (let y = 0; y < height; y++) {
    const row = y * width;
    for (let x = 0; x < width; x++) {
      const index = row + x;
      if (x > 0) { total += Math.abs(pixels[index] - pixels[index - 1]); comparisons++; }
      if (y > 0) { total += Math.abs(pixels[index] - pixels[index - width]); comparisons++; }
    }
  }
  return comparisons === 0 ? 0 : total / comparisons;
}
