# Figure Recognition V1 — Milestone 3 Retrieval

> **Historical implementation.** Developer retrieval CLI milestone. Production
> recognition decisions are documented in
> [`figure-recognition.md`](figure-recognition.md).

Milestone 3 is an internal developer evaluation tool. It reads one local image,
generates a 1024-dimensional `gemini-embedding-2` embedding in Vertex AI, and
returns the nearest documents from `catalogFigureEmbeddings`. It does not decide
whether a candidate is a correct recognition result and persists nothing.

## Firestore index

The query filters `embeddingSpace` to
`gemini-embedding-2_us_1024_image-v1` and performs `COSINE` nearest-neighbor
search on the 1024-dimensional `embedding` field. The required composite vector
index is declared in `firestore.indexes.json`.

Deploy indexes separately before using the tool:

```powershell
firebase deploy --only firestore:indexes
```

This change does not create or deploy the index. Firestore builds it
asynchronously; retrieval remains unavailable until the index is ready.

## Local use

Use Node 22 and local Application Default Credentials:

```powershell
gcloud auth application-default login
$env:GOOGLE_CLOUD_PROJECT='your-project-id'
cd functions
npm run retrieve:catalog-figures -- --file 'D:\photos\figure.jpg'
npm run retrieve:catalog-figures -- --file 'D:\photos\figure.jpg' --top-k 10
```

Top-K defaults to 5 and must be between 1 and 20. Supported image bytes are
PNG, JPEG, WebP, BMP, HEIC, HEIF, and AVIF. The tool detects MIME type from file
contents, does not upload the input, and does not log its full path or contents.

The ADC principal needs Vertex AI model invocation, Firestore query access, and
service usage permission. Common roles are `roles/aiplatform.user`,
`roles/datastore.user`, and, when not otherwise included,
`roles/serviceusage.serviceUsageConsumer`. No Storage permission is required.

Expected candidate output is intentionally ID-only:

```text
Rank 1
figureId: example-figure
seriesId: example-series
brandId: example-brand
ipId: example-ip
isSecret: false
distance: 0.123
```

Smaller cosine distance is nearer. Distance is not confidence, and this
milestone adds no threshold, recognition state, Catalog-name hydration,
Collection behavior, API, upload, or query persistence.
