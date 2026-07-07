import type {
  CatalogIpDoc,
  CatalogSeriesDoc,
  RecommendationItemWire,
  RecommendationProfile,
} from './types';
import { catalogExplorationFingerprint } from './catalogFingerprint';

export const MAX_RECOMMENDATIONS = 10;
export const MIN_RECOMMENDATIONS = 5;
export const MAX_SERIES_PER_IP = 2;
export const GAP_FILL_RECENT_POOL_SIZE = 20;
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

function gapFillSeed(profileHash: string, catalogFingerprint: string): number {
  const key = `gap_fill:${profileHash}:${catalogFingerprint}`;
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
    primaryReasonType: candidate.primaryReasonType,
    ...(candidate.primaryReasonMeta
      ? { primaryReasonMeta: candidate.primaryReasonMeta }
      : {}),
    ...(candidate.secondaryReasonType
      ? { secondaryReasonType: candidate.secondaryReasonType }
      : {}),
    ...(candidate.secondaryReasonMeta
      ? { secondaryReasonMeta: candidate.secondaryReasonMeta }
      : {}),
    reasonType: candidate.primaryReasonType,
    ...(candidate.primaryReasonMeta ? { reasonMeta: candidate.primaryReasonMeta } : {}),
  }));
}

interface ScoredCandidate {
  seriesId: string;
  score: number;
  primaryReasonType: RecommendationItemWire['primaryReasonType'];
  primaryReasonMeta?: string;
  secondaryReasonType?: RecommendationItemWire['secondaryReasonType'];
  secondaryReasonMeta?: string;
}

export function computeRecommendations(params: {
  profile: RecommendationProfile;
  series: CatalogSeriesDoc[];
  ips: CatalogIpDoc[];
  now?: Date;
}): RecommendationItemWire[] {
  const now = params.now ?? new Date();
  const trackedSeries = trackedCatalogSeriesSet(params.profile);
  const trackedIpIds = trackedIpIdSet(params.profile, params.series);
  const ipNameById = new Map(params.ips.map((ip) => [ip.id, ip.displayName]));
  const scored = new Map<string, ScoredCandidate>();

  const upsert = (
    series: CatalogSeriesDoc,
    score: number,
    primaryReasonType: RecommendationItemWire['primaryReasonType'],
    primaryReasonMeta?: string,
  ) => {
    const existing = scored.get(series.id);
    if (!existing || score > existing.score) {
      scored.set(series.id, {
        seriesId: series.id,
        score,
        primaryReasonType,
        primaryReasonMeta,
      });
    }
  };

  for (const series of params.series) {
    if (trackedSeries.has(series.id)) continue;
    if (trackedIpIds.has(series.ipId)) {
      upsert(
        series,
        30,
        'tracked_ip',
        ipNameById.get(series.ipId) ?? series.ipId,
      );
    }
  }

  for (const candidate of scored.values()) {
    const series = params.series.find((entry) => entry.id === candidate.seriesId);
    if (!series) continue;
    if (isRecentRelease(series.releaseDate, now)) {
      candidate.score += 10;
      candidate.secondaryReasonType = 'recent_release';
      candidate.secondaryReasonMeta = undefined;
    }
  }

  const orderIndex = buildOrderIndex(params.series);
  const seriesById = new Map(params.series.map((series) => [series.id, series]));
  const ranked = [...scored.values()].sort((a, b) =>
    compareRankedCandidates(a, b, seriesById, orderIndex),
  );
  const diversified = applyIpDiversity(
    ranked,
    (seriesId) => seriesById.get(seriesId)?.ipId ?? seriesId,
  );
  const results = composeCuratedResults(
    diversified,
    MAX_RECOMMENDATIONS,
    explorationSeed(
      params.profile.profileHash,
      catalogExplorationFingerprint(params.series),
    ),
  );

  if (results.length >= MIN_RECOMMENDATIONS) {
    return results;
  }

  const gapFillSorted = [...params.series].sort((a, b) =>
    compareSeriesNewestFirst(a, b, orderIndex),
  );
  const gapFillIpCounts = ipCountsForResults(results, seriesById);
  const catalogFingerprint = catalogExplorationFingerprint(params.series);

  appendGapFillResults({
    results,
    minimum: MIN_RECOMMENDATIONS,
    sortedCatalog: gapFillSorted,
    trackedSeries,
    scored,
    gapFillIpCounts,
    gapFillSeed: gapFillSeed(params.profile.profileHash, catalogFingerprint),
    now,
  });

  return results;
}

function appendGapFillResults(params: {
  results: RecommendationItemWire[];
  minimum: number;
  sortedCatalog: CatalogSeriesDoc[];
  trackedSeries: Set<string>;
  scored: Map<string, ScoredCandidate>;
  gapFillIpCounts: Map<string, number>;
  gapFillSeed: number;
  now: Date;
}): void {
  const eligible: CatalogSeriesDoc[] = [];
  for (const series of params.sortedCatalog) {
    if (params.trackedSeries.has(series.id)) continue;
    if (params.scored.has(series.id)) continue;
    eligible.push(series);
  }

  const recentPool = eligible.slice(0, GAP_FILL_RECENT_POOL_SIZE);
  const remainder = eligible.slice(GAP_FILL_RECENT_POOL_SIZE);

  const addFromCandidates = (
    candidates: CatalogSeriesDoc[],
    shuffle: boolean,
  ) => {
    const queue = [...candidates];
    if (shuffle) {
      const rng = mulberry32(params.gapFillSeed >>> 0);
      for (let i = queue.length - 1; i > 0; i--) {
        const j = Math.floor(rng() * (i + 1));
        [queue[i], queue[j]] = [queue[j], queue[i]];
      }
    }
    for (const series of queue) {
      if (params.results.length >= params.minimum) return;
      if (!canAddSeriesForIp(series.ipId, params.gapFillIpCounts, MAX_SERIES_PER_IP)) {
        continue;
      }
      params.gapFillIpCounts.set(
        series.ipId,
        (params.gapFillIpCounts.get(series.ipId) ?? 0) + 1,
      );
      params.results.push({
        seriesId: series.id,
        primaryReasonType: 'new_in_catalog',
        ...(isRecentRelease(series.releaseDate, params.now)
          ? { secondaryReasonType: 'recent_release' as const }
          : {}),
        reasonType: 'new_in_catalog',
      });
    }
  };

  addFromCandidates(recentPool, true);
  if (params.results.length < params.minimum) {
    addFromCandidates(remainder, false);
  }
}

function applyIpDiversity(
  ranked: ScoredCandidate[],
  ipIdForSeries: (seriesId: string) => string,
  maxPerIp = MAX_SERIES_PER_IP,
): ScoredCandidate[] {
  const ipCounts = new Map<string, number>();
  const diversified: ScoredCandidate[] = [];
  for (const candidate of ranked) {
    const ipId = ipIdForSeries(candidate.seriesId);
    if (!canAddSeriesForIp(ipId, ipCounts, maxPerIp)) continue;
    ipCounts.set(ipId, (ipCounts.get(ipId) ?? 0) + 1);
    diversified.push(candidate);
  }
  return diversified;
}

function canAddSeriesForIp(
  ipId: string,
  ipCounts: Map<string, number>,
  maxPerIp: number,
): boolean {
  return (ipCounts.get(ipId) ?? 0) < maxPerIp;
}

function ipCountsForResults(
  results: RecommendationItemWire[],
  seriesById: Map<string, CatalogSeriesDoc>,
): Map<string, number> {
  const ipCounts = new Map<string, number>();
  for (const item of results) {
    const ipId = seriesById.get(item.seriesId)?.ipId ?? item.seriesId;
    ipCounts.set(ipId, (ipCounts.get(ipId) ?? 0) + 1);
  }
  return ipCounts;
}

function trackedCatalogSeriesSet(profile: RecommendationProfile): Set<string> {
  const tracked = new Set(profile.trackedCatalogSeriesIds ?? []);
  if (tracked.size > 0) return tracked;
  // Legacy profiles uploaded before trackedCatalogSeriesIds shipped.
  for (const id of profile.ownedCatalogSeriesIds ?? []) tracked.add(id);
  for (const id of profile.wishlistCatalogSeriesIds ?? []) tracked.add(id);
  return tracked;
}

function trackedIpIdSet(
  profile: RecommendationProfile,
  series: CatalogSeriesDoc[],
): Set<string> {
  const explicit = (profile.trackedIpIds ?? []).filter((id) => id.trim().length > 0);
  if (explicit.length > 0) {
    return new Set(explicit);
  }
  const tracked = trackedCatalogSeriesSet(profile);
  const ids = new Set<string>();
  for (const entry of series) {
    if (tracked.has(entry.id) && entry.ipId) {
      ids.add(entry.ipId);
    }
  }
  return ids;
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
