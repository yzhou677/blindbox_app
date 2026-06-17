# Sprint 3N-FC — Repository Hygiene Audit

**Date:** 2026-06-16  
**Type:** Cleanup proposal only — **no deletions performed** in this sprint.  
**Goal:** Prepare `tools/market_intel/`, `docs/`, and screenshot artifacts for Marketplace Insights integration.

---

## Executive summary

| Area | Files (approx.) | Disk | Bundle impact |
|------|----------------:|-----:|---------------|
| `tools/market_intel/` (total) | 166 | **14.9 MB** | **None** (except `market_metadata.json` is pipeline-only, not in APK) |
| `tools/market_intel/screenshots/` | 41 PNG | **12.2 MB** (82% of folder) | **None** |
| `docs/` | 27 | **0.2 MB** | **None** |
| Repo root `screenshots/` | 0 | — | — |

**Flutter AAB/APK:** Only `tools/seed/*.json` (+ one seed markdown guide) ship in release builds. Market intel screenshots, docs, and debug artifacts do **not** affect app binary size.

**Recommended cleanup (when executed):** ~55 files deleted, ~8–10 MB recovered, **low risk**. Archive ~25 investigation docs/scripts into `tools/market_intel/archive/sprint_3n/` rather than deleting audit history.

---

## 1. Inventory

### 1.1 `tools/market_intel/` — design documents

| Document | Classification | Notes |
|----------|----------------|-------|
| `MATCHING_DESIGN.md` | **Active reference** | Pipeline matcher contract; cited in `docs/architecture/MARKET_INTELLIGENCE_EVOLUTION.md` |
| `SEARCH_TERM_DERIVATION_DESIGN.md` | **Active reference** | Search plan derivation rules |
| `METADATA_AUTOGEN_DESIGN.md` | **Active reference** | Future metadata overlay; inputs should move to Firestore export (note in doc) |
| `MATCHER_DESIGN_REVIEW.md` | **Active reference** | Matcher behavior spec |
| `MATCHER_GENERALIZATION_DESIGN.md` | **Active reference** | Generalization strategy |
| `QUERY_VOLUME_OPTIMIZATION.md` | **Active reference** | Cited in `docs/TECH_DEBT.md` |
| `SOLD_LISTING_DATA_SOURCE.md` | **Active reference** | Insights blocker; cited in `docs/TECH_DEBT.md` |
| `FIRESTORE_PERSISTENCE_DESIGN.md` | **Historical / partial** | Push tool shipped; scheduler sections aspirational |
| `MARKET_DETAIL_INSIGHTS_DESIGN.md` | **Active reference** | UI surfaces; embeds screenshot paths |
| `MARKET_EXPERIENCE_DESIGN.md` | **Active reference** | Product UX direction |
| `COLLECTION_VALUE_DESIGN.md` | **Active reference** | Shelf value surfaces |
| `MARKET_SNAPSHOT_SURFACE_REFACTOR.md` | **Historical record** | Sprint 2.4 refactor; links `sprint_2_4f` screenshots |
| `DEV_VALIDATION.md` | **Active reference** | Dev seeder workflow; cited from Dart dev screen |
| `MARKET_SNAPSHOT_ARCHITECTURE_AUDIT.md` | **Historical record** | Pre–3N-FB architecture snapshot |
| `MARKET_TRUST_AUDIT.md` | **Historical record** | Sprint 3G findings; superseded by remediation + 3M |
| `MARKET_TRUST_REMEDIATION_PLAN.md` | **Historical record** | Sprint 3I–3L backlog; largely implemented |
| `VALUATION_TRANSPARENCY_AUDIT.md` | **Historical record** | Sprint 3M input |
| `PRODUCTION_READINESS_AUDIT.md` | **Obsolete / superseded** | States pipeline uses seed; pre–3N-D/3N-FB |
| `CATALOG_MARKET_ARCHITECTURE_REVIEW.md` | **Active reference** | **Current** catalog/market architecture (post–3N-FA.1) |
| `SPRINT_3N_E_IMPLEMENTATION.md` | **Historical record** | Shipped 3N-E summary |
| `SPRINT_3N_FB_IMPLEMENTATION.md` | **Active reference** | **Current** pipeline catalog loader |
| `MARKET_PIPELINE_ALIGNMENT_PLAN.md` | **Obsolete / superseded** | Export-first + daily GHA; contradicted by 3N-FA.1 / 3N-FB |
| `MARKET_SNAPSHOT_PIPELINE_FORENSICS.md` | **Historical record** | Root-cause audit; seed-default facts fixed in 3N-FB |
| `MARKET_COVERAGE_GAP_AUDIT.md` | **Historical record** | Coverage investigation (untracked) |
| `NON_BLINDBOX_PRODUCTION_AUDIT.md` | **Historical record** | Untracked |
| `NON_BLINDBOX_FALLBACK_AUDIT.md` | **Historical record** | Untracked |
| `NON_BLINDBOX_MARKET_FORENSICS.md` | **Historical record** | Untracked; references `sprint_3n_a2` screenshots |
| `NON_BLINDBOX_TIER_B_VOCABULARY_PLAN.md` | **Historical record** | Superseded by shipped 3N-E |
| `NON_BLINDBOX_TIER_B_VOCABULARY_UX_REVIEW.md` | **Historical record** | Superseded by shipped 3N-E |
| `FIRESTORE_E2E_VALIDATION_REPORT.md` | **Historical record** | One-time dev seeder validation |
| `CATALOG_COVERAGE_REPORT.md` | **Generated artifact** | Output of `catalog_coverage_audit.mjs` |
| `SNAPSHOT_VALIDATION_REPORT.md` | **Generated artifact** | Output of `snapshot_validation_audit.mjs` |
| `MATCHER_GENERALIZATION_SIMULATION_REPORT.md` | **Generated artifact** | Output of simulation script |

### 1.2 `tools/catalog/` — design documents

| Document | Classification | Notes |
|----------|----------------|-------|
| `CATALOG_EXPORT_AUTOMATION_PLAN.md` | **Obsolete / superseded** | Daily export + blindbox-catalog hub; **replaced by** `CATALOG_MARKET_ARCHITECTURE_REVIEW.md` + 3N-FB direct Firestore |

### 1.3 `docs/` — market-intelligence-related

| Document | Classification | Notes |
|----------|----------------|-------|
| `docs/architecture/MARKET_INTELLIGENCE_EVOLUTION.md` | **Active reference** | Canonical evolution narrative |
| `docs/COLLECTIBLE_MARKET_INTELLIGENCE.md` | **Active reference** | Browse listing intelligence (separate from V2 `market_snapshots`) |
| `docs/TECH_DEBT.md` | **Active reference** | Links to `SOLD_LISTING_DATA_SOURCE`, `QUERY_VOLUME_OPTIMIZATION`, scheduler debt |
| `docs/MARKET_PRODUCTION_HARDENING.md` | **Active reference** | Production hardening notes |
| `docs/release_candidate_test_plan.md` | **Active reference** | QA plan; mentions seed fallback (app, not pipeline) |
| Other `docs/*` | **Out of scope** | Collection, privacy, Mercari, Play Store — not market-intel hygiene |

### 1.4 `tools/market_intel/` — sprint reports & audits (untracked)

All **untracked** as of audit date — safe to archive without git history loss if never committed:

| Item | Classification |
|------|----------------|
| `MARKET_COVERAGE_GAP_AUDIT.md` | Historical record |
| `MARKET_PIPELINE_ALIGNMENT_PLAN.md` | Obsolete (duplicate if committed later) |
| `MARKET_SNAPSHOT_PIPELINE_FORENSICS.md` | Historical record |
| `NON_BLINDBOX_*.md` (4 files) | Historical record |
| `_sprint_3n_a2_forensics.json` | Generated artifact |
| `_coverage_gap_counts.json` | Generated artifact |

### 1.5 `tools/market_intel/screenshots/`

| Folder | Files | Size | Referenced in docs? | Classification |
|--------|------:|-----:|---------------------|----------------|
| `sprint_2_4f/` | 6 | 3.95 MB | `MARKET_SNAPSHOT_SURFACE_REFACTOR.md` | Historical record |
| `sprint_3e/before/` + `after/` | 6 | 0.82 MB | `MARKET_DETAIL_INSIGHTS_DESIGN.md` | Historical record (duplicates 3F) |
| `sprint_3f/` | 5 | 0.82 MB | `MARKET_DETAIL_INSIGHTS_DESIGN.md` | Historical record |
| `sprint_3i/` | 7 | 2.36 MB | `MARKET_DETAIL_INSIGHTS_DESIGN.md` | **Active reference** (latest trust vocabulary) |
| `sprint_3j/` | 4 | 0.82 MB | `MARKET_DETAIL_INSIGHTS_DESIGN.md` | **Active reference** (insights gating) |
| `sprint_3k/` | 2 | 0.55 MB | **Nowhere** | One-time validation |
| `sprint_3l/` | 2 | 0.44 MB | **Nowhere** | One-time validation |
| `sprint_3m_c/` | 4 | 0.87 MB | `MARKET_TRUST_REMEDIATION_PLAN.md` | **Active reference** (transparency sheets) |
| `sprint_3n_a2/` | 5 | 1.52 MB | `NON_BLINDBOX_MARKET_FORENSICS.md` only (untracked) | Historical record |
| `sprint_3c/` | 0 | 0 | — | Empty folder |

**Tracked in git:** 25 PNG (sprint_2_4f, 3i, 3j, 3k, 3l, 3m_c).  
**Untracked:** sprint_3e, 3f, 3n_a2 (16 PNG).

### 1.6 Temporary validation artifacts (`tools/market_intel/`)

| Pattern | Count | Size | Classification |
|---------|------:|-----:|----------------|
| `debug_*.xml`, `_sprint_*_ui*.xml` | 11 | ~80 KB | **Delete candidate** |
| `parse_*.py`, `debug_*.py`, `scan_cards.py`, `list_cards.py`, `dump_*.py` | 15 | ~22 KB | **Delete candidate** (one-off UI dumps) |
| `capture_sprint_*_device_screenshots.py` | 12 | ~40 KB | **Keep** (regen screenshots) or archive if screenshots deleted |
| `_sprint_3nc_*.mjs`, `_sprint_3nd_*.mjs`, `_pipeline_forensics_*.mjs` | 5 | ~15 KB | **Archive** (investigation scripts) |
| `*.json` reports (`snapshot_validation_report.json`, `catalog_coverage_report.json`, etc.) | 8 | ~500 KB | **Generated artifact** — regen or gitignore |
| `market_metadata.json` | 1 | small | **Active reference** — pipeline input |
| `market_snapshots_dev.seed.json` | 1 | small | **Active reference** — dev seeder |

---

## 2. Screenshot review

### 2.1 One-time validation only (delete candidates)

| Folder | Reason |
|--------|--------|
| `sprint_3e/before/` + `after/` | Before/after for 3E; same surfaces covered by `sprint_3f` + `sprint_3i` |
| `sprint_3f/` | Purchase-context deltas; vocabulary finalized in 3I — redundant with 3i dark mode + tier shots |
| `sprint_3k/` | Collection estimates on/off; not linked from any committed doc |
| `sprint_3l/` | By-series estimates; not linked from any committed doc |
| `sprint_3n_a2/` | Forensics-only (untracked audit); value captured in markdown tables |
| `sprint_3c/` | Empty directory |

### 2.2 Duplicate screenshots

| Duplicate theme | Keep | Remove |
|-----------------|------|--------|
| Market Insights tier A/B/dark | `sprint_3i/` (most complete) | `sprint_3e/*`, much of `sprint_3f/` |
| Series estimate / tier B detail | `sprint_3m_c/` (info sheets) + `sprint_3i/4_market_detail_tier_b.png` | `sprint_3e/*series_estimate*` |
| Discover accordion | `sprint_3i/1_discover_tier_a.png`, `2_discover_tier_b.png` | `sprint_2_4f/` if refactor doc archived |

### 2.3 Referenced nowhere (committed)

| Folder | Status |
|--------|--------|
| `sprint_3k/` | **Delete candidate** |
| `sprint_3l/` | **Delete candidate** |

### 2.4 Recommended screenshot retention (KEEP)

| Folder | Why keep |
|--------|----------|
| `sprint_3i/` | Latest trust vocabulary reference set |
| `sprint_3j/` | Market Insights gating evidence |
| `sprint_3m_c/` | Valuation transparency / info sheets |
| `sprint_2_4f/` | **Archive** with `MARKET_SNAPSHOT_SURFACE_REFACTOR.md` unless deleted together |

**Estimated screenshot deletion:** 23 PNG, **~7.5 MB** (if 3e, 3f, 3k, 3l, 3n_a2, 2_4f removed).

---

## 3. Documentation review — superseded assumptions

| Document | Obsolete assumption | Replaced by | Recommendation |
|----------|---------------------|-------------|----------------|
| `MARKET_PIPELINE_ALIGNMENT_PLAN.md` | Export-first pipeline; daily GHA export; `blindbox-catalog/data` as hub | `CATALOG_MARKET_ARCHITECTURE_REVIEW.md`, `SPRINT_3N_FB_IMPLEMENTATION.md` | **Archive** |
| `tools/catalog/CATALOG_EXPORT_AUTOMATION_PLAN.md` | Daily export, drift across 3 copies, seed refresh Phase 5 | 3N-FA.1 + 3N-FB (Firestore direct) | **Archive** — keep export script spec as **historical** only |
| `MARKET_SNAPSHOT_PIPELINE_FORENSICS.md` | Pipeline defaults to `tools/seed`; export not wired | 3N-FB `--catalog-source firestore` default | **Archive** — findings still useful context |
| `PRODUCTION_READINESS_AUDIT.md` | Pipeline catalog = seed | 3N-FB | **Archive** or add 1-line superseded banner |
| `MARKET_COVERAGE_GAP_AUDIT.md` | Seed-based pipeline path | Firestore loader | **Archive** |
| `NON_BLINDBOX_*` audits (4) | Pre–3N-E vocabulary / seed counts | Shipped 3N-E + Firestore catalog | **Archive** together |
| `NON_BLINDBOX_TIER_B_VOCABULARY_*` | Planning docs | `SPRINT_3N_E_IMPLEMENTATION.md` | **Archive** |
| `METADATA_AUTOGEN_DESIGN.md` | Inputs = `tools/seed` | Should read Firestore / `CATALOG_DATA_DIR` | **Keep** — add superseded note on input path when autogen is built |
| `FIRESTORE_PERSISTENCE_DESIGN.md` | “Production write tool not started” | `push_market_snapshots.mjs` shipped | **Keep** — update status section or archive Part 1 |
| `MARKET_TRUST_REMEDIATION_PLAN.md` | Sprint 3I–3L task list | Mostly implemented | **Archive** |
| `docs/TECH_DEBT.md` § Scheduler | Implies GHA/scheduler as near-term | Manual runs until Insights + coverage SLO | **Keep** — trim scheduler urgency |

**Do not delete** `CATALOG_MARKET_ARCHITECTURE_REVIEW.md`, `SPRINT_3N_FB_IMPLEMENTATION.md`, `SOLD_LISTING_DATA_SOURCE.md`, `MATCHING_DESIGN.md`, or `docs/architecture/MARKET_INTELLIGENCE_EVOLUTION.md`.

---

## 4. Flutter bundle impact

### 4.1 `pubspec.yaml` asset declarations

```yaml
flutter:
  assets:
    - assets/images/app_icon.png
    - assets/market/fake_market_browse_items.json
    - assets/catalog/figures/
    - assets/catalog/series/
    - tools/seed/          # ← only tools/ path bundled
```

**Not declared:** `tools/market_intel/`, `docs/`, `screenshots/`, `tools/catalog/`.

### 4.2 Evidence — release APK contents

Built: `flutter build apk --release` (2026-06-16).

```text
jar tf app-release.apk | findstr tools

assets/flutter_assets/tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md
assets/flutter_assets/tools/seed/brands.json
assets/flutter_assets/tools/seed/figures.json
assets/flutter_assets/tools/seed/ips.json
assets/flutter_assets/tools/seed/series.json
```

```text
jar tf app-release.apk | findstr market_intel   → 0 matches
jar tf app-release.apk | findstr screenshots    → 0 matches (under tools/)
jar tf app-release.apk | findstr docs/          → 0 matches
```

### 4.3 Conclusions

| Path | In Android APK/AAB? | In iOS IPA? |
|------|---------------------|-------------|
| `tools/market_intel/**` | **No** | **No** (same `pubspec` assets) |
| `tools/market_intel/screenshots/**` | **No** | **No** |
| `docs/**` | **No** | **No** |
| `tools/seed/*.json` | **Yes** | **Yes** |
| `assets/play_store/**` | **No** (not in pubspec; store listing only) |

**Deleting market intel screenshots and docs does not reduce app binary size.**  
**Only `tools/seed/` affects bundle weight** (~0.4 MB JSON in APK from seed; separate from `assets/catalog/` images).

---

## 5. Cleanup plan

### 5.1 KEEP (do not remove)

| Category | Items | Count (approx.) | Risk |
|----------|-------|----------------:|------|
| Pipeline code | `*.mjs` except `_sprint_*` forensics | 37 | — |
| Pipeline config | `market_metadata.json`, `market_snapshots_dev.seed.json`, `fixtures/` | 4 | — |
| Active design | `MATCHING_DESIGN.md`, `SOLD_LISTING_DATA_SOURCE.md`, `SEARCH_TERM_DERIVATION_DESIGN.md`, `QUERY_VOLUME_OPTIMIZATION.md`, `DEV_VALIDATION.md`, `MARKET_DETAIL_INSIGHTS_DESIGN.md` | 8 | — |
| Current architecture | `CATALOG_MARKET_ARCHITECTURE_REVIEW.md`, `SPRINT_3N_FB_IMPLEMENTATION.md`, `SPRINT_3N_E_IMPLEMENTATION.md` | 3 | — |
| Docs | `docs/architecture/MARKET_INTELLIGENCE_EVOLUTION.md`, `docs/TECH_DEBT.md`, `docs/COLLECTIBLE_MARKET_INTELLIGENCE.md` | 3 | — |
| Regen tools | `compute_snapshots.mjs`, `push_market_snapshots.mjs`, `catalog_coverage_audit.mjs`, `snapshot_validation_audit.mjs`, `debug_ebay_live_probe.mjs` | 5+ | — |
| Screenshot evidence (minimal) | `sprint_3i/`, `sprint_3j/`, `sprint_3m_c/` | 15 PNG | — |
| Catalog loader | `tools/catalog/*` (code + tests) | 7 | — |

### 5.2 ARCHIVE → `tools/market_intel/archive/sprint_3n/`

Move as a batch; preserve git history for tracked files via `git mv`.

| Category | Items | Count | Disk |
|----------|-------|------:|-----:|
| Investigation audits | `MARKET_*_FORENSICS.md`, `NON_BLINDBOX_*.md`, `MARKET_COVERAGE_GAP_AUDIT.md`, `MARKET_PIPELINE_ALIGNMENT_PLAN.md` | 8 | ~200 KB |
| Superseded plans | `CATALOG_EXPORT_AUTOMATION_PLAN.md` (from `tools/catalog/`), vocabulary plan/review | 3 | ~100 KB |
| Completed sprint audits | `MARKET_TRUST_*`, `VALUATION_TRANSPARENCY_AUDIT.md`, `PRODUCTION_READINESS_AUDIT.md`, `FIRESTORE_E2E_VALIDATION_REPORT.md` | 5 | ~150 KB |
| Forensics scripts | `_sprint_3nc_*.mjs`, `_sprint_3nd_*.mjs`, `_pipeline_forensics_*.mjs`, `_coverage_gap_*.mjs` | 5 | ~20 KB |
| Old screenshots | `sprint_2_4f/`, `sprint_3e/`, `sprint_3f/`, `sprint_3n_a2/` | 22 PNG | ~7 MB |
| Surface refactor doc | `MARKET_SNAPSHOT_SURFACE_REFACTOR.md` | 1 | small |

**Archive subtotal:** ~35 files, **~7.5 MB**, **low risk**.

Add `tools/market_intel/archive/README.md` listing superseded-by pointers.

### 5.3 DELETE (safe — untracked or regenerable)

| Category | Items | Count | Disk | Risk |
|----------|-------|------:|-----:|------|
| UI dump XML | `debug_*.xml`, `_sprint_*_ui*.xml` | 11 | 80 KB | **None** — untracked |
| One-off parse/debug Python | `parse_*.py`, `debug_discover_*.py`, `debug_feed_ui.py`, `scan_cards.py`, `list_cards.py`, `dump_*.py`, `debug_sprint_3k_collection.py` | 14 | 22 KB | **None** — untracked |
| Empty folder | `screenshots/sprint_3c/` | 0 | 0 | **None** |
| Orphan screenshots | `sprint_3k/`, `sprint_3l/` (if not archived) | 4 PNG | 1.0 MB | **Low** — unreferenced |
| Generated JSON (optional) | `snapshot_validation_report.json`, `catalog_coverage_report.json`, `production_readiness_audit.json`, `matcher_generalization_simulation.json`, `_coverage_gap_counts.json`, `_sprint_3n_a2_forensics.json` | 6 | ~500 KB | **Low** — regen from scripts |

**Delete subtotal:** ~35 files, **~1.6 MB** (+ **7 MB** if screenshots deleted instead of archived).

### 5.4 Do not delete yet

| Item | Why |
|------|-----|
| `capture_sprint_*_device_screenshots.py` | Regenerate KEEP screenshot sets after UI changes |
| `SNAPSHOT_VALIDATION_REPORT.md` / `.json` | Active CI reference until regen policy defined |
| `CATALOG_COVERAGE_REPORT.md` | Linked from `docs/TECH_DEBT.md` |
| `tools/seed/` | **App bundle dependency** — separate hygiene sprint |

### 5.5 Totals (recommended execution)

| Action | Files | Disk recovered | Risk |
|--------|------:|---------------:|------|
| **DELETE** (temp only) | ~25 | ~0.6 MB | None |
| **ARCHIVE** | ~35 | ~7.5 MB (out of active tree) | Low |
| **DELETE** screenshots (after archive) | 0 if archived; +22 if skip archive | 0–7 MB | Low |
| **Combined** | **~55–60** | **~8–10 MB** | **Low** |

### 5.6 Suggested execution order (Sprint 3N-FD)

1. Add `tools/market_intel/archive/sprint_3n/README.md` with superseded-by map.  
2. `git mv` tracked obsolete docs + `sprint_2_4f` screenshots to archive.  
3. Delete untracked XML/Python temp files (never committed).  
4. Delete untracked duplicate screenshot folders (`sprint_3e`, `sprint_3f`, `sprint_3n_a2`) **or** move to archive first.  
5. Add `.gitignore` entries: `tools/market_intel/debug_*.xml`, `tools/market_intel/*_forensics.json`, optional `snapshot_validation_report.json`.  
6. One-line banner at top of archived docs: `> Superseded by CATALOG_MARKET_ARCHITECTURE_REVIEW.md (2026-06-16).`  
7. Update `MARKET_DETAIL_INSIGHTS_DESIGN.md` screenshot paths to point only at `sprint_3i/`, `3j/`, `3m_c/`.

---

## 6. Post-cleanup active doc set (target)

After hygiene, a new contributor should need only:

```text
tools/market_intel/
  MATCHING_DESIGN.md
  SOLD_LISTING_DATA_SOURCE.md
  SEARCH_TERM_DERIVATION_DESIGN.md
  QUERY_VOLUME_OPTIMIZATION.md
  DEV_VALIDATION.md
  MARKET_DETAIL_INSIGHTS_DESIGN.md
  CATALOG_MARKET_ARCHITECTURE_REVIEW.md
  SPRINT_3N_FB_IMPLEMENTATION.md
  screenshots/sprint_3i|3j|3m_c/
  archive/sprint_3n/   ← everything else
docs/
  architecture/MARKET_INTELLIGENCE_EVOLUTION.md
  TECH_DEBT.md
tools/catalog/
  (code only; plan archived)
```

---

## 7. Risk register

| Risk | Mitigation |
|------|------------|
| Lose audit trail | **Archive**, don't delete investigation markdown |
| Broken doc links | README in archive + superseded banners |
| Regenerate screenshots | Keep `capture_sprint_3i/3j/3m_c` scripts |
| Accidental seed deletion | Out of scope — seed is app bundle, not market_intel hygiene |

**No production code changes required for this cleanup.**
