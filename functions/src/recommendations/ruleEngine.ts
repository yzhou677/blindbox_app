import type {
  CatalogIpDoc,
  CatalogSeriesDoc,
  RecommendationItemWire,
  RecommendationProfile,
} from './types';
import { catalogExplorationFingerprint } from './catalogFingerprint';

export const MAX_RECOMMENDATIONS = 10;
const EXPLORATION_RATIO = 0.2;
const RECENCY_WINDOW_DAYS = 90;

function stableSlotCount(limit = MAX_RECOMMENDATIONS): number {
  return Math.round(limit * (1 - EXPLORATION_RATIO));
}

function explorationSlotCount(limit = MAX_RECOMMENDATIONS): number {
  return limit - stableSlotCount(limit);
}

function explorationSeed(profileHash: string, catalogFingerprint: string): number {
  const key = `${profileHash}:${catalogFingerprint}`;
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
  const trackedSeries = trackedCatalogSeriesSet(params.profile);
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
    if (trackedSeries.has(series.id)) continue;
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
    if (trackedSeries.has(series.id) || wishlistSeries.has(series.id)) continue;
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

  const orderIndex = buildOrderIndex(params.series);
  const seriesById = new Map(params.series.map((series) => [series.id, series]));
  const ranked = [...scored.values()].sort((a, b) =>
    compareRankedCandidates(a, b, seriesById, orderIndex),
  );
  const results = composeCuratedResults(
    ranked,
    MAX_RECOMMENDATIONS,
    explorationSeed(
      params.profile.profileHash,
      catalogExplorationFingerprint(params.series),
    ),
  );

  if (results.length >= MAX_RECOMMENDATIONS) {
    return results;
  }

  const gapFill = [...params.series].sort((a, b) =>
    compareSeriesNewestFirst(a, b, orderIndex),
  );

  for (const series of gapFill) {
    if (results.length >= MAX_RECOMMENDATIONS) break;
    if (trackedSeries.has(series.id)) continue;
    if (scored.has(series.id)) continue;
    results.push({ seriesId: series.id, reasonType: 'new_in_catalog' });
  }

  return results;
}

function trackedCatalogSeriesSet(profile: RecommendationProfile): Set<string> {
  const tracked = new Set(profile.trackedCatalogSeriesIds ?? []);
  if (tracked.size > 0) return tracked;
  // Legacy profiles uploaded before trackedCatalogSeriesIds shipped.
  for (const id of profile.ownedCatalogSeriesIds) tracked.add(id);
  for (const id of profile.wishlistCatalogSeriesIds) tracked.add(id);
  return tracked;
}

function buildOrderIndex(series: CatalogSeriesDoc[]): Map<string, number> {
  const orderIndex = new Map<string, number>();
  series.forEach((entry, index) => {
    orderIndex.set(entry.id, index);
  });
  return orderIndex;
}

function compareRankedCandidates(
  a: ScoredCandidate,
  b: ScoredCandidate,
  seriesById: Map<string, CatalogSeriesDoc>,
  orderIndex: Map<string, number>,
): number {
  const byScore = b.score - a.score;
  if (byScore !== 0) return byScore;
  const seriesA = seriesById.get(a.seriesId);
  const seriesB = seriesById.get(b.seriesId);
  if (!seriesA || !seriesB) return 0;
  return compareSeriesNewestFirst(seriesA, seriesB, orderIndex);
}

function compareSeriesNewestFirst(
  a: CatalogSeriesDoc,
  b: CatalogSeriesDoc,
  orderIndex: Map<string, number>,
): number {
  const parsedA = a.releaseDate ? Date.parse(a.releaseDate) : Number.NaN;
  const parsedB = b.releaseDate ? Date.parse(b.releaseDate) : Number.NaN;
  if (!Number.isNaN(parsedA) && !Number.isNaN(parsedB)) {
    const byDate = parsedB - parsedA;
    if (byDate !== 0) return byDate;
  } else if (!Number.isNaN(parsedA)) {
    return -1;
  } else if (!Number.isNaN(parsedB)) {
    return 1;
  }
  const ia = orderIndex.get(a.id) ?? 0;
  const ib = orderIndex.get(b.id) ?? 0;
  return ib - ia;
}

function isRecentRelease(releaseDate: string | null | undefined, now: Date): boolean {
  if (!releaseDate) return false;
  const parsed = Date.parse(releaseDate);
  if (Number.isNaN(parsed)) return false;
  const diffDays = (now.getTime() - parsed) / (1000 * 60 * 60 * 24);
  return diffDays <= RECENCY_WINDOW_DAYS;
}
