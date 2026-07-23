# Figure Recognition Milestone 1

> **Historical implementation.** Bootstrap milestone. Current production
> recognition is summarized in [`figure-recognition.md`](figure-recognition.md).

Milestone 1 verifies that the existing Firebase backend can read one catalog
image from the project's default Firebase Storage bucket and request an image
embedding. It does not expose a Cloud Function, persist the vector, or perform
similarity search.

## Configuration

The typed configuration is in
`functions/src/figureRecognition/imageEmbeddingConfig.ts`:

- model: `gemini-embedding-2`, the current supported Google multimodal
  embedding model
- location: `us`
- output dimension: `1024`

The output dimension is requested explicitly and validated before a result is
returned. The vector exists only in process memory and is never logged.

## One real verification

Prerequisites:

1. Enable `aiplatform.googleapis.com` and billing for the project.
2. Configure local Application Default Credentials:

   ```powershell
   gcloud auth application-default login
   gcloud auth application-default set-quota-project blindbox-collection
   ```

3. Ensure that the ADC principal can read the Firebase Storage object and call
   the embedding model.

From `functions/`, choose an existing object path relative to the default
bucket. Do not pass an HTTP URL or `gs://` URI:

```powershell
$env:GOOGLE_CLOUD_PROJECT='blindbox-collection'
$env:FIREBASE_STORAGE_BUCKET='blindbox-collection.firebasestorage.app'
npm run verify:image-embedding -- 'catalog/path/to/figure.jpg'
```

The command builds the backend, reads the object, calls `embedContent` through
`@google/genai` in Vertex AI mode using ADC, and prints one JSON record with
only `success`, `model`, `location`, `dimension`, and `elapsedMs`. It never
prints or persists the vector or image bytes.

## Runtime permissions

The deployed Cloud Functions runtime service account needs:

- `roles/aiplatform.user` on the project, or a least-privilege custom role that
  includes `aiplatform.endpoints.predict` and `serviceusage.services.use`
- `roles/storage.objectViewer` on the default Firebase Storage bucket, or an
  equivalent grant containing `storage.objects.get`

No API key or repository secret is required. Milestone 1 does not export this
verification as a deployed function, so these runtime permissions are
documented for the later deployed caller and are not changed by this work.
