# Figure Recognition Labeled Evaluation

> **Historical / tooling.** Developer evaluation harness. Production policy and
> UX are documented in [`figure-recognition.md`](figure-recognition.md).

This developer-only tool runs the existing Figure Recognition pipeline over a
local labeled photo set. Its purpose is to collect evidence for later retrieval
policy calibration. It does not choose thresholds, train a model, change
ranking, or make production confidence claims.

## Why labeled evaluation

Raw retrieval distances are not probabilities. Collector photos vary by
lighting, viewpoint, clutter, reflection, isolation outcome, and Catalog
coverage. A trustworthy decision policy therefore needs measurements from real
photos with known expected outcomes, including subjects that are intentionally
absent from the Catalog.

## Manifest

The manifest is strict JSON. Start from
[`tools/figure-retrieval-evaluation-manifest.example.json`](../functions/tools/figure-retrieval-evaluation-manifest.example.json),
which demonstrates the complete supported schema without being loaded
automatically by the runner.

Version must be `1`, `dataset` is required, `photos` must be non-empty, and each
file may be absolute or relative to the manifest. Resolved photo paths must be
unique. A `present` photo requires `expectedFigureId`; an `absent` photo must
omit it. Notes are optional developer-only text and never affect evaluation.

All rows and referenced image types are validated before any paid call. One bad
row rejects the complete run.

## Quick Start

1. Copy:

   ```text
   tools/figure-retrieval-evaluation-manifest.example.json
   ```

   to:

   ```text
   D:\figure-eval\manifest.json
   ```

2. Put evaluation images in:

   ```text
   D:\figure-eval\photos\
   ```

3. Fill in `expectedFigureId` for every Catalog-present photo.

4. Mark Catalog-absent photos with:

   ```json
   "catalogPresence": "absent"
   ```

5. From the `functions` directory, run:

   ```powershell
   npm run evaluate:figure-retrieval -- `
     --manifest "D:\figure-eval\manifest.json" `
     --output-dir "D:\figure-eval\results"
   ```

## Running

This command makes real paid localization, refinement, segmentation, embedding,
and retrieval calls for each usable case:

```powershell
cd D:\blindbox_app\functions

npm run evaluate:figure-retrieval -- `
  --manifest "D:\figure-eval\manifest.json" `
  --output-dir "D:\figure-eval\results"
```

Options:

```text
--top-k <1-20>       default 5
--overwrite          replace existing evaluation reports
--continue-on-error  continue after a sanitized per-case failure; this is the default
```

Processing is sequential and preserves photo order. Runtime is approximately
the sum of the existing per-photo pipeline latencies, so a set of dozens of
photos may take several minutes. Actual time and cost depend on service latency,
image processing, and how many images pass isolation.

## Optional preview artifacts

Preview generation is disabled by default. Developers can pass
`--preview-dir` to create one directory per safe internal case ID, such as
`photo-0007`. Available coarse/refined overlays and crops, segmentation
artifacts, exact embedding input, and sanitized diagnostics are saved there.
Isolation-rejected cases retain artifacts produced before rejection.

Existing preview case directories are protected unless
`--overwrite-preview` is explicitly supplied. Evaluation reports continue to
use their separate existing `--overwrite` behavior.

Use repeated `--case-id photo-0007` arguments or a comma-separated
`--case-ids photo-0007,photo-0008` value to rerun selected cases. Requested IDs
are validated before evaluation, manifest order is retained, and the summary
reports the number skipped by the filter.

For filtered developer runs, `--debug-top-candidates` prints raw candidate
identity fields and distances without changing evaluation reports or decisions.
It retrieves and displays up to 10 candidates by default; use
`--debug-top-k 10` to set an explicit bound. Debug output is console-only and
never includes embeddings or vectors.

## Processing behavior

Each photo reuses the same local reader, subject-isolation pipeline, embedding
provider, vector retrieval, and shadow decision resolver as single-image
evaluation. The runner does not duplicate those algorithms.

A non-usable isolation result is recorded as `isolation_rejected`; retrieval is
skipped and the next photo continues. Provider and retrieval failures become
sanitized `failed` rows with bounded component/error codes.

Catalog-present photos measure where the expected Figure appears. Catalog-absent
photos intentionally have no correctness flags; they measure evidence and future
rejection behavior without pretending a returned candidate is correct.

## Output files

The output directory contains:

- `evaluation-results.json`: safe structured per-case results and returned
  candidate metadata.
- `evaluation-results.csv`: the same photos in flat, escaped spreadsheet form.
- `evaluation-summary.json`: aggregate metrics and evidence distributions.

Reports are refreshed after every completed photo, limiting lost work if a long
run is interrupted. V1 does not resume from partial output: rerun with
`--overwrite`, which processes every case again. Resume without caching images,
embeddings, masks, or model responses is a follow-up.

Without `--overwrite`, any existing report causes a safe startup failure before
paid calls.

## Metric definitions

Catalog-present retrieval metrics use only completed, correctly labeled
Catalog-present photos:

- Top-1/Top-3/Top-5 accuracy: fraction whose expected Figure is within that rank.
- Mean reciprocal rank: mean of `1 / expectedRank`, using zero when absent from
  the requested Top-K.
- Expected-present rate: fraction whose expected Figure appears anywhere in
  requested Top-K.

Decision counts cover completed photos. Catalog-absent decision counts are also
reported separately to support later false-confident-match analysis.

Pipeline metrics count segmentation, segmentation fallback, accepted
refinement, isolation rejection, and elapsed time. P50/P95 and evidence
percentiles use deterministic linear interpolation between adjacent sorted
values.

Evidence distributions are separated into Catalog-present and Catalog-absent
groups. Each field reports count, minimum, maximum, mean, median, P10, P25, P75,
P90, and P95. Empty groups report `count: 0` without invented values.

## Spreadsheet inspection

Open `evaluation-results.csv`, group rows by `catalogPresence`, and compare
correct versus incorrect retrieval rows using Top-1 distance, Top-1/Top-2 gap,
relative gap, spread, taxonomy ratios, isolation outcome, and shadow reasons.
Keep Catalog-absent rows separate when measuring rejection risk.

The tool deliberately does not recommend a cutoff. A later calibration review
must examine false matches, review rate, coverage, Series-specific behavior,
and the cost of collector-facing errors before freezing `retrieval-policy-v1`.

## Privacy and safety

Reports and progress output never contain full source paths, images, masks,
vectors, polygons, credentials, tokens, stack traces, or model prose. Source
photos stay in their original local locations and are never copied into the
output directory. No report is uploaded or written to Firestore.

The reports contain generated row identifiers, optional expected Figure IDs,
returned Catalog IDs and distances, safe pipeline outcomes, policy metadata,
and timing.
