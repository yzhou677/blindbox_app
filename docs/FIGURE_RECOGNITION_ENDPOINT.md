# Figure Recognition Endpoint (PR7 Part 4)

`recognizeFigureV1` is an App Check-protected Gen 2 callable used after the
collector confirms a subject frame. The request contains the original acquired
image and a normalized rectangle in oriented-image coordinates. The bounded
locator transport image is never reused for recognition.

The backend uses `PrimarySubjectCropper` as the canonical crop implementation,
then runs the frozen selected-subject blur evaluator, existing image embedding,
Firestore vector retrieval, and `ShadowRetrievalDecisionResolver`. Borderline
quality requires explicit continuation. Too-blurry selections stop before
embedding. The shadow resolver can return candidates for review or no confident
match; it never auto-confirms Top 1.

Candidate hydration reads Catalog documents only after ranking. It adds display
names and `imageKey` without reordering or filtering retrieval candidates. The
response never exposes vectors, distances, thresholds, prompts, model names, or
internal diagnostics. No Collection or Wishlist write is performed.

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

