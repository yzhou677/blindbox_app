# Figure Recognition PR5: Retrieval Evidence and Shadow Decisions

PR5 introduces an evaluation-only decision boundary after ordered Catalog
retrieval. It follows
[`PDR-001: Figure Recognition Principles`](decisions/product/PDR-001-figure-recognition-principles.md):
automatic results remain suggestions, uncertainty is handled gracefully, and
the already-selected subject is never changed by identity evaluation.

## Pipeline and responsibilities

```text
already-selected subject
-> existing embedding and ordered Top-K retrieval
-> pure retrieval evidence summary
-> shadow decision policy
-> existing Top-K output plus developer diagnostics
```

Retrieval continues to own candidate generation, validation, active-space
filtering, distance ordering, stable tie-breaking, ranking, and Top-K bounds.
It does not interpret confidence.

`RetrievalEvidenceSummarizer` performs side-effect-free mathematical and
taxonomy derivation. It contains no thresholds, outcomes, model names, storage
logic, or product policy. `ShadowRetrievalDecisionResolver` interprets that
evidence conservatively. The CLI only formats the result after printing the
unchanged raw candidates.

The decision layer receives no image, mask, vector, dimension, model name,
database object, or subject-isolation detail. It receives ordered candidates,
requested Top-K, `lower_is_better` distance semantics, and an opaque calibration
profile.

## Evidence definitions

- `returnedCandidateRatio`: returned candidate count divided by requested Top-K.
- `top1Top2Gap`: Top-2 distance minus Top-1 distance.
- `relativeTop1Top2Gap`: absolute gap divided by Top-1 distance; omitted when
  Top-1 is zero or Top-2 is absent.
- `distanceSpread`: last distance minus Top-1 distance.
- `leadingTieCount`: consecutive leading candidates equal to Top-1 within the
  centralized floating-point equality tolerance.
- `nearDuplicateDistanceCount`: adjacent ordered pairs within the centralized
  numerical near-duplicate tolerance.
- Distinct taxonomy counts ignore missing values.
- `topSeries`, `topIp`, and `topBrand` counts describe the most represented
  non-empty value anywhere in Top-K. Ratios use total candidate count as the
  denominator, so missing taxonomy cannot inflate concentration.
- `top1Series`, `top1Ip`, and `top1Brand` counts describe how many candidates
  share Top-1's corresponding taxonomy value.
- `sameSeriesLeadingAmbiguity` is true when Top-1 and Top-2 are different
  Figures from the same non-empty Series.

The equality tolerances are numerical summarization safeguards, not recognition
thresholds. Summarization never changes candidate order.

## Shadow policy

Policy version: `retrieval-policy-shadow-v1`

Current calibration profile: `figure-image-retrieval-v1`

Rules are evaluated in order:

1. Empty candidates -> `no_confident_match` / `no_candidates`.
2. Malformed, non-finite, out-of-order, or contradictory evidence ->
   `no_confident_match` / `invalid_evidence`.
3. Unsupported profile -> `no_confident_match` / `uncalibrated_profile`.
4. All other valid evidence -> `needs_review` /
   `shadow_evaluation_only`.

Leading ties, duplicate leading distances, same-Series Figure ambiguity, and a
sparse result set add bounded diagnostic reasons. They do not filter candidates
or change ranks. Shadow V1 has no path that emits `high_confidence`.

No numeric probability is exposed. Distances and heuristic summaries have not
been calibrated as probabilities, and presenting them as percentages would
overstate certainty.

## Reason codes

The bounded contract includes:

- `no_candidates`
- `invalid_evidence`
- `uncalibrated_profile`
- `shadow_evaluation_only`
- `ambiguous_leading_candidates`
- `duplicate_leading_distances`
- `same_series_figure_ambiguity`
- `sparse_candidate_set`
- reserved evaluation-only signal reasons for later labeled calibration

Reserved signal reasons do not currently affect the outcome.

## CLI evaluation

Both whole-image and isolated-subject retrieval pass through the same decision
composition after Top-K. Existing candidates print first and remain unchanged;
the decision and evidence block follows them.

An optional developer label can be supplied:

```powershell
npm run retrieve:catalog-figures -- `
  --file "C:\path\to\photo.jpg" `
  --top-k 5 `
  --isolate-subject `
  --evaluation-label "expected-figure-id"
```

The resulting in-memory record contains only expected Figure ID, expected rank,
Top-1 correctness, Top-K presence, decision outcome, policy version, and
calibration profile. It is printed only; it is not uploaded or persisted and
does not contain the image path.

## Calibration and rollout

### Candidate policy under shadow evaluation

`retrieval-policy-candidate-v1` is evaluated alongside, and does not replace,
`retrieval-policy-shadow-v1`. It emits `high_confidence` only when Top-1
distance is at most `0.225` and the absolute Top-1/Top-2 gap is at least
`0.025`. Otherwise valid calibrated evidence remains `needs_review`. Empty,
invalid, and uncalibrated inputs retain the existing fail-closed outcomes.

The absolute gap was selected because it produced a compact, directly
explainable rule in the current labeled calibration set without relying on
taxonomy or other metadata. `0.225` was retained instead of broadening the
distance boundary to `0.23`: collector trust favors the more conservative
boundary, and the broader value has not established an equivalent safety case.

On the current calibration set, this candidate produced 17 high-confidence
cases, 100% observed high-confidence precision, zero false accepts, zero
Catalog-absent high-confidence results, and 40.48% high-confidence coverage.
These are calibration-set observations, not production estimates. A separate
holdout evaluation is required before any production acceptance behavior may
be considered. CLI and batch-evaluation output expose both policies solely for
developer comparison; product behavior still follows neither candidate
high-confidence output nor any automatic acceptance path.

Shadow output should be collected manually against a labeled local evaluation
set covering correct Top-1, correct non-leading Top-K, out-of-Catalog subjects,
same-Series variants, secret variants, clutter, different viewpoints, and both
segmentation success and fallback.

Calibration should compare false confident matches, high-confidence precision,
review rate, no-match rate, coverage, and behavior across Series and input
conditions. Collector trust requires prioritizing precision over automatic
coverage.

After sufficient labeled evidence, a separate decision may freeze a calibrated
profile and production thresholds. That later work must preserve the current
decision interface and cannot reinterpret Series agreement as exact Figure
recognition.

## Limitations

- Shadow outcomes are diagnostics, not production confidence claims.
- Taxonomy concentration may reveal ambiguity but does not prove identity.
- A large distance gap can still be misleading when the correct Figure is not
  represented in the Catalog.
- Distance distributions may change when the retrieval evidence profile changes.
- The optional evaluation label trusts the developer's supplied Figure ID and
  performs no Catalog lookup.
- PR5 adds no reranking, filtering, additional model call, persistence,
  analytics, UI, or Collection behavior.
