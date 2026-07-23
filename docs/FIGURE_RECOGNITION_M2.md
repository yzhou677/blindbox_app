# Figure Recognition V1 — Milestone 2

> **Historical implementation.** Embedding backfill milestone. See
> [`figure-recognition.md`](figure-recognition.md) for the live recognition path.

Milestone 2 creates one resumable, internal catalog-image embedding backfill. It
reads the canonical `figures` collection and default Firebase Storage bucket,
then writes one native Firestore vector document to
`catalogFigureEmbeddings/{figureId}`. It does not expose a Cloud Function.
This collection is derived, rebuildable infrastructure data; canonical catalog
documents remain the source of truth.

## Stored schema

Each document is keyed by the canonical `figureId` and contains
`figureId`, `seriesId`, `brandId`, `ipId`, `isSecret`, `imageObjectPath`,
`contentHash`, `embeddingSpace`, `embeddingModel`, `embeddingLocation`,
`embeddingDimension`, `embeddingVersion`, optional diagnostic
`catalogModifiedAt`, native-vector `embedding`, and server-managed `createdAt`
and `updatedAt`. Display names, URLs, tokens, bytes, and plain numeric vectors
are not stored.

## Configuration

- Model: `gemini-embedding-2` (the current supported Google multimodal embedding model)
- Vertex AI location: `us`
- Dimension: `1024`
- Version: `image-v1`
- Embedding space: `gemini-embedding-2_us_1024_image-v1`
- Planning price: `$0.00012` per image by default, overridable with
  `IMAGE_EMBEDDING_PRICE_PER_IMAGE_USD`

The default is an estimate based on Google's published Gemini Embedding 2 image
input price when this milestone was implemented. Pricing can change; check the
[official pricing page](https://cloud.google.com/gemini-enterprise-agent-platform/generative-ai/pricing)
and override the value before approving a run.

The output dimension is explicit and validated. Image bytes and vectors remain
in memory and are never logged. The persisted image identity is a SHA-256 hash
of the downloaded bytes.

## Run

Use Node 22, install the `functions/` dependencies, enable the Vertex AI and
Firestore APIs, and authenticate local ADC:

```powershell
gcloud auth application-default login
$env:GOOGLE_CLOUD_PROJECT='your-project-id'
$env:FIREBASE_STORAGE_BUCKET='your-project-id.appspot.com'
$env:IMAGE_EMBEDDING_PRICE_PER_IMAGE_USD='0.00012' # optional override
cd functions
npm run embed:catalog-figures -- --figure-id your-figure-id
```

For a bounded sequential batch:

```powershell
npm run embed:catalog-figures -- --limit 10
```

`--force` regenerates otherwise compatible vectors. Supported options are
`--limit`, `--figure-id`, `--force`, `--prune-stale-alternatives`, and
`--prune-dry-run` (requires prune). The tool exits nonzero if any figure
fails. It writes each successful figure immediately, so rerunning safely skips
compatible records. A metadata-only catalog identity change updates metadata
without another paid embedding call.

When a figure lists `alternativeImages`, the job embeds each supplemental
`imageKey` into `catalogFigureEmbeddings/{figureId}__alt__{imageKey}` after the
primary `{figureId}` document. Without `alternativeImages`, behavior remains
one primary embedding per figure. Stale alternative cleanup runs only when
`--prune-stale-alternatives` is set; it never deletes the primary document.

Every invocation first completes a read-only planning phase. It scans the
selected catalog range, resolves and hashes images, compares existing records,
and prints totals for up-to-date records, metadata-only updates, required
embeddings, missing images, estimated API calls, and estimated AI cost. The
execution phase begins only if the operator enters exactly `y` at the prompt.
Any other response exits without embedding calls or Firestore writes. Because
the planner does not retain catalog image bytes, images requiring embeddings
are downloaded again after confirmation.

Local ADC must identify a principal that can read `figures`, read objects from
the default bucket, call Vertex AI, and write `catalogFigureEmbeddings`. The
deployed runtime service account would need equivalent least-privilege access:

- `roles/aiplatform.user`
- `roles/storage.objectViewer` on the default bucket
- Firestore document read/write permission (commonly `roles/datastore.user`)
- permission to consume enabled services (commonly `serviceusage.services.use`,
  included in `roles/serviceusage.serviceUsageConsumer` when needed)

No IAM is changed by this repository. Do not run the command against production
without confirming the project, bucket, principal, and expected billing impact.
A full-catalog run makes paid model calls for every incompatible image and can
incur material cost; start with one figure or a small `--limit`.

The direct `@google-cloud/firestore` 8.6.0 dependency is intentionally separate
from Firebase Admin 10's older transitive Firestore client. npm therefore keeps
that older client nested for Admin while locking v8 for native-vector reads and
writes; Firebase Admin and Firebase Functions themselves are not upgraded.

## Deliberate limits

There is one active embedding space and no migration machinery. The job is
sequential and intended for controlled bootstrap/backfill use. This milestone
adds no vector index, similarity query, user-photo flow, scheduled job, trigger,
HTTP endpoint, Flutter behavior, or changes to Catalog/Collection/Market logic.
