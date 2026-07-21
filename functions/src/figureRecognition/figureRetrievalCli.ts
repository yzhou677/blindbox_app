import { DEFAULT_TOP_K, validateTopK } from './figureRetrievalService';
import type { FigureRetrievalCandidate } from './figureRetrievalTypes';

export type FigureRetrievalCliOptions = { file: string; topK: number };

export function parseFigureRetrievalArgs(args: string[]): FigureRetrievalCliOptions {
  let file: string | undefined;
  let topK = DEFAULT_TOP_K;
  for (let index = 0; index < args.length; index++) {
    const arg = args[index];
    if (arg === '--file') {
      const value = args[++index];
      if (!value || value.startsWith('--')) throw new Error('--file requires a local image path');
      file = value;
    } else if (arg === '--top-k') {
      const value = args[++index];
      topK = Number(value);
      validateTopK(topK);
    } else throw new Error(`Unknown option: ${arg}`);
  }
  if (!file) throw new Error('--file is required');
  return { file, topK };
}

export function formatFigureRetrievalCandidate(candidate: FigureRetrievalCandidate): string[] {
  return [
    `Rank ${candidate.rank}`,
    `figureId: ${candidate.figureId}`,
    `seriesId: ${candidate.seriesId}`,
    `brandId: ${candidate.brandId}`,
    `ipId: ${candidate.ipId}`,
    `isSecret: ${candidate.isSecret}`,
    `distance: ${candidate.distance}`,
  ];
}
