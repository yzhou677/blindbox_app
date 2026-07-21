import type { LocatorCandidate, LocatorResponse } from './primarySubjectTypes';

export class InvalidLocatorOutputError extends Error {
  constructor() { super('Primary subject locator returned invalid structured output'); this.name = 'InvalidLocatorOutputError'; }
}
export class InvalidRefinementOutputError extends Error {
  constructor() { super('Primary subject refiner returned invalid structured output'); this.name = 'InvalidRefinementOutputError'; }
}

export function validateLocatorResponse(value: unknown): LocatorResponse {
  if (!isRecord(value) || Object.keys(value).some((key) => key !== 'candidates') || !Array.isArray(value.candidates) || value.candidates.length > 3) fail();
  const candidates = value.candidates.map(validateCandidate);
  return { candidates };
}

export function validateRefinementResponse(value: unknown): { box: LocatorCandidate['box'] } {
  try {
    if (!isRecord(value) || Object.keys(value).some((key) => key !== 'bbox')) fail();
    return { box: validateCandidate(value).box };
  } catch {
    throw new InvalidRefinementOutputError();
  }
}

function validateCandidate(value: unknown): LocatorCandidate {
  if (!isRecord(value) || Object.keys(value).some((key) => key !== 'bbox') || !Array.isArray(value.bbox) || value.bbox.length !== 4) fail();
  const raw = value.bbox as unknown[];
  if (!raw.every((coordinate) => typeof coordinate === 'number' && Number.isFinite(coordinate))) fail();
  const [ymin, xmin, ymax, xmax] = (raw as number[]).map(clampBoundary);
  if (ymin >= ymax || xmin >= xmax) fail();
  return { box: { ymin, xmin, ymax, xmax } };
}

function clampBoundary(value: number): number {
  if (value < -1 || value > 1001) fail();
  return Math.max(0, Math.min(1000, value));
}
function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === 'object' && value !== null; }
function fail(): never { throw new InvalidLocatorOutputError(); }
