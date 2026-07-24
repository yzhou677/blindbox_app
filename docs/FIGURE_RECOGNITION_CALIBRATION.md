# Figure Recognition Retrieval Calibration

> **Tooling + history.** Live production thresholds and policy wiring are in
> [`figure-recognition.md`](figure-recognition.md). This document describes the
> calibration analyzer and the historical selection of
> `retrieval-policy-candidate-v1`.

This offline developer tool explores small, explainable retrieval-decision policy families using an existing labeled `evaluation-results.json`. Distance alone is insufficient: a nearby wrong or Catalog-absent result can look deceptively close, so the analyzer also compares separation from competing candidates. It does not run image processing, retrieval, Firebase, or paid APIs, and it does not modify production recognition configuration.

## Run

From `functions/`:

```powershell
npm run calibrate:figure-retrieval -- `
  --input "D:\figure-eval\results\evaluation-results.json" `
  --output-dir "D:\figure-eval\calibration"
```

Existing output files are protected. Pass `--overwrite` only when replacement is intentional.

## Input and exclusions

The input is the JSON result array produced by the batch retrieval evaluation runner. IDs must be unique and safe. Completed rows require finite Top-1 evidence and consistent source policy metadata. Catalog-present rows require `expectedFigureId` and `top1Correct`; Catalog-absent rows must not claim an expected figure.

Failed cases, subject-isolation rejections, and completed rows lacking Top-1 evidence are counted and excluded before policy evaluation. Validation completes before any analysis output is written.

## Policy families

The analyzer evaluates four deterministic families: distance plus relative gap; distance plus absolute gap; distance plus either margin; and a strong-distance shortcut or distance plus relative gap. An optional distance-spread floor is explored as an additional condition. Threshold grids and analyzer metadata are centralized in `retrievalCalibrationConfig.ts`.

A passing rule yields `high_confidence`. Otherwise a Top-1 distance beyond the candidate maximum yields `no_confident_match`; remaining cases yield `needs_review`. Threshold equality is inclusive. Missing Top-2-derived evidence cannot satisfy a gap condition, though the strong-distance branch can still pass independently.

## Outputs

- `calibration-policy-results.json`: every evaluated policy and its aggregate metrics.
- `calibration-policy-results.csv`: compact comparison table.
- `calibration-summary.json`: input/exclusion counts, conservative shortlists, Pareto candidates, safe case IDs for shortlisted policies, and caveats.

The summary also contains `retrievalQuality`: completed-case Top-1/Top-3/Top-5
accuracy, mean reciprocal rank, distance summaries, Catalog-absent retrieval
rate, expected-IP and expected-Series groups, and hard retrieval failures. These
statistics are printed by the CLI but do not alter policy generation or the
existing policy-results CSV.

Expected IP and Series are recovered only from the returned candidate matching
the labeled expected Figure. If that Figure was not retrieved and the result
contains no explicit expected taxonomy, the report uses `unknown` rather than
guessing from an identifier. Average rank uses retrieved correct Figures;
mean reciprocal rank assigns zero to a not-retrieved correct Figure.

Ranking prioritizes fewer false accepts, then fewer Catalog-absent high-confidence outcomes, higher precision, higher coverage, lower complexity, and a stable policy ID. Shortlists include zero-false-accept policies, the highest-coverage zero-false-accept tier, and policies meeting 99% or 95% observed precision. These are comparisons, not an automatic policy recommendation.

## Interpretation and limitations

High-confidence precision measures correct Catalog-present Top-1 accepts divided by all high-confidence outcomes. Coverage is the high-confidence share of eligible cases. A false accept is either an incorrect Catalog-present Top-1 accepted with high confidence or any Catalog-absent case accepted with high confidence.

Calibration-set results are not production probabilities. Dataset composition, Catalog coverage, image conditions, IP/Series balance, and duplicate-like figures can bias results. Select a policy only after reviewing case diagnostics and evaluating it on a separate holdout dataset. Keep the holdout untouched during threshold selection and report its results independently.

## Production candidate policy

Calibration originally selected `retrieval-policy-candidate-v1` with Top-1
distance `<= 0.225` and absolute Top-1/Top-2 gap `>= 0.025`. Absolute gap was
chosen for its simple, inspectable separation requirement.

After collector sample validation, production relaxed only the absolute Top-1
distance gate to `0.240` while keeping the same policy version string,
calibration profile, and `0.025` gap. The shadow resolver remains evaluation-
only; the production callable uses `CandidateRetrievalDecisionResolver`.

Historical calibration-set notes below describe the original `0.225` selection
and are not live production thresholds.
