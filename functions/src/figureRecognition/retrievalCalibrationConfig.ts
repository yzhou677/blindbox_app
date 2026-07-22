function range(start: number, end: number, step: number): readonly number[] {
  const scale = 10000; const values: number[] = [];
  for (let value = Math.round(start * scale); value <= Math.round(end * scale); value += Math.round(step * scale)) values.push(value / scale);
  return Object.freeze(values);
}

export const RETRIEVAL_CALIBRATION_CONFIG = Object.freeze({
  analyzerVersion: 'figure-retrieval-calibration-v1',
  grid: Object.freeze({
    maximumTop1Distance: range(0.15, 0.24, 0.005),
    minimumAbsoluteGap: range(0.005, 0.06, 0.0025),
    minimumRelativeGap: range(0.02, 0.35, 0.01),
    strongDistance: range(0.10, 0.18, 0.01),
    minimumDistanceSpread: Object.freeze([undefined, 0.05] as Array<number | undefined>),
  }),
  shortlistLimit: 20,
  caveats: Object.freeze([
    'Metrics are calibration-set metrics, not unbiased production estimates.',
    'A separate holdout dataset is required before trusting a policy broadly.',
    'The dataset may overrepresent particular IPs, Series, photo conditions, or Catalog coverage.',
    'No statistical certainty or probability calibration is claimed.',
  ]),
});

export type RetrievalCalibrationConfig = typeof RETRIEVAL_CALIBRATION_CONFIG;
