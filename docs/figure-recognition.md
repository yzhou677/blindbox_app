# Figure Recognition

Canonical product and architecture guide for Shelfy’s catalog-constrained
figure recognition. This document describes **current production behavior**.
Milestone / PR notes under `docs/FIGURE_RECOGNITION_*.md` are historical unless
explicitly marked current.

Related durable decisions:

- [`PDR-001: Figure Recognition Principles`](decisions/product/PDR-001-figure-recognition-principles.md)
- [`ADR-003: Catalog-constrained multimodal retrieval`](decisions/architecture/ADR-003-ai-figure-recognition-retrieval-architecture.md)

Operational endpoint notes:

- [`FIGURE_RECOGNITION_ENDPOINT.md`](FIGURE_RECOGNITION_ENDPOINT.md) — `recognizeFigureV1`
- [`FIGURE_SUBJECT_LOCATOR_ENDPOINT.md`](FIGURE_SUBJECT_LOCATOR_ENDPOINT.md) — `subjectLocatorV1`
- [`FIGURE_RECOGNITION_PR7.md`](FIGURE_RECOGNITION_PR7.md) — whole-image precheck

---

## Overview

Shelfy does **not** treat recognition as “AI one-tap identity.” Recognition is
**human-in-the-loop**, closed-world Catalog retrieval:

1. The collector chooses or captures a photo.
2. Shelfy may suggest a subject frame; the collector confirms or edits it.
3. Only a bounded crop of that confirmed subject is sent for recognition.
4. The backend retrieves Catalog candidates and applies a calibrated decision
   policy.
5. The collector reviews candidates (or a calm no-match) and opens Series
   details. Recognition **never auto-adds** to the shelf.

This keeps identity trustworthy, Collection mutation explicit, and cost bounded
to one intentional subject per attempt.

---

## End-to-end flow

```text
Local photo (camera / gallery)
  → Whole-image quality precheck (device-local, fail-open except extreme blur)
  → Photo review (“Use This Photo” / retake / choose another)
  → Subject framing (default box + optional locator suggestion; drag / resize)
  → Orientation-correct crop (no upscale; max long edge 4096)
  → recognizeFigureV1 (App Check callable, crop-only request v2)
  → Selected-subject blur gate (too_blurry stops before embedding)
  → Embedding + Firestore vector Top-K
  → CandidateRetrievalDecisionResolver
  → Hydration only when candidates are presentable
  → Candidate UI  or  No-match UI
  → Series navigation (preview or shelf Series sheet; Own/Add unchanged)
```

Entry points today: Discover / catalog search photo actions open the same
floating scan sheet (`showCatalogPhotoVerification`). Framing and recognition
stay inside that continuous sheet — there is no standalone result page.

---

## Whole-image and selected-subject blur

### Whole-image precheck (client)

After photo confirmation and before framing deep-work:

- Runs fully on-device (no upload / AI).
- Rejects only obviously unusable photos (strictly below the centralized
  extreme-failure floor). Equality passes.
- Uncertain photos proceed. Evaluation unavailable fails open.

### Selected-subject blur (backend)

After the collector confirms a frame:

| Subject quality | Behavior |
|---|---|
| `good` | Proceeds to embedding / retrieval |
| `borderline` | Proceeds the same way (no confirmation gate) |
| `too_blurry` | Response `too_blurry`; client returns to framing-friendly recovery |

There is **no** production “Photo may be a little soft” / “Continue Anyway”
Borderline confirmation flow. Legacy request field `continueBorderline` may
still be accepted for older clients and is ignored.

---

## Retrieval policy (production)

Production uses:

```text
CandidateRetrievalDecisionResolver
policyVersion: retrieval-policy-candidate-v1
calibrationProfile: figure-image-retrieval-v1
maximumTop1Distance: 0.240
minimumTop1Top2Gap: 0.025
```

`ShadowRetrievalDecisionResolver` is **evaluation / tooling only**. It does not
control `recognizeFigureV1`.

| Outcome | Condition (inclusive gates) | Hydration | Client UI |
|---|---|---|---|
| `high_confidence` | Top-1 ≤ 0.240 **and** gap ≥ 0.025 | Yes | Candidates; Best Match on rank 1 |
| `needs_review` | Top-1 ≤ 0.240 **and** gap &lt; 0.025 | Yes | Candidates; Best Match on rank 1 |
| `no_confident_match` | Top-1 &gt; 0.240, empty/invalid evidence, etc. | **No** | No-match analysis continuity |

Response statuses the client maps:

- `too_blurry`
- `no_confident_match`
- `candidates` + `high_confidence`
- `candidates` + `needs_review`

`subjectQuality` may still be `good` or `borderline` on presentable /
no-match responses (blur classification metadata). There is **no** response
`status: 'borderline'` — borderline subject quality proceeds into recognition
like good.

Responses never expose vectors, distances, thresholds, prompts, or model names.

---

## Recognition UX

### Review → Frame → Finding → Results

1. **Review** — photo-first confirmation; quiet guidance.
2. **Frame** — shared subject editor; locator suggestion is advisory; user edits
   win over late locator replies.
3. **Finding** — crop stays visible; thin indeterminate progress (no %); staged
   analysis checklist (Shape → Colors → Accessories → Facial details →
   Matching) paced for presentation while the real request runs.
4. **Results**
   - **Candidates:** Best Match card + other possibilities; full-card tap opens
     Series; no confidence percentages; no recognition-side Add-to-shelf CTA.
   - **No-match:** photo remains the visual anchor; checklist stays as completed
     analysis; Matching settles to a muted dash state (⊖), not a success check
     and not an error-red failure; actions: Try Another Photo / Adjust Frame /
     Create Custom Figure.

### Motion and timing

Checklist advances are cosmetic and centralized in `CollectibleMotion`
(~900ms → Matching hold). They do **not** drive backend phases.

- Early backend results cancel pending checklist timers (no artificial delay of
  no-match / failure).
- On successful candidates, Matching briefly settles to ✓ (~320ms) before
  candidate cards replace the finding chrome. Reduced motion skips the hold.
- Progress is indeterminate; never a fake percentage.

### Retry and crop reuse

The Flutter gateway prepares one orientation-correct crop Base64 per selection
and caches it on that selection object. **Retry reuses the prepared artifact**
unless the crop / selection changes or a new scan generation invalidates it.

---

## Backend architecture

```text
Crop (client v2)
  → validate + decode
  → selected-subject blur
  → image embedding (active Catalog embedding space)
  → Firestore vector Top-K
  → CandidateRetrievalDecisionResolver
  → hydrate Catalog display fields (names, imageKey) when presentable
  → bounded candidate presentation payload
```

Lazy Cloud Functions entry keeps `recognizeFigureV1` isolated from Market /
eBay / Mercari / Recommendations cold-start graphs. App Check remains required.

Recognize request **v2** is crop-only. Request **v1** (full image + selection)
remains for rolling compatibility; current Flutter clients send only v2.

---

## Navigation (discovery-first)

`openRecognitionCandidateSeries`:

- Not on shelf → `CatalogSeriesPreviewSheet`
- Already on shelf → `SeriesFiguresSheet` with matched figure scroll + temporary
  highlight
- Back returns to the still-open recognition results sheet
- Collection Own / Wishlist / Add semantics are unchanged
- Custom figure creation remains available from no-match

Recognition answers Catalog identity. Collection writes stay explicit user
actions.

---

## Future evolution

Non-commitments — roadmap directions consistent with PDR-001 / ADR-003. Each
step reuses the same closed-world Catalog retrieval core; Collection mutation
stays explicit.

```text
V1   Single collectible recognition
       (current: one intentional subject, one crop, candidate / no-match UI)

  ↓

V1.5 Multiple reference images per figure
       (richer Catalog embedding evidence for hard poses / packaging)

  ↓

V2   Series Scan
       (still intentional, but Series-aware assist across related figures)

  ↓

V3   Whole shelf recognition
       (detect / crop regions from a shelf photo; each region reuses V1)

  ↓

Future Fine-tuned reranker
         (optional downstream compare over verified Top-K only)
```

Related discussion topics that land here later: multi-reference training data,
shelf detection, model fine-tuning, and reranker evaluation. They do not change
V1’s human-in-the-loop contract.

Any threshold change remains a deliberate calibration + deploy event; this
document tracks live values only.
