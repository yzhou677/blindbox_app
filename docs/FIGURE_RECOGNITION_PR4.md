# Figure Recognition PR4: Primary Subject Isolation

PR4 adds an optional primary-subject isolation stage to the local developer
retrieval CLI. It does not change production routes or the default PR3
whole-image behavior.

## Pipeline and boundaries

```text
Local image
-> GooglePrimarySubjectLocator (semantic localization only)
-> PrimarySubjectOutputValidator (strict structured contract)
-> PrimarySubjectCandidateSelector (deterministic local primary selection)
-> coarse selected crop
-> GooglePrimarySubjectRefiner (one bounded semantic tightening pass)
-> PrimarySubjectRefinementService (mapping, guards, coarse fallback)
-> PrimarySubjectCropper (final geometry and crop)
-> PrimarySubjectIsolationService (local technical quality gate)
-> GeminiSubjectSegmenter (same-subject polygon only)
-> deterministic local mask processing and transparent crop
-> existing ImageEmbeddingProvider
-> existing COSINE Firestore vector retrieval
```

`PrimarySubjectLocator` is replaceable and does not know the Catalog. Gemini
proposes up to three single-collectible boxes and never chooses a primary. The
validator independently rejects malformed boxes, and the local selector scores
the valid candidates. The cropper owns pixels but not semantic proposals. The
isolation service is the only component that decides whether retrieval may run.

`SubjectSegmenter` is the replaceable foreground-isolation boundary. The current
implementation is `GeminiSubjectSegmenter`; Gemini schema and transport types do
not leak to callers. `SubjectSegmentationStage` owns fallback and exposes only
the final `embeddingInput`, so retrieval is segmentation-provider agnostic.

ADR-003 already establishes that future cropping stages feed the unchanged
Catalog retrieval pipeline, so PR4 does not add another durable architecture
decision.

## Locator configuration and prompt

All locator and technical-gate defaults are centralized in
`primarySubjectConfig.ts`. The current locator is `gemini-3.5-flash` in Vertex
AI location `us`, with temperature `0`, high media resolution, and prompt
version `primary-subject-v3`. Authentication uses Application Default
Credentials; no API key is supported.

Gemini 3.5 Flash is the current stable GA Flash-class multimodal model selected
for image localization, structured JSON output, Vertex AI ADC support, and a
longer lifecycle than the superseded audit assumption. Replacing the locator
model requires one configuration change.

Prompt v3 asks Gemini only to propose zero through three tight boxes, with each
box representing exactly one physical collectible. It must not rank candidates
or select a primary. It excludes reflections, beverage cans, props, shelves,
decorations, unrelated plush, hands, keyboards, tables, packaging artwork,
printed characters, and photographs. The schema contains only `candidates` and
one normalized `bbox` per candidate; it contains no role, status, reason,
identity, or confidence field.

The local selector scores every validated candidate using centralized weights:
center proximity 0.40, composite crop sharpness 0.25, subject area 0.20, and
subject-to-padded-crop occupancy 0.15. Stable input order breaks exact ties.
Diagnostics expose every component score, total score, and selected flag.

The selected coarse crop is sent once to the same centrally configured Gemini
model using refinement prompt `primary-subject-refinement-v1`. The full source
image is not sent again. Refinement returns exactly one normalized `bbox` for
the same collectible and cannot select another candidate. The box is mapped
from coarse-crop coordinates back into the oriented source coordinate system.

Refinement is accepted only when it remains inside the coarse crop, reduces
unpadded area by 5–65%, and passes the existing source-size, subject-area, and
composite blur gates. Accepted boxes receive 6% final padding clamped inside
the coarse crop. Malformed output, exhausted transient retries, guard failures,
or quality failures use the already accepted coarse crop. Refinement is never
recursive and fallback never uses the full source image.

## Gemini subject segmentation

The accepted refined crop, or accepted coarse fallback, is the only segmentation
input. This stage never sends the full original photo. It uses the centrally
configured `gemini-3.5-flash` model in Vertex AI location `us`, temperature `0`,
high media resolution, ADC, and prompt version
`primary-subject-segmentation-v1`.

The provider-private structured response is
`{ polygons: [{ points: [[x, y], ...] }] }`, with at most one polygon and
coordinates normalized from 0 through 1000 in the crop. The prompt requires the
same already-selected physical collectible, preserves attached identifying
parts, excludes nearby clutter, and forbids identity, classification, reasoning,
and prose.

Local validation rejects unknown fields, empty or multiple polygons, malformed
or non-finite coordinates, excessive points, fewer than three distinct points,
zero area, self-intersection, material boundary overflow, empty masks,
implausible foreground area, and masks that miss the selected crop's central
anchor. Model-provided bounds are not trusted.

A pure TypeScript scanline rasterizer creates a binary mask. Deterministic
post-processing keeps the anchor component, removes distant tiny components,
retains sufficiently close attached components, fills only small holes, and
uses a one-pixel closing operation. It recomputes tight bounds and applies 4%
safety padding. All parameters are centralized in `primarySubjectConfig.ts`.
The final image is an undistorted transparent PNG with original color and alpha.

Provider, schema, polygon, or safety failures return `unavailable`; the stage
then passes the accepted refined/coarse crop unchanged. It never falls back to
the original image. Only 429, timeout, and 5xx transport failures retry, with a
maximum of three attempts. Invalid model output is never retried.

## Crop and quality rules

Coordinates are normalized as `ymin, xmin, ymax, xmax` from 0 through 1000.
Small overflow of at most one normalized unit is clamped; other invalid,
reversed, degenerate, non-finite, or contradictory output fails closed.

The cropper applies EXIF orientation first, uses floor for minimum pixel edges
and ceil for maximum edges, adds 12% proportional padding, and clamps to source
bounds. It preserves the padded crop's aspect ratio, never forces a square,
never stretches, and never upscales. Oversized crops are downscaled with
Lanczos resampling. Alpha-bearing inputs remain PNG; other crops use one
high-quality JPEG encoding.

Current evaluation defaults (not permanent product semantics) are:

- minimum crop: 160 x 160 source pixels
- minimum unpadded subject area ratio: 0.02
- minimum crop-local Sharp `stats().sharpness`: 1.5
- minimum mean absolute grayscale gradient: 1.0
- padding ratio: 0.12
- maximum processed dimension: 4096

Final statuses are `usable`, `no_subject`, `too_blurry`, and
`subject_too_small`. Only `usable` continues. Multiple proposals are locally
scored into one primary; the pipeline never embeds more than one candidate and
never falls back to the whole image.

Blur is a deterministic composite check. Sharp `stats().sharpness` remains one
signal, while mean absolute horizontal/vertical grayscale gradient supplies a
second local-detail signal for smooth collectibles with crisp boundaries. A
crop is rejected as `too_blurry` only when both signals are below their
configured thresholds. Diagnostics report both raw metrics, thresholds,
per-signal failures, and the combined decision.

## CLI usage

Whole-image baseline (unchanged):

```powershell
npm run retrieve:catalog-figures -- `
  --file "C:\path\to\tinytiny-shelf-photo.jpg" `
  --top-k 5
```

Subject isolation:

```powershell
npm run retrieve:catalog-figures -- `
  --file "C:\path\to\tinytiny-shelf-photo.jpg" `
  --top-k 5 `
  --isolate-subject `
  --preview-dir "C:\path\to\tinytiny-preview"
```

Preview files are created only when `--preview-dir` is supplied. In addition to
the coarse/refined artifacts, segmentation creates `segmentation-mask.png`,
`segmented-overlay.jpg`, `segmented-subject.png`, `embedding-input.png`, and
`segmentation.json`. The embedding-input bytes exactly match the bytes sent to
embedding. Fallback previews use the correct MIME extension so their bytes also
remain exact. The JSON contains only safe diagnostics, never polygons or image
data. Existing files cause a safe failure; add
`--overwrite-preview` to overwrite explicitly. Output contains filenames,
never the complete source path.

For real-photo evaluation, compare the baseline Top-K with the isolated Top-K,
inspect that the overlay and exact crop select the intended collectible, and
record status, correct Series rank, and added latency. No real call is part of
automated tests.

## ADC, APIs, IAM, cost, and privacy

Enable the Vertex AI API and Firestore API. For local verification:

```powershell
gcloud auth application-default login
gcloud auth application-default set-quota-project YOUR_PROJECT_ID
$env:GOOGLE_CLOUD_PROJECT="YOUR_PROJECT_ID"
```

The principal needs Vertex prediction permission (normally
`roles/aiplatform.user`) and the existing read permission for
`catalogFigureEmbeddings` (normally `roles/datastore.user`, or a narrower custom
role). PR4 does not require Storage access because its input is a local file.

Segmentation adds one paid Gemini vision request and its latency after the
existing locator/refiner work and before the paid embedding request. Rejected
photos incur localization cost but
make zero embedding calls and zero vector queries. Consult current Vertex AI
pricing rather than embedding a price in this implementation.

Source bytes and crops exist only in process memory unless the developer
explicitly requests local previews. Nothing is uploaded except the in-memory
image request to Vertex AI, and nothing is written to Firestore. Logs omit
vectors, bytes, base64, credentials, signed URLs, full source paths, and model
prose.

TinyTiny manual validation is intentionally opt-in and paid:

```powershell
cd D:\blindbox_app\functions

npm run retrieve:catalog-figures -- `
  --file "C:\Users\runze\Downloads\20260720_190908.jpg" `
  --top-k 5 `
  --isolate-subject `
  --preview-dir "C:\Users\runze\Downloads\tinytiny-preview" `
  --overwrite-preview
```

Compare the refined crop, mask, overlay, segmented subject, exact embedding
input, and Top-K. Confirm the complete head/body, both hair buns, hat, limbs,
clothing, attached flower, and tail remain; the can and background figure are
largely excluded; shelf background is reduced; geometry is not stretched; and
retrieval rank does not worsen. Nothing is hard-coded to this photo.

## Limitations

Semantic localization can still be wrong in very crowded, occluded, mirrored,
or unusually framed photos. Generated polygons are not guaranteed to be
pixel-perfect; transparent, reflective, heavily occluded, or extremely thin
parts may be missed. Technical thresholds are evaluation defaults and
need real-photo calibration. PR4 does not add recognition confidence,
distance interpretation, reranking, Catalog hydration, Flutter UI, uploads,
analytics, persistence, or multi-object shelf recognition.
