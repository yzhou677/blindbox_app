import { promises as fs } from 'node:fs';
import type { QueryImageReader } from './figureRetrievalTypes';
import type { StoredImage } from './imageEmbeddingTypes';

type FileStat = { isFile(): boolean };
type LocalFileSystem = {
  stat(path: string): Promise<FileStat>;
  readFile(path: string): Promise<Buffer>;
};

export class LocalImageReader implements QueryImageReader {
  constructor(private readonly fileSystem: LocalFileSystem = fs) {}

  async read(filePath: string): Promise<StoredImage> {
    if (!filePath.trim()) throw new Error('Local image path is required');
    let stat: FileStat;
    try {
      stat = await this.fileSystem.stat(filePath);
    } catch {
      throw new Error('Local image file does not exist');
    }
    if (!stat.isFile()) throw new Error('Local image path must reference a regular file');
    const bytes = await this.fileSystem.readFile(filePath);
    return { bytes, mimeType: detectImageMimeType(bytes) };
  }
}

export function detectImageMimeType(bytes: Buffer): string {
  if (bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
  if (bytes.length >= 12 && bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP') return 'image/webp';
  if (bytes.length >= 2 && bytes.toString('ascii', 0, 2) === 'BM') return 'image/bmp';
  if (bytes.length >= 12 && bytes.toString('ascii', 4, 8) === 'ftyp') {
    const brand = bytes.toString('ascii', 8, 12);
    if (brand === 'avif' || brand === 'avis') return 'image/avif';
    if (['heic', 'heix', 'hevc', 'hevx'].includes(brand)) return 'image/heic';
    if (brand === 'mif1' || brand === 'msf1') return 'image/heif';
  }
  throw new Error('Unsupported local image type');
}
