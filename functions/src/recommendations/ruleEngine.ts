import type {
  CatalogIpDoc,
  CatalogSeriesDoc,
  RecommendationItemWire,
  RecommendationProfile,
} from './types';

const MAX_RECOMMENDATIONS = 20;
const RECENCY_WINDOW_DAYS = 90;

interface ScoredCandidate {
  seriesId: string;
  score: number;
  reasonType: RecommendationItemWire['reasonType'];
  reasonMeta?: string;
}

export function computeRecommendations(params: {
  profile: RecommendationProfile;
  series: CatalogSeriesDoc[];
  ips: CatalogIpDoc[];
  now?: Date;
}): RecommendationItemWire[] {
  const now = params.now ?? new Date();
  const ownedSeries = new Set(params.profile.ownedCatalogSeriesIds);
  const wishlistSeries = new Set(params.profile.wishlistCatalogSeriesIds);
  const ownedIpIds = new Set(params.profile.ownedIpIds);
  const wishlistIpIds = new Set(params.profile.wishlistIpIds);
  const ipNameById = new Map(params.ips.map((ip) => [ip.id, ip.displayName]));
  const scored = new Map<string, ScoredCandidate>();

  const upsert = (
    series: CatalogSeriesDoc,
    score: number,
    reasonType: RecommendationItemWire['reasonType'],
    reasonMeta?: string,
  ) => {
    const existing = scored.get(series.id);
    if (!existing || score > existing.score) {
      scored.set(series.id, { seriesId: series.id, score, reasonType, reasonMeta });
    }
  };

  for (const series of params.series) {
    if (ownedSeries.has(series.id)) continue;
    if (ownedIpIds.has(series.ipId)) {
      upsert(
        series,
        30,
        'owned_ip',
        ipNameById.get(series.ipId) ?? series.ipId,
      );
    }
  }

  for (const series of params.series) {
    if (ownedSeries.has(series.id) || wishlistSeries.has(series.id)) continue;
    if (scored.has(series.id)) continue;
    if (wishlistIpIds.has(series.ipId)) {
      upsert(
        series,
        25,
        'wishlist_ip',
        ipNameById.get(series.ipId) ?? series.ipId,
      );
    }
  }

  for (const candidate of scored.values()) {
    const series = params.series.find((entry) => entry.id === candidate.seriesId);
    if (!series) continue;
    if (isRecentRelease(series.releaseDate, now)) {
      candidate.score += 10;
      candidate.reasonType = 'recent_release';
      candidate.reasonMeta = undefined;
    }
  }

  const ranked = [...scored.values()].sort((a, b) => b.score - a.score);
  const results: RecommendationItemWire[] = ranked
    .slice(0, MAX_RECOMMENDATIONS)
    .map((candidate) => ({
      seriesId: candidate.seriesId,
      reasonType: candidate.reasonType,
      ...(candidate.reasonMeta ? { reasonMeta: candidate.reasonMeta } : {}),
    }));

  if (results.length >= MAX_RECOMMENDATIONS) {
    return results;
  }

  const gapFill = [...params.series].sort((a, b) =>
    compareNewestFirst(a.releaseDate, b.releaseDate),
  );

  for (const series of gapFill) {
    if (results.length >= MAX_RECOMMENDATIONS) break;
    if (ownedSeries.has(series.id)) continue;
    if (scored.has(series.id)) continue;
    results.push({ seriesId: series.id, reasonType: 'new_in_catalog' });
  }

  return results;
}

function isRecentRelease(releaseDate: string | null | undefined, now: Date): boolean {
  if (!releaseDate) return false;
  const parsed = Date.parse(releaseDate);
  if (Number.isNaN(parsed)) return false;
  const diffDays = (now.getTime() - parsed) / (1000 * 60 * 60 * 24);
  return diffDays <= RECENCY_WINDOW_DAYS;
}

function compareNewestFirst(
  a: string | null | undefined,
  b: string | null | undefined,
): number {
  const da = a ? Date.parse(a) : Number.NaN;
  const db = b ? Date.parse(b) : Number.NaN;
  if (!Number.isNaN(da) && !Number.isNaN(db)) return db - da;
  if (!Number.isNaN(da)) return -1;
  if (!Number.isNaN(db)) return 1;
  return 0;
}
