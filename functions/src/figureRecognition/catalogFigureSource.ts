import { FieldPath, Firestore, QueryDocumentSnapshot, Timestamp } from '@google-cloud/firestore';
import { parseAlternativeImages } from './catalogAlternativeImages';
import type { CatalogFigure, CatalogFigureSource } from './catalogEmbeddingTypes';

export class FirestoreCatalogFigureSource implements CatalogFigureSource {
  constructor(private readonly firestore: Firestore) {}

  async get(figureId: string): Promise<CatalogFigure | null> {
    const snapshot = await this.firestore.collection('figures').doc(figureId).get();
    return snapshot.exists ? mapFigure(snapshot.id, snapshot.data(), snapshot.updateTime) : null;
  }

  async *pages(pageSize: number): AsyncIterable<CatalogFigure[]> {
    let cursor: QueryDocumentSnapshot | undefined;
    while (true) {
      let query = this.firestore.collection('figures').orderBy(FieldPath.documentId()).limit(pageSize);
      if (cursor) query = query.startAfter(cursor);
      const snapshot = await query.get();
      if (snapshot.empty) return;
      yield snapshot.docs.map((doc) => mapFigure(doc.id, doc.data(), doc.updateTime));
      cursor = snapshot.docs[snapshot.docs.length - 1];
    }
  }
}

function mapFigure(id: string, raw: Record<string, unknown> | undefined, updateTime?: Timestamp): CatalogFigure {
  const data = raw ?? {};
  const stringField = (name: string): string => {
    const value = data[name];
    if (typeof value !== 'string' || !value.trim()) throw new Error(`Figure ${id} has invalid ${name}`);
    return value;
  };
  if (typeof data.isSecret !== 'boolean') throw new Error(`Figure ${id} has invalid isSecret`);
  return {
    figureId: id,
    seriesId: stringField('seriesId'),
    brandId: stringField('brandId'),
    ipId: stringField('ipId'),
    isSecret: data.isSecret,
    imageKey: stringField('imageKey'),
    alternativeImages: parseAlternativeImages(data.alternativeImages),
    catalogModifiedAt: updateTime ?? null,
  };
}
