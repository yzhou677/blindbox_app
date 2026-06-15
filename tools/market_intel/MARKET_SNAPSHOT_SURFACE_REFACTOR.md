# Sprint 2 Step 4F — Discover Market Snapshot (Gallery)

> **Date:** 2026-06-15 (final: Step 4F.5 accordion)  
> **Scope:** Discover / catalog gallery only. Market and Collection are future surfaces.  
> **Dev seed:** `node tools/market_intel/push_market_snapshots_dev.mjs`

---

## Summary

`CatalogFigureGallerySheet` shows market intelligence via a **disclosure accordion** — not `MarketSnapshotBadge`, not navigation to Market.

| State | UI |
|-------|-----|
| Collapsed | `▶ Market Information` only |
| Expanded | `▼ Market Information` + value/sales line + range + updated |
| No snapshot | No row |

**Tap target:** the disclosure row (`Market Information`). Value and sales appear only after expand.

---

## Copy

| Context | Collapsed | Expanded (first line after header) |
|---------|-----------|-------------------------------------|
| Figure snapshot | `▶ Market Information` | `Market Value · $42 · 18 sales` |
| Series fallback | `▶ Market Information` | `Using Series Estimate · $37 · 4 sales` |
| No data | *(hidden)* | — |

Expanded body also shows **Range** (`$38–$48`) and **Updated** (`Updated 1h ago`) when available.

---

## Widget tree

```
CatalogFigureGallerySheet
└── caption Column
    ├── Text (figure name)
    ├── _GalleryMarketInformationAccordion(figureId)
    │   └── marketSnapshotProvider(figureId)
    │       ├── null → SizedBox.shrink
    │       └── data → InkWell (disclosure toggle)
    │           ├── ▶ / ▼ Market Information
    │           └── [expanded] summary line + MarketSnapshotDiscoverExpandPanel
    └── Text? (series · rarity)
```

**Canonical figure id:** `CatalogFigureGalleryItem.id`

---

## Implementation

| Piece | Location |
|-------|----------|
| Accordion widget | [`catalog_figure_gallery_sheet.dart`](../../lib/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart) |
| Disclosure + summary formatters | [`market_snapshot_format.dart`](../../lib/features/market_intel/widgets/market_snapshot_format.dart) |
| Range + updated panel | [`market_snapshot_discover_expand_panel.dart`](../../lib/features/market_intel/widgets/market_snapshot_discover_expand_panel.dart) |
| Widget tests | [`catalog_figure_gallery_market_snapshot_test.dart`](../../test/catalog_figure_gallery_market_snapshot_test.dart) |

**Unchanged:** Firestore, repository, `marketSnapshotProvider`, series fallback logic.

**`MarketSnapshotBadge`:** retained for dev validation and future Market screen — not used in gallery.

---

## Data flow

```
Firestore market_snapshots
  → MarketSnapshotRepository
  → marketSnapshotProvider(figureId)
  → formatMarketSnapshotDiscoverDisclosureLabel / formatMarketSnapshotDiscoverSummaryLine
  → accordion UI
```

---

## Validation screenshots

Only folder kept under `tools/market_intel/screenshots/`:

[`screenshots/sprint_2_4f/`](./screenshots/sprint_2_4f/)

| File | Scenario |
|------|----------|
| `A_figure_collapsed.png` | Luck — `▶ Market Information` |
| `A_figure_expanded.png` | Luck — value, range, updated |
| `B_series_collapsed.png` | Hope — disclosure only |
| `B_series_expanded.png` | Hope — series estimate + range |
| `C_gallery_no_snapshot.png` | Winnie — no market row |
| `E_dark_expanded.png` | Luck expanded — dark mode |

```bash
flutter analyze
flutter test test/catalog_figure_gallery_market_snapshot_test.dart test/market_snapshot_format_test.dart test/market_snapshot_badge_test.dart
```

---

## Future surfaces (not in 4F)

- **Market** — full `MarketSnapshotBadge` / detail when Market ships
- **Collection** — portfolio-level estimated value (separate from catalog browse)

---

## Archived material (removed from repo)

Pre-integration screenshot sets (`sprint_2_4e`, `integration_audit`) and their review reports were deleted to keep `tools/market_intel` lean. Decisions are captured in this document.

**Note:** Screenshots live under `tools/` only — they are **not** bundled in the Flutter app (`pubspec.yaml` has no asset entries for them).
