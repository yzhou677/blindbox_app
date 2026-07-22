export type SubjectLocatorRequestV1 = {
  version: 1;
  image: { dataBase64: string; mimeType: 'image/jpeg' | 'image/png' | 'image/webp' };
  requestId?: string;
};

export type SubjectLocatorSuggestionResponseV1 = {
  version: 1;
  status: 'suggestion';
  rect: { left: number; top: number; width: number; height: number };
  coordinateSpace: 'normalized_oriented_image';
  orientedWidth: number;
  orientedHeight: number;
  locatorVersion: string;
  selectorVersion: string;
};

export type SubjectLocatorNoSuggestionResponseV1 = Omit<SubjectLocatorSuggestionResponseV1, 'status' | 'rect' | 'coordinateSpace'> & {
  status: 'no_suggestion';
};

export type SubjectLocatorResponseV1 = SubjectLocatorSuggestionResponseV1 | SubjectLocatorNoSuggestionResponseV1;

export class SubjectLocatorRequestError extends Error {
  constructor(readonly reason: 'invalid_request' | 'unsupported_mime_type' | 'payload_too_large' | 'invalid_image' | 'image_dimensions_unsupported') {
    super(reason);
    this.name = 'SubjectLocatorRequestError';
  }
}

export class SubjectLocatorTimeoutError extends Error {
  constructor() { super('locator_timeout'); this.name = 'SubjectLocatorTimeoutError'; }
}
