# Technical debt

Tracked items that are not release blockers. Severity and priority are conservative — only active, reachable issues.

## Minor Analyzer Warnings

Current status:

- `test/catalog_image_display_test.dart` — unused local variable
- `test/market_search_anr_repro_test.dart` — unused import
- `test/market_tab_reselect_navigation_test.dart` — unused private element

**Severity:** GREEN

**Impact:** None

**Priority:** Cleanup when convenient.

---

## Future Performance Opportunities

These are **not** current bugs. The Collection rendering audit (2026) confirmed the app is performant at today’s catalog (~343 series / ~2,435 figures) and typical shelf sizes. Entries below are documentation-only placeholders for when scale or profiling demands action.

**Principle:** Do not implement preemptively. See [Performance Characteristics](ARCHITECTURE_NOTES.md#performance-characteristics) in `ARCHITECTURE_NOTES.md`.

### Reuse grouped shelf sections

**Description:** [`groupShelfSeriesByUniverse`](../lib/features/collection/presentation/shelf_series_feed.dart) runs in both [`sortShelfSeriesForDisplay`](../lib/features/collection/presentation/collection_shelf_browse.dart) (for alphabetical, figure-count, and completion sorts) and again in [`buildShelfFeedItems`](../lib/features/collection/presentation/shelf_series_feed.dart) per bucket — duplicate O(n) grouping on the same series list within one `build()`.

**Expected benefit:** Fewer allocations and passes over the shelf when sort modes regroup by IP/universe; marginal at current sizes.

**Current priority:** Low

**Trigger for revisiting:** Collection sizes consistently exceed **~1,000 series**, or profiling shows grouping as a hot spot during filter/sort interactions.

---

### Search indexing

**Description:** Search V2 ([`CatalogSearchService`](../lib/features/catalog/search/catalog_search_service.dart)) linearly scans in-memory catalog figures for token matches. No inverted index or FTS layer.

**Expected benefit:** Sub-linear or cached lookups for very large catalogs; reduced CPU on every debounced shelf search and catalog browse query.

**Current priority:** Low

**Trigger for revisiting:** Catalog grows beyond approximately **10k–20k figures**, or profiling identifies search latency as user-visible (typing lag, frame drops after debounce).

---

### Memoize summary aggregates

**Status (2026-06):** Collection Insights dashboard inputs are memoized via [`collectionInsightsDashboardInputsProvider`](../lib/features/collection/application/collection_insights_dashboard_providers.dart); expand/collapse state is isolated in [`CollectionInsightsDashboardHost`](../lib/features/collection/widgets/collection_insights_dashboard_host.dart) so toggling the dashboard does not rebuild the shelf pipeline.

**Remaining (low priority):** [`countShelfCompletionTiers`](../lib/features/collection/domain/series_completion_resolution.dart) and other shelf-wide aggregates inside [`CollectionScreen.build`](../lib/features/collection/collection_screen.dart) still recompute when unrelated shelf UI state changes.

**Trigger for revisiting:** Profiling shows summary calculations as a **measurable** fraction of frame time, or shelf sizes grow large enough that duplicate scans matter.

---

### Cache editorial interpretation

**Description:** [`shelfEmotionalProfileProvider`](../lib/features/collection/application/shelf_emotional_providers.dart), [`shelfRelationshipInsightsProvider`](../lib/features/collection/application/shelf_emotional_providers.dart), and related editorial providers re-run [`interpretShelf`](../lib/features/collection/application/shelf_emotional_interpreter.dart) / relationship analysis on every dependent rebuild.

**Expected benefit:** Stable derived copy when snapshot unchanged; less CPU on filter/sort-only rebuilds.

**Current priority:** Low

**Trigger for revisiting:** Interpretation logic becomes **significantly more complex**, rebuild frequency increases (e.g. high-frequency provider churn), or traces show editorial work as hot.

---

### Feed pipeline optimization

**Description:** The full browse pipeline in [`CollectionScreen.build`](../lib/features/collection/collection_screen.dart) — brand filter → IP filter → search → partition → sort → `buildShelfFeedItems` — executes on every rebuild that touches dependencies, not only when shelf data changes. **Dashboard expand/collapse is excluded** (host owns that state). Feed item lists are materialized eagerly even though `SliverList.builder` lazily builds widgets.

**Expected benefit:** Fewer passes and allocations when toggling UI prefs; optional `select`/memoization on snapshot + filter/sort keys.

**Current priority:** Low

**Trigger for revisiting:** **Measured rebuild time** becomes user-visible (jank, dropped frames) in DevTools timeline or production-adjacent profiling — not before.
