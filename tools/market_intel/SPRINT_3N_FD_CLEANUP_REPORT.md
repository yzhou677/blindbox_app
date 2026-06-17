# Sprint 3N-FD — Repository Hygiene Cleanup Report

**Date:** 2026-06-16  
**Scope:** `tools/market_intel/` cleanup per [`SPRINT_3N_FC_REPOSITORY_HYGIENE_AUDIT.md`](./SPRINT_3N_FC_REPOSITORY_HYGIENE_AUDIT.md).  
**No production code, tests, Firebase, pipeline logic, or Flutter UI changes.**

---

## Summary

| Metric | Before | After |
|--------|-------:|------:|
| **Active `tools/market_intel/` files** | ~104 (excl. untracked temp) | **84** |
| **Active tree size** | ~14.9 MB (whole folder incl. untracked) | **4.79 MB** |
| **Archived (`archive/sprint_3n/`)** | 0 | **56 files, 8.44 MB** |
| **Deleted** | — | **~27 files** |

**Active tree reduction:** ~**10.1 MB** moved out of the working navigation path (archive + deletes).

---

## 1. Files deleted

### Temporary artifacts (untracked)

| Category | Files |
|----------|------:|
| UI dump XML (`debug_*.xml`, `_sprint_*_ui*.xml`) | 11 |
| One-off Python (`parse_*.py`, `debug_*.py`, `scan_cards.py`, etc.) | 14 |

### Generated JSON (tracked — `git rm`)

| File | Regenerate via |
|------|----------------|
| `snapshot_validation_report.json` | `node tools/market_intel/snapshot_validation_audit.mjs` |
| `catalog_coverage_report.json` | `node tools/market_intel/catalog_coverage_audit.mjs` |
| `production_readiness_audit.json` | (obsolete audit output) |
| `matcher_generalization_simulation.json` | `node tools/market_intel/matcher_generalization_simulation_audit.mjs` |

### Generated JSON (untracked)

| File |
|------|
| `_coverage_gap_counts.json` |
| `_sprint_3n_a2_forensics.json` |

### Empty directory

| Path |
|------|
| `screenshots/sprint_3c/` |

**Delete total:** ~27 files, ~**0.6 MB**

---

## 2. Files archived (`tools/market_intel/archive/sprint_3n/`)

### Docs (17)

`CATALOG_EXPORT_AUTOMATION_PLAN.md`, `MARKET_PIPELINE_ALIGNMENT_PLAN.md`, `MARKET_SNAPSHOT_PIPELINE_FORENSICS.md`, `MARKET_COVERAGE_GAP_AUDIT.md`, `NON_BLINDBOX_*` (4), `NON_BLINDBOX_TIER_B_VOCABULARY_*` (2), `PRODUCTION_READINESS_AUDIT.md`, `MARKET_TRUST_AUDIT.md`, `MARKET_TRUST_REMEDIATION_PLAN.md`, `VALUATION_TRANSPARENCY_AUDIT.md`, `FIRESTORE_E2E_VALIDATION_REPORT.md`, `MARKET_SNAPSHOT_ARCHITECTURE_AUDIT.md`, `MARKET_SNAPSHOT_SURFACE_REFACTOR.md`, `MATCHER_GENERALIZATION_SIMULATION_REPORT.md`

### Screenshots (28 PNG)

| Folder | Count |
|--------|------:|
| `sprint_2_4f/` | 6 |
| `sprint_3e/before/` + `after/` | 6 |
| `sprint_3f/` | 5 |
| `sprint_3k/` | 2 |
| `sprint_3l/` | 2 |
| `sprint_3n_a2/` | 5 |

### Scripts (12)

Forensics: `_sprint_3nc_*.mjs`, `_sprint_3nd_*.mjs`, `_pipeline_forensics_*.mjs`, `_coverage_gap_*.mjs`, `_fixture_full_catalog_count.mjs`

Capture (obsolete): `capture_sprint_3c/3e/3f/3k/3l/3n_a2_device_screenshots.py`

**Archive total:** 56 files, **8.44 MB** (git history preserved via `git mv` where tracked)

---

## 3. Active tree kept

### Screenshots (15 PNG)

- `screenshots/sprint_3i/` (7)
- `screenshots/sprint_3j/` (4)
- `screenshots/sprint_3m_c/` (4)

### Active capture scripts

- `capture_sprint_3i_device_screenshots.py`
- `capture_sprint_3j_device_screenshots.py`
- `capture_sprint_3m_c_device_screenshots.py`
- `capture_sprint_3m_device_screenshots.py`
- `capture_sprint_3d_device_screenshots.py`

### Key docs

`CATALOG_MARKET_ARCHITECTURE_REVIEW.md`, `SPRINT_3N_FB_IMPLEMENTATION.md`, `SPRINT_3N_E_IMPLEMENTATION.md`, `MATCHING_DESIGN.md`, `SOLD_LISTING_DATA_SOURCE.md`, `MARKET_DETAIL_INSIGHTS_DESIGN.md`, `DEV_VALIDATION.md`, etc.

---

## 4. Documentation touch-ups (non-production)

| File | Change |
|------|--------|
| `MARKET_DETAIL_INSIGHTS_DESIGN.md` | Screenshot section → active `3i/3j/3m_c` only |
| `FIRESTORE_PERSISTENCE_DESIGN.md` | Link to archived `PRODUCTION_READINESS_AUDIT.md` |
| `CATALOG_MARKET_ARCHITECTURE_REVIEW.md` | Link to archived export plan |
| `archive/README.md` | **New** — superseded-by map |
| `.gitignore` | Ignore regen JSON + debug XML |

---

## 5. Build impact verification

### `pubspec.yaml`

```yaml
flutter:
  assets:
    - tools/seed/    # only tools/ path bundled
```

No `tools/market_intel/`, `archive/`, or `docs/` entries.

### Release APK (`build/app/outputs/flutter-apk/app-release.apk`)

| Path pattern | In APK? |
|--------------|---------|
| `assets/flutter_assets/tools/seed/*.json` | **Yes** |
| `market_intel` | **No** |
| `archive` | **No** |
| `docs/` | **No** |
| `screenshots` (under tools) | **No** |

**Conclusion:** Cleanup does not change app binary contents.

---

## 6. Success criteria

| Criterion | Met |
|-----------|-----|
| Active tree smaller / easier to navigate | Yes — 84 vs ~104 active files; screenshots 15 vs 41 |
| No production behavior changes | Yes |
| No Flutter / test / Firebase / pipeline code changes | Yes |
| No build output changes | Yes — same `pubspec` asset set |
| Git history preserved for tracked moves | Yes — `git mv` / rename detection |

---

## 7. Active layout (post-cleanup)

```text
tools/market_intel/
  *.mjs              # pipeline + audits (regen tools)
  market_metadata.json
  MATCHING_DESIGN.md
  SOLD_LISTING_DATA_SOURCE.md
  CATALOG_MARKET_ARCHITECTURE_REVIEW.md
  SPRINT_3N_*_IMPLEMENTATION.md
  screenshots/sprint_3i|3j|3m_c/
  archive/
    README.md
    sprint_3n/       # historical
tools/catalog/
  (code + tests only)
```
