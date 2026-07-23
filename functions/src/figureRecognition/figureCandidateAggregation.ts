import type { EmbeddingImageRole } from './catalogEmbeddingIds';
import type { FigureRetrievalCandidate } from './figureRetrievalTypes';

export type ImageLevelRetrievalMatch = Omit<FigureRetrievalCandidate, 'rank'> & {
  imageRole?: EmbeddingImageRole;
  variant?: string;
  matchedImageKey?: string;
};

export type FigureCandidateAggregationStats = {
  candidateImageCount: number;
  candidateFigureCount: number;
  alternativeMatchCount: number;
  winningImageRole?: EmbeddingImageRole;
  winningVariant?: string;
};

/**
 * Collapse image-level vector hits to one row per figureId, keeping the best
 * (lowest) cosine distance. Tie-break among equal distances prefers the first
 * encounter after distance-then-figureId sort of the image matches — which for
 * equal distance is deterministic by figureId, then stable input order for the
 * same figure's images.
 *
 * When every figure appears once (legacy primary-only embeddings), this is an
 * identity transform aside from re-assigning rank.
 */
export function aggregateFigureCandidates(
  imageMatches: ImageLevelRetrievalMatch[],
): { candidates: FigureRetrievalCandidate[]; stats: FigureCandidateAggregationStats } {
  const sorted = [...imageMatches].sort(
    (left, right) => left.distance - right.distance || left.figureId.localeCompare(right.figureId),
  );

  const bestByFigure = new Map<string, ImageLevelRetrievalMatch>();
  let alternativeMatchCount = 0;
  for (const match of sorted) {
    if (match.imageRole === 'alternative') alternativeMatchCount += 1;
    const existing = bestByFigure.get(match.figureId);
    if (!existing || match.distance < existing.distance) {
      bestByFigure.set(match.figureId, match);
    }
  }

  const candidates = [...bestByFigure.values()]
    .sort((left, right) => left.distance - right.distance || left.figureId.localeCompare(right.figureId))
    .map((match, index) => toFigureCandidate(match, index + 1));

  const top = candidates[0];
  return {
    candidates,
    stats: {
      candidateImageCount: imageMatches.length,
      candidateFigureCount: candidates.length,
      alternativeMatchCount,
      winningImageRole: top?.imageRole,
      winningVariant: top?.variant,
    },
  };
}

function toFigureCandidate(match: ImageLevelRetrievalMatch, rank: number): FigureRetrievalCandidate {
  const candidate: FigureRetrievalCandidate = {
    figureId: match.figureId,
    seriesId: match.seriesId,
    brandId: match.brandId,
    ipId: match.ipId,
    isSecret: match.isSecret,
    distance: match.distance,
    rank,
    embeddingSpace: match.embeddingSpace,
  };
  if (match.imageRole) candidate.imageRole = match.imageRole;
  if (match.variant) candidate.variant = match.variant;
  if (match.matchedImageKey) candidate.matchedImageKey = match.matchedImageKey;
  return candidate;
}
