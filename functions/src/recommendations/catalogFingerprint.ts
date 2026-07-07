import { createHash } from 'crypto';

/** Content fingerprint for exploration-slot rotation (series membership). */
export function catalogExplorationFingerprint(series: { id: string }[]): string {
  const ids = series.map((entry) => entry.id).sort();
  return createHash('sha256').update(ids.join(',')).digest('hex');
}
