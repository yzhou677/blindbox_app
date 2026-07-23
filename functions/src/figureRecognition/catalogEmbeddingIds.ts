/**
 * Document ID scheme for `catalogFigureEmbeddings`:
 *
 * - Primary: `{figureId}` (unchanged — preserves existing production docs)
 * - Alternative: `{figureId}__alt__{imageKey}`
 *
 * `imageKey` is included so two alternatives with similar variants cannot collide.
 * Do not derive alternative IDs from `variant` alone.
 */

export const ALTERNATIVE_DOC_ID_SEPARATOR = '__alt__';

export type EmbeddingImageRole = 'primary' | 'alternative';

export function primaryEmbeddingDocumentId(figureId: string): string {
  const id = figureId.trim();
  if (!id) throw new Error('figureId is required for primary embedding document id');
  return id;
}

export function alternativeEmbeddingDocumentId(figureId: string, imageKey: string): string {
  const id = figureId.trim();
  const key = imageKey.trim();
  if (!id) throw new Error('figureId is required for alternative embedding document id');
  if (!key) throw new Error('imageKey is required for alternative embedding document id');
  if (key.includes(ALTERNATIVE_DOC_ID_SEPARATOR)) {
    throw new Error(`alternative imageKey must not contain ${ALTERNATIVE_DOC_ID_SEPARATOR}`);
  }
  return `${id}${ALTERNATIVE_DOC_ID_SEPARATOR}${key}`;
}

export function embeddingDocumentId(input: {
  figureId: string;
  imageRole: EmbeddingImageRole;
  imageKey: string;
}): string {
  return input.imageRole === 'primary'
    ? primaryEmbeddingDocumentId(input.figureId)
    : alternativeEmbeddingDocumentId(input.figureId, input.imageKey);
}

export function isAlternativeEmbeddingDocumentId(documentId: string): boolean {
  return documentId.includes(ALTERNATIVE_DOC_ID_SEPARATOR);
}
