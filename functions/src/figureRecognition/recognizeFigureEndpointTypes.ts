export type RecognitionSelectionV1 = {
  left: number;
  top: number;
  width: number;
  height: number;
  coordinateSpace: 'normalized_oriented_image';
};

export type RecognizeFigureRequestV1 = {
  version: 1;
  image: { dataBase64: string; mimeType: 'image/jpeg' | 'image/png' | 'image/webp' };
  selection: RecognitionSelectionV1;
  continueBorderline?: boolean;
  requestId?: string;
};

export type RecognitionCandidateV1 = {
  rank: number;
  figureId: string;
  figureName: string;
  seriesId: string;
  seriesName: string;
  ipId: string;
  ipName: string;
  imageKey: string;
};

type QualityFields = { subjectQuality: 'good' | 'borderline'; blurEvaluatorVersion: string };
export type RecognizeFigureResponseV1 =
  | ({ version: 1; status: 'borderline' } & QualityFields)
  | { version: 1; status: 'too_blurry'; blurEvaluatorVersion: string }
  | ({ version: 1; status: 'candidates'; decision: 'needs_review'; candidates: RecognitionCandidateV1[]; policyVersion: string } & QualityFields)
  | ({ version: 1; status: 'no_confident_match'; policyVersion: string } & QualityFields);

export class RecognizeFigureRequestError extends Error {
  constructor(readonly reason: 'invalid_request' | 'unsupported_mime_type' | 'payload_too_large' | 'invalid_image' | 'image_dimensions_unsupported' | 'invalid_selection') {
    super(reason); this.name = 'RecognizeFigureRequestError';
  }
}

export class RecognitionQualityUnavailableError extends Error {
  constructor() { super('quality_unavailable'); this.name = 'RecognitionQualityUnavailableError'; }
}

export class RecognitionHydrationError extends Error {
  constructor() { super('candidate_hydration_failed'); this.name = 'RecognitionHydrationError'; }
}

