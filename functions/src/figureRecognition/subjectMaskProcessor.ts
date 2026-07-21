import sharp from 'sharp';
import type { PrimarySubjectConfig } from './primarySubjectConfig';
import type { PixelBoundingBox } from './primarySubjectTypes';
import type { StoredImage } from './imageEmbeddingTypes';
import type { SubjectMask, SubjectSegmentationPreview } from './subjectSegmentationTypes';

export type Point = readonly [number, number];
type SegmentationConfig = PrimarySubjectConfig['segmentation'];
type Component = { pixels: number[]; area: number; bounds: PixelBoundingBox; anchorPixels: number };

export type ProcessedSubjectMask = {
  mask: SubjectMask;
  tightBoundingBox: PixelBoundingBox;
  rawForegroundAreaRatio: number;
  finalForegroundAreaRatio: number;
  connectedComponentCount: number;
  acceptedPolygonPointCount: number;
};

export function validatePolygon(value: unknown, config: SegmentationConfig): Point[] {
  if (!Array.isArray(value) || value.length < 3 || value.length > config.maxPolygonPoints) throw new Error('invalid_point_count');
  const points: Point[] = value.map((point) => {
    if (!Array.isArray(point) || point.length !== 2 || !point.every((coordinate) => typeof coordinate === 'number' && Number.isFinite(coordinate))) throw new Error('invalid_coordinate');
    const [x, y] = point as [number, number];
    const overflow = config.normalizedBoundaryOverflow;
    if (x < -overflow || x > 1000 + overflow || y < -overflow || y > 1000 + overflow) throw new Error('coordinate_out_of_bounds');
    return [Math.min(1000, Math.max(0, x)), Math.min(1000, Math.max(0, y))];
  });
  if (new Set(points.map(([x, y]) => `${x}:${y}`)).size < 3) throw new Error('insufficient_distinct_points');
  if (Math.abs(signedArea(points)) < 0.000001) throw new Error('zero_area_polygon');
  if (hasSelfIntersection(points)) throw new Error('self_intersecting_polygon');
  return points;
}

export function rasterizeAndProcessPolygon(points: Point[], width: number, height: number, anchor: PixelBoundingBox, config: SegmentationConfig): ProcessedSubjectMask {
  if (!Number.isInteger(width) || !Number.isInteger(height) || width <= 0 || height <= 0) throw new Error('invalid_image_dimensions');
  const pixels = rasterize(points, width, height);
  return processBinaryMask(pixels, width, height, anchor, config, points.length);
}

/** Exported for deterministic unit testing and future provider-independent mask adapters. */
export function processBinaryMask(pixels: Uint8Array, width: number, height: number, anchor: PixelBoundingBox, config: SegmentationConfig, acceptedPolygonPointCount = 0): ProcessedSubjectMask {
  if (pixels.length !== width * height) throw new Error('mask_dimensions_mismatch');
  const total = width * height;
  const rawArea = countForeground(pixels);
  if (rawArea === 0) throw new Error('empty_foreground');
  const rawRatio = rawArea / total;
  if (rawRatio < config.minForegroundAreaRatio) throw new Error('foreground_too_small');
  if (rawRatio > config.maxForegroundAreaRatio) throw new Error('foreground_too_large');

  const insetAnchor = inset(anchor, config.anchorInsetRatio, width, height);
  const components = componentsOf(pixels, width, height, insetAnchor);
  const anchored = components.filter((component) => component.anchorPixels > 0).sort((a, b) => b.area - a.area);
  if (anchored.length === 0) throw new Error('foreground_misses_anchor');
  const main = anchored[0];
  const anchorOverlap = main.anchorPixels / Math.max(1, insetAnchor.width * insetAnchor.height);
  if (anchorOverlap < config.minAnchorOverlapRatio) throw new Error('foreground_anchor_overlap_too_small');

  const retained = components.filter((component) => component === main || (
    component.area / total >= config.minAttachedComponentAreaRatio && boxDistance(component.bounds, main.bounds) <= config.maxAttachedComponentDistance
  ));
  let processed: Uint8Array = new Uint8Array(total);
  for (const component of retained) for (const index of component.pixels) processed[index] = 255;
  processed = fillSmallHoles(processed, width, height, Math.min(config.maxHolePixels, Math.floor(total * config.maxHoleAreaRatio)));
  if (config.closingRadius > 0) processed = erode(dilate(processed, width, height, config.closingRadius), width, height, config.closingRadius);
  const finalArea = countForeground(processed);
  if (finalArea === 0) throw new Error('empty_processed_foreground');
  const finalRatio = finalArea / total;
  if (finalRatio < config.minForegroundAreaRatio || finalRatio > config.maxForegroundAreaRatio) throw new Error('processed_foreground_out_of_range');
  const rawBounds = foregroundBounds(processed, width, height);
  const tightBoundingBox = pad(rawBounds, config.safetyPaddingRatio, width, height);
  return {
    mask: { width, height, format: 'binary', data: processed, coordinateSpace: 'segmentation-input' },
    tightBoundingBox,
    rawForegroundAreaRatio: rawRatio,
    finalForegroundAreaRatio: finalRatio,
    connectedComponentCount: components.length,
    acceptedPolygonPointCount,
  };
}

export async function renderSegmentedSubject(image: StoredImage, processed: ProcessedSubjectMask): Promise<{ image: StoredImage; preview: SubjectSegmentationPreview }> {
  const { width, height, data } = processed.mask;
  const source = await sharp(image.bytes).rotate().ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  if (source.info.width !== width || source.info.height !== height || source.info.channels !== 4) throw new Error('render_dimensions_mismatch');
  const rgba = Buffer.from(source.data);
  for (let index = 0; index < width * height; index++) rgba[index * 4 + 3] = Math.round((rgba[index * 4 + 3] * data[index]) / 255);
  const box = processed.tightBoundingBox;
  const subjectBytes = await sharp(rgba, { raw: { width, height, channels: 4 } }).extract(box).png().toBuffer();
  const subject = { bytes: subjectBytes, mimeType: 'image/png' } as const;
  const maskBytes = await sharp(Buffer.from(data), { raw: { width, height, channels: 1 } }).png().toBuffer();
  const overlayPixels = Buffer.alloc(width * height * 4);
  for (let index = 0; index < width * height; index++) {
    overlayPixels[index * 4] = 0; overlayPixels[index * 4 + 1] = 230; overlayPixels[index * 4 + 2] = 118;
    overlayPixels[index * 4 + 3] = data[index] ? 92 : 0;
  }
  const stroke = Math.max(2, Math.round(width / 300));
  const svg = Buffer.from(`<svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg"><rect x="${box.left}" y="${box.top}" width="${box.width}" height="${box.height}" fill="none" stroke="#00e676" stroke-width="${stroke}"/></svg>`);
  const overlayBytes = await sharp(image.bytes).rotate().composite([
    { input: overlayPixels, raw: { width, height, channels: 4 } },
    { input: svg },
  ]).jpeg({ quality: 90 }).toBuffer();
  return { image: subject, preview: {
    mask: { bytes: maskBytes, mimeType: 'image/png' },
    overlay: { bytes: overlayBytes, mimeType: 'image/jpeg' },
    subject,
  } };
}

function signedArea(points: Point[]): number {
  let sum = 0;
  for (let index = 0; index < points.length; index++) {
    const [x1, y1] = points[index]; const [x2, y2] = points[(index + 1) % points.length];
    sum += x1 * y2 - x2 * y1;
  }
  return sum / 2;
}

function hasSelfIntersection(points: Point[]): boolean {
  for (let first = 0; first < points.length; first++) {
    const firstNext = (first + 1) % points.length;
    for (let second = first + 1; second < points.length; second++) {
      const secondNext = (second + 1) % points.length;
      if (first === second || firstNext === second || secondNext === first) continue;
      if (segmentsIntersect(points[first], points[firstNext], points[second], points[secondNext])) return true;
    }
  }
  return false;
}

function segmentsIntersect(a: Point, b: Point, c: Point, d: Point): boolean {
  const cross = (p: Point, q: Point, r: Point) => (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0]);
  const onSegment = (p: Point, q: Point, r: Point) => q[0] >= Math.min(p[0], r[0]) && q[0] <= Math.max(p[0], r[0]) && q[1] >= Math.min(p[1], r[1]) && q[1] <= Math.max(p[1], r[1]);
  const values = [cross(a, b, c), cross(a, b, d), cross(c, d, a), cross(c, d, b)];
  if ((values[0] > 0) !== (values[1] > 0) && (values[2] > 0) !== (values[3] > 0) && values.every((value) => value !== 0)) return true;
  return (values[0] === 0 && onSegment(a, c, b)) || (values[1] === 0 && onSegment(a, d, b)) ||
    (values[2] === 0 && onSegment(c, a, d)) || (values[3] === 0 && onSegment(c, b, d));
}

function rasterize(points: Point[], width: number, height: number): Uint8Array {
  const mapped = points.map(([x, y]) => [x / 1000 * width, y / 1000 * height] as Point);
  const result = new Uint8Array(width * height);
  for (let y = 0; y < height; y++) {
    const scanY = y + 0.5; const intersections: number[] = [];
    for (let index = 0; index < mapped.length; index++) {
      const [x1, y1] = mapped[index]; const [x2, y2] = mapped[(index + 1) % mapped.length];
      if ((y1 <= scanY && y2 > scanY) || (y2 <= scanY && y1 > scanY)) intersections.push(x1 + (scanY - y1) * (x2 - x1) / (y2 - y1));
    }
    intersections.sort((a, b) => a - b);
    for (let index = 0; index + 1 < intersections.length; index += 2) {
      const start = Math.max(0, Math.ceil(intersections[index] - 0.5));
      const end = Math.min(width - 1, Math.floor(intersections[index + 1] - 0.5));
      for (let x = start; x <= end; x++) result[y * width + x] = 255;
    }
  }
  return result;
}

function componentsOf(mask: Uint8Array, width: number, height: number, anchor: PixelBoundingBox): Component[] {
  const visited = new Uint8Array(mask.length); const result: Component[] = [];
  const directions = [-1, 0, 1];
  for (let seed = 0; seed < mask.length; seed++) {
    if (!mask[seed] || visited[seed]) continue;
    const queue = [seed]; visited[seed] = 1; const pixels: number[] = [];
    let minX = width; let minY = height; let maxX = -1; let maxY = -1; let anchorPixels = 0;
    for (let cursor = 0; cursor < queue.length; cursor++) {
      const index = queue[cursor]; const x = index % width; const y = Math.floor(index / width); pixels.push(index);
      minX = Math.min(minX, x); minY = Math.min(minY, y); maxX = Math.max(maxX, x); maxY = Math.max(maxY, y);
      if (inside(x, y, anchor)) anchorPixels++;
      for (const dy of directions) for (const dx of directions) {
        if (dx === 0 && dy === 0) continue;
        const nx = x + dx; const ny = y + dy; const next = ny * width + nx;
        if (nx >= 0 && nx < width && ny >= 0 && ny < height && mask[next] && !visited[next]) { visited[next] = 1; queue.push(next); }
      }
    }
    result.push({ pixels, area: pixels.length, bounds: { left: minX, top: minY, width: maxX - minX + 1, height: maxY - minY + 1 }, anchorPixels });
  }
  return result;
}

function fillSmallHoles(mask: Uint8Array, width: number, height: number, maxArea: number): Uint8Array {
  if (maxArea <= 0) return mask;
  const inverse = new Uint8Array(mask.length); for (let i = 0; i < mask.length; i++) inverse[i] = mask[i] ? 0 : 255;
  const holes = componentsOf(inverse, width, height, { left: 0, top: 0, width: 0, height: 0 });
  const result = mask.slice();
  for (const hole of holes) {
    const touchesEdge = hole.bounds.left === 0 || hole.bounds.top === 0 || hole.bounds.left + hole.bounds.width === width || hole.bounds.top + hole.bounds.height === height;
    if (!touchesEdge && hole.area <= maxArea) for (const index of hole.pixels) result[index] = 255;
  }
  return result;
}

function dilate(mask: Uint8Array, width: number, height: number, radius: number): Uint8Array {
  const result = new Uint8Array(mask.length);
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    for (let dy = -radius; dy <= radius && !result[y * width + x]; dy++) for (let dx = -radius; dx <= radius; dx++) {
      const nx = x + dx; const ny = y + dy;
      if (nx >= 0 && nx < width && ny >= 0 && ny < height && mask[ny * width + nx]) { result[y * width + x] = 255; break; }
    }
  }
  return result;
}

function erode(mask: Uint8Array, width: number, height: number, radius: number): Uint8Array {
  const result = new Uint8Array(mask.length);
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    let keep = true;
    for (let dy = -radius; dy <= radius && keep; dy++) for (let dx = -radius; dx <= radius; dx++) {
      const nx = x + dx; const ny = y + dy;
      if (nx < 0 || nx >= width || ny < 0 || ny >= height || !mask[ny * width + nx]) { keep = false; break; }
    }
    if (keep) result[y * width + x] = 255;
  }
  return result;
}

function foregroundBounds(mask: Uint8Array, width: number, height: number): PixelBoundingBox {
  let minX = width; let minY = height; let maxX = -1; let maxY = -1;
  for (let index = 0; index < mask.length; index++) if (mask[index]) { const x = index % width; const y = Math.floor(index / width); minX = Math.min(minX, x); minY = Math.min(minY, y); maxX = Math.max(maxX, x); maxY = Math.max(maxY, y); }
  if (maxX < minX || maxY < minY) throw new Error('invalid_mask_bounds');
  return { left: minX, top: minY, width: maxX - minX + 1, height: maxY - minY + 1 };
}

function pad(box: PixelBoundingBox, ratio: number, width: number, height: number): PixelBoundingBox {
  const left = Math.max(0, Math.floor(box.left - box.width * ratio)); const top = Math.max(0, Math.floor(box.top - box.height * ratio));
  const right = Math.min(width, Math.ceil(box.left + box.width * (1 + ratio))); const bottom = Math.min(height, Math.ceil(box.top + box.height * (1 + ratio)));
  return { left, top, width: right - left, height: bottom - top };
}

function inset(box: PixelBoundingBox, ratio: number, width: number, height: number): PixelBoundingBox {
  const insetX = Math.floor(box.width * ratio); const insetY = Math.floor(box.height * ratio);
  const left = Math.max(0, Math.min(width - 1, box.left + insetX)); const top = Math.max(0, Math.min(height - 1, box.top + insetY));
  const right = Math.max(left + 1, Math.min(width, box.left + box.width - insetX)); const bottom = Math.max(top + 1, Math.min(height, box.top + box.height - insetY));
  return { left, top, width: right - left, height: bottom - top };
}

function inside(x: number, y: number, box: PixelBoundingBox): boolean { return x >= box.left && y >= box.top && x < box.left + box.width && y < box.top + box.height; }
function countForeground(mask: Uint8Array): number { let count = 0; for (const value of mask) if (value) count++; return count; }
function boxDistance(a: PixelBoundingBox, b: PixelBoundingBox): number {
  const dx = Math.max(0, Math.max(a.left, b.left) - Math.min(a.left + a.width, b.left + b.width));
  const dy = Math.max(0, Math.max(a.top, b.top) - Math.min(a.top + a.height, b.top + b.height));
  return Math.max(dx, dy);
}
