# Catalog figure art — re-export guide (catalog development / asset workflows)

> **Not runtime metadata.** APK-bundled `tools/seed/*.json` was removed; catalog metadata at runtime comes from Firestore + persisted cache only ([`docs/CATALOG_ARCHITECTURE.md`](../../docs/CATALOG_ARCHITECTURE.md)). This guide applies to **catalog development** — Firestore ingestion, Storage uploads, and external export JSON — not to app startup.

**Audience:** Cursor agent working in the **external catalog repo** or admin tooling (Firestore export, Storage uploads, `D:\blindbox-catalog\data\*.json`).  
**Consumer app:** `blindbox_app` — gallery, search thumbs, series browse. Frontend can blur letterbox and adapt fit, but **cannot fix a full-poster composite used as a figure**, wrong aspect, or a missing Storage object.

Use this doc to **audit existing `figures` + Storage objects** and output a **re-download / re-export checklist** for the human.

QA findings split into **failures** (block `publish-series`) and **warnings** (list only). See [`.cursor/skills/catalog-image-qa/SKILL.md`](../../.cursor/skills/catalog-image-qa/SKILL.md).

---

## What the app cannot fix (must replace asset)

| Problem | Why UX breaks | Replace? |
|--------|----------------|----------|
| **Full marketing poster or collage as the figure file** | Several products, a campaign layout, or a lineup in one frame — not a single figure | **Yes — priority** (`PROMO_COMPOSITE`) |
| **Landscape promo in portrait UI** | Even with blur-backdrop gallery, the crop feels wrong | **Yes** |
| **Light/beige solid page background** (esp. Secret) | Clashes with dark premium UI; looks like a PDF slide, not product art | **Yes** |
| **Heavy lifestyle scene** (moss, flowers, props) as only figure asset | Inconsistent vs cutout figures; thumb/gallery compete with background | **Yes — prefer cutout** |
| **Wrong aspect “poster” not product** | User expects one figure; image is a 16:9 campaign banner | **Yes** |
| **Missing / 404 Storage object** | Placeholder only; looks broken in search | **Yes** |
| **imageKey ≠ filename stem** | Resolver 404; same as missing | **Fix upload or key** |
| **Tiny subject in large canvas** | Huge empty margins; figure feels like a stamp | **Yes** |

Printed titles, logos, rarity labels, or the word SECRET on an otherwise single-figure shot are **allowed**. Do not flag those as `PROMO_COMPOSITE`.

## What the app can tolerate (optional improvement)

| Problem | Mitigation in app | Replace? |
|--------|-------------------|----------|
| Mild letterboxing on square cutout | Blur backdrop + contain in gallery; `AppImageFrame` on thumbs | Optional |
| Slightly soft JPEG source converted to WebP | Higher-res re-export helps; not blocking | Optional |
| Transparent WebP with extra padding | `transparentFigure` contain + inset | Optional trim in export |
| Long edge under 1200px | App still shows the art | **Warning only** (`LOW_RES` if &lt; 800) |
| Series cover editorial crop | Cover fill is intentional for **series** covers only | N/A for figures |

---

## Target asset spec (replacement figures)

Produce **one primary file per figure** at:

`catalog/figures/<imageKey>.<ext>`  
(`imageKey` = Firestore `figures/{id}` stem; see [FIREBASE_STORAGE_CATALOG.md](../../lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md))

**Prefer `.webp`.** Keep alpha when converting from a transparent source. `.png` / `.jpg` / `.jpeg` remain supported when conversion fails or is a poor fit — report `NON_WEBP` as a **warning**, do not block publish. After writing, each `imageKey` should have **one** file (remove duplicate same-stem leftovers). The app probes `.webp`, `.png`, `.jpg`, `.jpeg`, `.avif` for Storage.

### Required traits (“good” figure art)

1. **Subject:** Single figure, centered, about **70–85%** of the frame height. A Secret may still show the figure (including on-image SECRET labels).
2. **Background:** Transparent cutout **preferred**; else a very soft neutral gradient (not a cream poster page).
3. **Aspect:** **1:1** (preferred) or **4:5** portrait — not 16:9 landscape.
4. **Resolution:** Suggested long edge **≥ 1200px** (app decodes up to ~1536px in gallery). Long edge under 800px is `LOW_RES` — **warning only**, not a publish blocker.
5. **Format:** Prefer `.webp`. `.png` / `.jpg` / `.jpeg` are allowed. Preserve alpha on cutouts when the format supports it.

### Series cover (`catalog/series/<imageKey>.<ext>`) — different rules

- Cover **may** be editorial collage / lifestyle.
- Prefer `.webp`; other supported extensions are allowed.
- Do **not** reuse series cover as figure art.

---

## How to flag figures for the human’s re-download list

Scan every `figures/*.json` row (and Storage `catalog/figures/*`). Flag **`REEXPORT`** when **any** apply:

### A. Visual / content (manual review or vision)

- [ ] Image is a **full promotional poster or collage** (several products / lineup), not a single figure. On-image text alone is not enough.
- [ ] **Multiple figures** visible as main content (lineup poster).
- [ ] **Landscape** width > height by ~20%+.
- [ ] **Solid light** background (#F5F0E8-style) especially for `isSecret`.
- [ ] Figure occupies **&lt; 50%** of frame area (excess empty margin).

### B. Technical (scriptable)

- [ ] No supported file at `catalog/figures/<imageKey>.{webp,png,jpg,jpeg,avif}` — **failure** `MISSING_ASSET`.
- [ ] The only (or primary) file is not `.webp` — **warning** `NON_WEBP`; do not block publish.
- [ ] `imageKey` empty or ≠ document `id` stem.
- [ ] Only `thumbnailAsset` legacy path in seed without Storage upload (app may 404).

### C. Known bad patterns from app QA (May 2026)

Series **`baby_three_the_fairytale_world_series`** (`The Fairytale World Series Plush Blind Box`):

- Many regular figures observed as **full promo composites** (lineup / bordered lifestyle posters), not single-figure product art.
- **`baby_three_the_fairytale_world_series_secret`** — silhouette on **light beige** card; breaks dark gallery (`LIGHT_SOLID_BG`).
- **Action:** Prefer single-figure cutouts on transparent or dark-friendly backgrounds where possible.

Use this series as the **reference example** when explaining “bad vs good” to stakeholders.

---

## Output format for the catalog agent

Deliver two lists. **Failures** block `publish-series`. **Warnings** do not.

```text
## Failures
| Priority | seriesId | figureId | imageKey | isSecret | Reason code | Notes |
|----------|----------|----------|----------|----------|-------------|-------|
| P0 | baby_three_the_fairytale_world_series | ..._kitty_belle_pink | ... | false | PROMO_COMPOSITE | full lineup poster, not one figure |
| P2 | ... | ... | ... | false | MISSING_ASSET | no supported file on disk |

## Warnings
| Priority | seriesId | figureId | imageKey | isSecret | Reason code | Notes |
|----------|----------|----------|----------|----------|-------------|-------|
| P2 | ... | ... | ... | false | LOW_RES | long edge 400 |
| P2 | ... | ... | ... | false | NON_WEBP | kept as .png after convert skipped |
```

**Reason codes** (use exactly):

- `PROMO_COMPOSITE` — **failure** — full marketing poster or collage, not a single figure. Do not use for on-image title, logo, rarity, or SECRET text on a single figure.
- `LANDSCAPE_POSTER` — **failure** — aspect ratio wrong for figure slot
- `LIGHT_SOLID_BG` — **failure** — off-brand solid light background (incl. Secret cards)
- `MULTI_SUBJECT` — **failure** — multiple figures in one asset
- `SMALL_SUBJECT` — **failure** — tiny figure in large canvas
- `MISSING_ASSET` — **failure** — no supported image file for a required key
- `IMAGEKEY_MISMATCH` — **failure** — key/path mismatch
- `SERIES_COVER_USED` — **failure** — figure slot uses series poster art
- `LOW_RES` — **warning** — long edge &lt; 800px
- `NON_WEBP` — **warning** — file is not `.webp` (png/jpg/jpeg/avif still allowed; do not block publish)

Sort within each list: **P0** = gallery/search embarrassment, **P1** = inconsistent but usable, **P2** = nice to have.

---

## Do not change (unless fixing above)

- Firestore schema: still **`imageKey` only**, no URLs on docs.
- Storage paths: `catalog/figures/<imageKey>.<ext>` with preferred `.webp`; app probes supported extensions.
- Document ids / `imageKey` stems (renaming forces app + shelf migration).

Replace **binaries only**, keep ids stable.

---

## Optional: two-tier asset model (future)

If the catalog pipeline supports it later:

| Role | Use in app | Notes |
|------|------------|-------|
| `figure_cutout` | thumbs, gallery, add-series | transparent, 1:1 |
| `figure_promo` | marketing web only | campaign posters OK here |

Not implemented in app yet — until then, the single-figure product file must live at the canonical `imageKey` path.

---

## References in blindbox_app

- Storage: `lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md`
- Resolver: `lib/features/catalog/catalog_image_resolver.dart`
- Display rules: `lib/features/catalog/presentation/catalog_image_display.dart`
- Gallery stage (blur backdrop): `lib/features/catalog/presentation/figure_gallery/catalog_gallery_stage.dart`
- Skills: `.cursor/skills/catalog-image-qa/SKILL.md`, `.cursor/skills/add-series-local/SKILL.md`, `.cursor/skills/publish-series/SKILL.md`
