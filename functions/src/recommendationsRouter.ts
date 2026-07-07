import type { Request, Response } from 'express';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { catalogExplorationFingerprint } from './recommendations/catalogFingerprint';
import {
  computeRecommendations,
  MAX_RECOMMENDATIONS,
} from './recommendations/ruleEngine';
import type {
  CatalogIpDoc,
  CatalogSeriesDoc,
  RecommendationProfile,
} from './recommendations/types';

function firestore() {
  return getFirestore();
}

export async function handleRecommendationProfileRequest(
  req: Request,
  res: Response,
): Promise<void> {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }

  const body = req.body as Partial<RecommendationProfile>;
  const installId = (body.installId ?? '').trim();
  if (!installId) {
    res.status(400).json({ error: 'invalid_install_id' });
    return;
  }

  const profile: RecommendationProfile = {
    installId,
    trackedCatalogSeriesIds: normalizeIdList(body.trackedCatalogSeriesIds),
    ownedCatalogSeriesIds: normalizeIdList(body.ownedCatalogSeriesIds),
    wishlistCatalogSeriesIds: normalizeIdList(body.wishlistCatalogSeriesIds),
    trackedIpIds: normalizeIdList(body.trackedIpIds),
    wishlistIpIds: normalizeIdList(body.wishlistIpIds),
    profileHash: (body.profileHash ?? '').trim(),
  };

  if (!profile.profileHash) {
    res.status(400).json({ error: 'invalid_profile_hash' });
    return;
  }

  const validSeriesIds = await validateSeriesIds(profile.trackedCatalogSeriesIds);
  if (!validSeriesIds) {
    res.status(400).json({ error: 'invalid_series_ids' });
    return;
  }

  const profileRef = firestore().collection('recommendation_profiles').doc(installId);
  const existing = await profileRef.get();
  const existingHash = existing.exists
    ? String(existing.data()?.profileHash ?? '')
    : '';
  if (existingHash && existingHash === profile.profileHash) {
    res.status(200).json({ ok: true, skipped: true });
    return;
  }

  await profileRef.set(
    {
      ...profile,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const catalog = await loadCatalogDocs();
  const catalogFingerprint = catalogExplorationFingerprint(catalog.series);
  const items = computeRecommendations({
    profile,
    series: catalog.series,
    ips: catalog.ips,
  });

  await firestore().collection('recommendations').doc(installId).set({
    items,
    profileHash: profile.profileHash,
    catalogFingerprint,
    computedAt: FieldValue.serverTimestamp(),
  });

  res.status(200).json({ ok: true });
}

export async function handleRecommendationForYouRequest(
  req: Request,
  res: Response,
): Promise<void> {
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }

  const installId = String(req.query.installId ?? '').trim();
  if (!installId) {
    res.status(400).json({ error: 'invalid_install_id' });
    return;
  }

  const profileSnap = await firestore()
    .collection('recommendation_profiles')
    .doc(installId)
    .get();
  if (!profileSnap.exists) {
    res.status(200).json({ items: [], profileHash: '' });
    return;
  }

  const profile = profileSnap.data() as RecommendationProfile;
  const catalog = await loadCatalogDocs();
  const catalogFingerprint = catalogExplorationFingerprint(catalog.series);
  const cacheSnap = await firestore().collection('recommendations').doc(installId).get();
  const cache = cacheSnap.data();
  if (
    cache &&
    cache.profileHash === profile.profileHash &&
    cache.catalogFingerprint === catalogFingerprint &&
    Array.isArray(cache.items) &&
    cache.items.length <= MAX_RECOMMENDATIONS
  ) {
    res.status(200).json({
      items: cache.items,
      profileHash: profile.profileHash,
    });
    return;
  }

  const items = computeRecommendations({
    profile,
    series: catalog.series,
    ips: catalog.ips,
  });

  await firestore().collection('recommendations').doc(installId).set({
    items,
    profileHash: profile.profileHash,
    catalogFingerprint,
    computedAt: FieldValue.serverTimestamp(),
  });

  res.status(200).json({ items, profileHash: profile.profileHash });
}

async function validateSeriesIds(seriesIds: string[]): Promise<boolean> {
  const unique = [...new Set(seriesIds.filter((id) => id.trim().length > 0))];
  if (unique.length === 0) return true;

  const refs = unique.map((id) => firestore().collection('series').doc(id));
  const snaps = await firestore().getAll(...refs);
  return snaps.every((snap) => snap.exists);
}

async function loadCatalogDocs(): Promise<{
  series: CatalogSeriesDoc[];
  ips: CatalogIpDoc[];
}> {
  const [seriesSnap, ipsSnap] = await Promise.all([
    firestore().collection('series').get(),
    firestore().collection('ips').get(),
  ]);

  const series: CatalogSeriesDoc[] = seriesSnap.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      ipId: String(data.ipId ?? ''),
      displayName: String(data.displayName ?? doc.id),
      releaseDate: (data.releaseDate as string | null | undefined) ?? null,
    };
  });

  const ips: CatalogIpDoc[] = ipsSnap.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      displayName: String(data.displayName ?? doc.id),
    };
  });

  return { series, ips };
}

function normalizeIdList(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  return [...new Set(raw.map((entry) => String(entry).trim()).filter(Boolean))].sort();
}
