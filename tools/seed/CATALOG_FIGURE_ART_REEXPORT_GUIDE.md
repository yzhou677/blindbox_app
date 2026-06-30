# Catalog figure art — re-export guide (catalog development / asset workflows)

> **Not runtime metadata.** APK-bundled `tools/seed/*.json` was removed; catalog metadata at runtime comes from Firestore + persisted cache only ([`docs/CATALOG_ARCHITECTURE.md`](../../docs/CATALOG_ARCHITECTURE.md)). This guide applies to **catalog development** — Firestore ingestion, Storage uploads, and external export JSON — not to app startup.

**Audience:** Cursor agent working in the **external catalog repo** or admin tooling (Firestore export, Storage uploads, `D:\blindbox-catalog\data\*.json`).  
**Consumer app:** `blindbox_app` — gallery, search thumbs, series browse. Frontend can blur letterbox and adapt fit, but **cannot fix baked-in promo graphics or wrong asset types**.

Use this doc to **audit existing `figures` + Storage objects** and output a **re-download / re-export checklist** for the human.

---

## What the app cannot fix (must replace asset)

| Problem | Why UX breaks | Replace? |
|--------|----------------|----------|
| **Marketing / poster composite** | Series title, logos, hand-drawn borders, multiple products in one frame baked into pixels | **Yes — priority** |
| **Landscape promo in portrait UI** | Even with blur-backdrop gallery, text/logos stay tiny or cropped awkwardly | **Yes** |
| **Light/beige solid page background** (esp. Secret) | Clashes with dark premium UI; looks like a PDF slide, not product art | **Yes** |
| **Heavy lifestyle scene** (moss, flowers, props) as only figure asset | Inconsistent vs cutout figures; thumb/gallery compete with background | **Yes — prefer cutout** |
| **Wrong aspect “poster” not product** | User expects one figure; image is a 16:9 campaign banner | **Yes** |
| **Missing / 404 Storage object** | Placeholder only; looks broken in search | **Yes** |
| **imageKey ≠ filename stem** | Resolver 404; same as missing | **Fix upload or key** |
| **Tiny subject in large canvas** | Huge empty margins; figure feels like a stamp | **Yes** |

## What the app can tolerate (optional improvement)

| Problem | Mitigation in app | Replace? |
|--------|-------------------|----------|
| Mild letterboxing on square cutout | Blur backdrop + contain in gallery; `AppImageFrame` on thumbs | Optional |
| Slightly soft JPEG | Higher-res re-export helps; not blocking | Optional |
| Transparent PNG with extra padding | `transparentFigure` contain + inset | Optional trim in export |
| Series cover editorial crop | Cover fill is intentional for **series** covers only | N/A for figures |

---

## Target asset spec (replacement figures)

Produce **one primary file per figure** at:

`catalog/figures/<imageKey>.<ext>`  
(`imageKey` = Firestore `figures/{id}` stem; see [FIREBASE_STORAGE_CATALOG.md](../../lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md))

### Required traits (“good” figure art)

1. **Subject:** Single figure (or single secret silhouette), centered,占画面 **~70–85%** 高度.
2. **Background:** Transparent PNG/WebP **preferred**; else very soft neutral gradient (not cream poster page).
3. **Aspect:** **1:1** (preferred) or **4:5** portrait — not 16:9 landscape.
4. **No baked UI:** No series name, brand logo, “Baby Three”, rarity text, decorative frame, collage of全系列.
5. **Resolution:** Long edge **≥ 1200px** (app decodes up to ~1536px in gallery).
6. **Format:** `.webp` or `.png` (keep alpha for plush/cutout).
7. **Secret (`isSecret: true`):** App-themed **silhouette / mystery** on **transparent or dark-friendly** background — not beige card mockup.

### Series cover (`catalog/series/<imageKey>`) — different rules

- Cover **may** be editorial collage / lifestyle.
- Do **not** reuse series cover as figure art.

---

## How to flag figures for the human’s re-download list

Scan every `figures/*.json` row (and Storage `catalog/figures/*`). Flag **`REEXPORT`** when **any** apply:

### A. Visual / content (manual review or vision)

- [ ] Image is clearly a **promotional poster** (text overlays, logos, ornate border).
- [ ] **Multiple figures** visible as main content (lineup poster).
- [ ] **Landscape** width > height by ~20%+.
- [ ] **Solid light** background (#F5F0E8-style) especially for `isSecret`.
- [ ] Figure occupies **< 50%** of frame area (excess empty margin).

### B. Technical (scriptable)

- [ ] No object at `catalog/figures/<imageKey>.{avif,webp,png,jpg,jpeg}`.
- [ ] `imageKey` empty or ≠ document `id` stem.
- [ ] Only `thumbnailAsset` legacy path in seed without Storage upload (app may 404).

### C. Known bad patterns from app QA (May 2026)

Series **`baby_three_the_fairytale_world_series`** (`The Fairytale World Series Plush Blind Box`):

- All regular figures observed as **square promo composites** (“My Woodland Story”, “Baby Three” script, doodle borders, lifestyle photo).
- **`baby_three_the_fairytale_world_series_secret`** — silhouette on **light beige** card; breaks dark gallery.
- **Action:** Re-export **entire series lineup** as transparent/clean cutouts; Secret as dark-theme mystery asset.

Use this series as the **reference example** when explaining “bad vs good” to stakeholders.

---

## Output format for the catalog agent

Deliver a table the human can work from:

```text
| Priority | seriesId | figureId | imageKey | isSecret | Reason code | Notes |
|----------|----------|----------|----------|----------|-------------|-------|
| P0 | baby_three_the_fairytale_world_series | ..._secret | ..._secret | true | SECRET_LIGHT_BG | beige poster card |
| P0 | baby_three_the_fairytale_world_series | ..._kitty_belle_pink | ... | false | PROMO_COMPOSITE | title + border baked in |
| P1 | ... | ... | ... | false | LANDSCAPE_POSTER | 16:9 promo |
| P2 | ... | ... | ... | false | MISSING_STORAGE | 404 |
```

**Reason codes** (use exactly):

- `PROMO_COMPOSITE` — marketing poster, not product
- `LANDSCAPE_POSTER` — aspect ratio wrong for figure slot
- `LIGHT_SOLID_BG` — off-brand background (incl. Secret cards)
- `MULTI_SUBJECT` — multiple figures in one asset
- `SMALL_SUBJECT` — tiny figure in large canvas
- `MISSING_STORAGE` — no file at canonical path
- `IMAGEKEY_MISMATCH` — key/path mismatch
- `SERIES_COVER_USED` — figure slot uses series poster art
- `LOW_RES` — long edge < 800px (if checked)

Sort: **P0** = gallery/search embarrassment, **P1** = inconsistent but usable, **P2** = nice to have.

---

## Do not change (unless fixing above)

- Firestore schema: still **`imageKey` only**, no URLs on docs.
- Storage paths: `catalog/figures/<imageKey>.<ext>`.
- Document ids / `imageKey` stems (renaming forces app + shelf migration).

Replace **binaries only**, keep ids stable.

---

## Optional: two-tier asset model (future)

If the catalog pipeline supports it later:

| Role | Use in app | Notes |
|------|------------|-------|
| `figure_cutout` | thumbs, gallery, add-series | transparent, 1:1 |
| `figure_promo` | marketing web only | current posters OK here |

Not implemented in app yet — until then, **cutout must live at the canonical `imageKey` path**.

---

## References in blindbox_app

- Storage: `lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md`
- Resolver: `lib/features/catalog/catalog_image_resolver.dart`
- Display rules: `lib/features/catalog/presentation/catalog_image_display.dart`
- Gallery stage (blur backdrop): `lib/features/catalog/presentation/figure_gallery/catalog_gallery_stage.dart`
