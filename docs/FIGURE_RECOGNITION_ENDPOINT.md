# Figure Recognition Endpoint (PR7 Part 4)

`recognizeFigureV1` is an App Check-protected Gen 2 callable used after the
collector confirms a subject frame. Flutter prepares one orientation-correct,
bounded selected-subject crop from the original acquired image and sends only
that crop. The original local image remains the coordinate source of truth;
the bounded locator transport image is never reused for recognition.

The client crop uses the same centralized 4096-pixel maximum dimension and
does not upscale. The backend validates the selected-subject crop, then runs
the frozen selected-subject blur evaluator, existing image embedding,
Firestore vector retrieval, and `ShadowRetrievalDecisionResolver`. Borderline
quality requires explicit continuation. Too-blurry selections stop before
embedding. The shadow resolver can return candidates for review or no confident
match; it never auto-confirms Top 1.

Candidate hydration reads Catalog documents only after ranking. It adds display
names and `imageKey` without reordering or filtering retrieval candidates. The
response never exposes vectors, distances, thresholds, prompts, model names, or
internal diagnostics. No Collection or Wishlist write is performed.

The crop-only request is version 2. The callable retains the version 1
original-image-plus-selection parser during rolling releases, while current
clients use only version 2. This prevents an app/function deployment-order
dependency without changing the current recognition path.

## Failure mapping

The subject locator is advisory. `no_suggestion`, locator timeout, malformed
locator output, and locator callable/network failure all continue to manual
framing with the centered default rectangle and no AI-suggestion label. They do
not produce `Scan unavailable`.

After the collector confirms a frame, selected-subject quality and recognition
are required dependencies. The client keeps these outcomes distinct:

- unsupported or unreadable original image: image preparation failure;
- selected subject classified too blurry: blocking quality state;
- quality evaluator unavailable: recoverable quality dependency failure;
- recognition timeout or callable/backend failure: `Scan unavailable`;
- valid retrieval with insufficient evidence: no confident match;
- malformed recognition response: recoverable backend failure.

Debug builds emit structured `[SubjectLocator]` and `[FigureRecognition]`
entries containing only function name, correlation ID, byte count, MIME type,
dimensions, elapsed time, result type, and sanitized callable error fields.
They never log image bytes, file paths, EXIF, tokens, or private metadata.

Runtime requirements:

- Vertex AI API enabled and ADC available to the Functions runtime.
- Runtime service account granted `roles/aiplatform.user`.
- Runtime service account granted read access to Firestore Catalog, embedding,
  and vector-index documents (normally `roles/datastore.user`; use a narrower
  custom read role when available).
- App Check configured for supported Flutter platforms.

Scoped deployment (not run as part of implementation verification):

```powershell
npm --prefix functions run deploy:figure-recognition -- --project blindbox-collection
```

Equivalent Firebase command:

```powershell
npx --prefix functions firebase deploy --only functions:market:recognizeFigureV1 --project blindbox-collection
```
