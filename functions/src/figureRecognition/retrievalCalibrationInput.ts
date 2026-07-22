import { promises as fs } from 'node:fs';
import type { CalibrationInputSample, CalibrationInputSummary } from './retrievalCalibrationTypes';

type InputFileSystem = Pick<typeof fs, 'readFile'>;

export class RetrievalCalibrationInputLoader {
  constructor(private readonly fileSystem: InputFileSystem = fs) {}

  async load(inputPath: string): Promise<{ samples: CalibrationInputSample[]; summary: CalibrationInputSummary }> {
    let parsed: unknown;
    try { parsed = JSON.parse(await this.fileSystem.readFile(inputPath, 'utf8')); } catch { throw new Error('Calibration input is not valid evaluation-results JSON'); }
    return validateCalibrationInput(parsed);
  }
}

export function validateCalibrationInput(value: unknown): { samples: CalibrationInputSample[]; summary: CalibrationInputSummary } {
  if (!Array.isArray(value)) throw new Error('Calibration input must be an array');
  const ids = new Set<string>(); const samples: CalibrationInputSample[] = [];
  let failed = 0; let rejected = 0; let incomplete = 0; let present = 0; let absent = 0;
  for (const row of value) {
    if (!record(row) || !safeId(row.id)) throw new Error('Evaluation result has invalid ID');
    if (ids.has(row.id)) throw new Error('Duplicate evaluation result ID');
    ids.add(row.id);
    if (row.catalogPresence !== 'present' && row.catalogPresence !== 'absent') throw new Error(`Evaluation result ${row.id} has invalid catalogPresence`);
    if (row.catalogPresence === 'present') {
      if (!safeId(row.expectedFigureId)) throw new Error(`Catalog-present result ${row.id} requires expectedFigureId`);
      present++;
    } else {
      if (Object.hasOwn(row, 'expectedFigureId') && row.expectedFigureId !== undefined) throw new Error(`Catalog-absent result ${row.id} must not claim expectedFigureId`);
      absent++;
    }
    if (row.status === 'failed') { failed++; continue; }
    if (row.status === 'isolation_rejected') { rejected++; continue; }
    if (row.status !== 'completed') throw new Error(`Evaluation result ${row.id} has invalid status`);
    if (row.top1Distance === undefined) { incomplete++; continue; }
    if (!finite(row.top1Distance) || !optionalFinite(row.top2Distance) || !optionalFinite(row.top1Top2Gap) || !optionalFinite(row.relativeTop1Top2Gap) || !optionalFinite(row.distanceSpread)) throw new Error(`Evaluation result ${row.id} has non-finite evidence`);
    if (typeof row.policyVersion !== 'string' || !row.policyVersion || typeof row.calibrationProfile !== 'string' || !row.calibrationProfile) throw new Error(`Evaluation result ${row.id} lacks source policy metadata`);
    if (row.catalogPresence === 'present' && typeof row.top1Correct !== 'boolean') throw new Error(`Catalog-present result ${row.id} requires top1Correct`);
    const returnedCandidates = Array.isArray(row.returnedCandidates) ? row.returnedCandidates.filter(record) : [];
    const expectedCandidate = row.catalogPresence === 'present' ? returnedCandidates.find((candidate) => candidate.figureId === row.expectedFigureId) : undefined;
    const expectedRank = positiveInteger(row.expectedRank) ? row.expectedRank : positiveInteger(expectedCandidate?.rank) ? expectedCandidate.rank : undefined;
    samples.push({
      id: row.id, catalogPresence: row.catalogPresence, expectedFigureId: row.expectedFigureId as string | undefined,
      top1FigureId: safeId(row.top1FigureId) ? row.top1FigureId : undefined,
      top1SeriesId: safeId(row.top1SeriesId) ? row.top1SeriesId : safeId(returnedCandidates[0]?.seriesId) ? returnedCandidates[0].seriesId : undefined,
      top1IpId: safeId(returnedCandidates[0]?.ipId) ? returnedCandidates[0].ipId : undefined,
      top1Correct: row.top1Correct as boolean | undefined, expectedRank,
      expectedSeriesId: safeId(row.expectedSeriesId) ? row.expectedSeriesId : safeId(expectedCandidate?.seriesId) ? expectedCandidate.seriesId : undefined,
      expectedIpId: safeId(expectedCandidate?.ipId) ? expectedCandidate.ipId : undefined,
      top1Distance: row.top1Distance, top2Distance: row.top2Distance as number | undefined, top1Top2Gap: row.top1Top2Gap as number | undefined,
      relativeTop1Top2Gap: row.relativeTop1Top2Gap as number | undefined, distanceSpread: row.distanceSpread as number | undefined,
      policyVersion: row.policyVersion, calibrationProfile: row.calibrationProfile,
    });
  }
  const policies = new Set(samples.map((sample) => sample.policyVersion)); const profiles = new Set(samples.map((sample) => sample.calibrationProfile));
  if (policies.size > 1 || profiles.size > 1) throw new Error('Completed evaluation results contain mixed source policy metadata');
  return { samples, summary: {
    totalRows: value.length, evaluatedRows: samples.length, excludedRows: failed + rejected + incomplete,
    excludedFailed: failed, excludedIsolationRejected: rejected, excludedIncompleteEvidence: incomplete,
    catalogPresentRows: present, catalogAbsentRows: absent,
    sourcePolicyVersion: samples[0]?.policyVersion ?? 'unknown', sourceCalibrationProfile: samples[0]?.calibrationProfile ?? 'unknown',
  } };
}

function record(value: unknown): value is Record<string, unknown> { return typeof value === 'object' && value !== null && !Array.isArray(value); }
function safeId(value: unknown): value is string { return typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(value); }
function finite(value: unknown): value is number { return typeof value === 'number' && Number.isFinite(value); }
function optionalFinite(value: unknown): boolean { return value === undefined || finite(value); }
function positiveInteger(value: unknown): value is number { return typeof value === 'number' && Number.isInteger(value) && value > 0; }
