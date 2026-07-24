import type { Firestore } from '@google-cloud/firestore';
import type { FigureRetrievalCandidate } from './figureRetrievalTypes';
import { RecognitionHydrationError, type RecognitionCandidateV1 } from './recognizeFigureEndpointTypes';

export interface RecognitionCandidateHydrator { hydrate(candidates: readonly FigureRetrievalCandidate[]): Promise<RecognitionCandidateV1[]>; }

export class FirestoreRecognitionCandidateHydrator implements RecognitionCandidateHydrator {
  constructor(private readonly firestore: Firestore) {}
  async hydrate(candidates: readonly FigureRetrievalCandidate[]): Promise<RecognitionCandidateV1[]> {
    try {
      const limited = [...candidates];
      const refsByPath = new Map<string, ReturnType<Firestore['doc']>>();
      for (const candidate of limited) {
        for (const ref of [
          this.firestore.collection('figures').doc(candidate.figureId),
          this.firestore.collection('series').doc(candidate.seriesId),
          this.firestore.collection('ips').doc(candidate.ipId),
        ]) refsByPath.set(ref.path, ref);
      }
      const refs = [...refsByPath.values()];
      const snapshots = await this.firestore.getAll(...refs);
      const dataByPath = new Map(snapshots.map((snapshot, index) => [refs[index].path, snapshot.data()]));
      return limited.map((candidate) => {
        const figure = dataByPath.get(`figures/${candidate.figureId}`), series = dataByPath.get(`series/${candidate.seriesId}`), ip = dataByPath.get(`ips/${candidate.ipId}`);
        const figureName = text(figure?.displayName ?? figure?.name), seriesName = text(series?.displayName ?? series?.name), ipName = text(ip?.displayName ?? ip?.name), imageKey = text(figure?.imageKey);
        if (!figureName || !seriesName || !ipName || !imageKey) throw new RecognitionHydrationError();
        return { rank: candidate.rank, figureId: candidate.figureId, figureName, seriesId: candidate.seriesId, seriesName, ipId: candidate.ipId, ipName, imageKey };
      });
    } catch (error) { if (error instanceof RecognitionHydrationError) throw error; throw new RecognitionHydrationError(); }
  }
}
function text(value: unknown): string { return typeof value === 'string' ? value.trim() : ''; }
