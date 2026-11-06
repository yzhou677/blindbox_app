---
name: recognition-eval
description: >-
  Runs the labeled figure-retrieval evaluation and reads its metrics. Use
  when the user asks to evaluate recognition, measure Top-K accuracy, or
  record a retrieval eval.
---

# Recognition eval

This measures the existing pipeline. It does not pick thresholds or train a model. Full notes: [docs/FIGURE_RECOGNITION_EVALUATION.md](../../../docs/FIGURE_RECOGNITION_EVALUATION.md). Product rules stay in [docs/figure-recognition.md](../../../docs/figure-recognition.md) and [docs/decisions/product/PDR-001-figure-recognition-principles.md](../../../docs/decisions/product/PDR-001-figure-recognition-principles.md).

The run makes paid localization, embedding, and retrieval calls.

## Steps

1. Copy [functions/tools/figure-retrieval-evaluation-manifest.example.json](../../../functions/tools/figure-retrieval-evaluation-manifest.example.json) to a manifest outside the repo.
2. Manifest `version` is `1`. `dataset` is required. `photos` is non-empty. Paths are unique. A `present` photo needs `expectedFigureId`. An `absent` photo must omit it.
3. One bad row rejects the whole run before any paid call.
4. From `functions/`:

```text
npm run evaluate:figure-retrieval -- --manifest "<manifest.json>" --output-dir "<results-dir>"
```

Script: `functions/package.json` → `tools/evaluate-figure-retrieval.mjs`.

5. Optional flags are defined in [functions/src/figureRecognition/figureRetrievalEvaluationCli.ts](../../../functions/src/figureRecognition/figureRetrievalEvaluationCli.ts). Defaults come from that file. Do not assume a default that is not written there.

## What to read

Output directory:

- `evaluation-summary.json` — aggregate metrics
- `evaluation-results.csv` — one row per photo
- `evaluation-results.json` — same rows, structured

On Catalog-present completed photos: Top-1, Top-3, Top-5 accuracy, mean reciprocal rank, expected-present rate.

Also read decision counts, isolation rejection, and the present vs absent evidence distributions. Do not treat a candidate for an absent photo as correct.

Open the CSV, group by `catalogPresence`, and compare correct vs incorrect rows using Top-1 distance, Top-1/Top-2 gap, relative gap, spread, taxonomy ratios, isolation outcome, and shadow reasons.

The tool does not recommend a cutoff. There is no eval-history folder in this repo. Keep the output directory you passed.
