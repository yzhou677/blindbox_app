import { promises as fs } from 'node:fs';
import path from 'node:path';
import type { FigureRetrievalEvaluationManifest, FigureRetrievalEvaluationManifestPhoto, ResolvedFigureRetrievalEvaluationCase } from './figureRetrievalEvaluationTypes';

type ManifestFileSystem = Pick<typeof fs, 'readFile'>;
type PreflightImageReader = { read(filePath: string): Promise<unknown> };

export class FigureRetrievalEvaluationManifestLoader {
  constructor(private readonly images: PreflightImageReader, private readonly fileSystem: ManifestFileSystem = fs) {}

  async load(manifestPath: string): Promise<{ version: 1; dataset: string; photos: ResolvedFigureRetrievalEvaluationCase[] }> {
    if (!manifestPath.trim()) throw new Error('Manifest path is required');
    let contents: string;
    try { contents = await this.fileSystem.readFile(manifestPath, 'utf8'); }
    catch (error) {
      if ((error as { code?: unknown })?.code === 'ENOENT') {
        throw new Error('No evaluation manifest found. You can start by copying tools/figure-retrieval-evaluation-manifest.example.json to your local evaluation directory and editing it.');
      }
      throw new Error('Evaluation manifest could not be read');
    }
    let parsed: unknown;
    try { parsed = JSON.parse(contents); } catch { throw new Error('Manifest is not valid JSON'); }
    const manifest = validateManifest(parsed);
    const base = path.dirname(path.resolve(manifestPath));
    const resolved = manifest.photos.map(({ file, ...entry }, index) => ({ ...entry, id: `photo-${String(index + 1).padStart(4, '0')}`, filePath: path.isAbsolute(file) ? path.normalize(file) : path.resolve(base, file) }));
    rejectDuplicatePaths(resolved.map((entry) => entry.filePath));
    // Complete local preflight before any provider or retrieval call.
    for (const entry of resolved) {
      try { await this.images.read(entry.filePath); } catch { throw new Error(`Manifest case ${entry.id} references a missing or unsupported image`); }
    }
    return { version: 1, dataset: manifest.dataset, photos: resolved };
  }
}

export function validateManifest(value: unknown): FigureRetrievalEvaluationManifest {
  if (!exactObject(value, ['version', 'dataset', 'photos']) || value.version !== 1 || !validDataset(value.dataset) || !Array.isArray(value.photos) || value.photos.length === 0) throw new Error('Manifest version 1 with dataset and non-empty photos is required');
  const photos = value.photos.map((entry, index) => validatePhoto(entry, index));
  rejectDuplicatePaths(photos.map((photo) => photo.file));
  return { version: 1, dataset: value.dataset, photos };
}

function validatePhoto(value: unknown, index: number): FigureRetrievalEvaluationManifestPhoto {
  const allowed = ['file', 'expectedFigureId', 'catalogPresence', 'notes'];
  if (!objectWithAllowedKeys(value, allowed)) throw new Error(`Manifest photo ${index + 1} is malformed`);
  if (typeof value.file !== 'string' || !value.file.trim()) throw new Error(`Manifest photo ${index + 1} requires file`);
  if (value.catalogPresence !== 'present' && value.catalogPresence !== 'absent') throw new Error(`Manifest photo ${index + 1} has invalid catalogPresence`);
  const expectedFigureId = optionalId(value.expectedFigureId, 'expectedFigureId', index + 1);
  if (value.catalogPresence === 'present' && !expectedFigureId) throw new Error(`Manifest photo ${index + 1} requires expectedFigureId`);
  if (value.catalogPresence === 'absent' && Object.hasOwn(value, 'expectedFigureId')) throw new Error(`Manifest photo ${index + 1} must omit expectedFigureId`);
  if (value.notes !== undefined && (typeof value.notes !== 'string' || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(value.notes))) throw new Error(`Manifest photo ${index + 1} has invalid notes`);
  return { file: value.file, catalogPresence: value.catalogPresence, expectedFigureId, notes: value.notes as string | undefined };
}

function exactObject(value: unknown, keys: string[]): value is Record<string, unknown> { return objectWithAllowedKeys(value, keys) && Object.keys(value).length === keys.length; }
function objectWithAllowedKeys(value: unknown, keys: string[]): value is Record<string, unknown> { return typeof value === 'object' && value !== null && !Array.isArray(value) && Object.keys(value).every((key) => keys.includes(key)); }
function safeId(value: unknown): value is string { return typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(value); }
function optionalId(value: unknown, field: string, id: unknown): string | undefined {
  if (value === undefined || value === null) return undefined;
  if (!safeId(value)) throw new Error(`Manifest case ${String(id)} has invalid ${field}`);
  return value;
}
function validDataset(value: unknown): value is string { return typeof value === 'string' && value.trim().length > 0 && value.length <= 128 && !/[\u0000-\u001f]/.test(value); }
function rejectDuplicatePaths(paths: string[]): void {
  const seen = new Set<string>();
  for (const value of paths) {
    const normalized = path.normalize(value).toLowerCase();
    if (seen.has(normalized)) throw new Error('Manifest contains duplicate photo file paths');
    seen.add(normalized);
  }
}
