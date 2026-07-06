import type {
  CatalogIpDoc,
  CatalogSeriesDoc,
  RecommendationItemWire,
  RecommendationProfile,
} from './types';

const MAX_RECOMMENDATIONS = 10;
const EXPLORATION_RATIO = 0.2;
const RECENCY_WINDOW_DAYS = 90;

function stableSlotCount(limit = MAX_RECOMMENDATIONS): number {
  return Math.round(limit * (1 - EXPLORATION_RATIO));
}

function explorationSlotCount(limit = MAX_RECOMMENDATIONS): number {
  return limit - stableSlotCount(limit);
}

function explorationSeed(profileHash: string, now: Date): number {
  const year = now.getUTCFullYear();
  const yearStart = Date.UTC(year, 0, 1);
  const weekBucket =
    year * 1000 +
    Math.floor((now.getTime() - yearStart) / (7 * 24 * 60 * 60 * 1000));
  const key = `${profileHash}:${weekBucket}`;
  let hash = 0;
  for (let i = 0; i < key.length; i++) {
    hash = (hash * 31 + key.charCodeAt(i)) | 0;
  }
  return hash;
}

function mulberry32(seed: number): () => number {
  let t = seed >>> 0;
  return () => {
    t += 0x6d2b79f5;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r ^= r + Math.imul(r ^ (r >>> 7), 61 | r);
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

function pickExploration<T>(pool: T[], count: number, seed: number): T[] {
  if (pool.length === 0 || count <= 0) return [];
  const rng = mulberry32(seed);
  const copy = [...pool];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy.slice(0, count);
}

function composeCuratedResults(
  ranked: ScoredCandidate[],
  limit: number,
  seed: number,
): RecommendationItemWire[] {
  if (ranked.length === 0) return [];

  const stableSlots = stableSlotCount(limit);
  const exploreSlots = explorationSlotCount(limit);
  const stableCount = Math.min(stableSlots, ranked.length);
  const stable = ranked.slice(0, stableCount);
  const explorePool = ranked.slice(stableCount);
  const explored = pickExploration(
    explorePool,
    Math.min(exploreSlots, limit - stableCount),
    seed,
  );

  return [...stable, ...explored].map((candidate) => ({
    seriesId: candidate.seriesId,
    reasonType: candidate.reasonType,
    ...(candidate.reasonMeta ? { reasonMeta: candidate.reasonMeta } : {}),
  }));
}

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
  const results = composeCuratedResults(
    ranked,
    MAX_RECOMMENDATIONS,
    explorationSeed(params.profile.profileHash, now),
  );

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
