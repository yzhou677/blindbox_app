# Market Intelligence — Metadata Auto-Generation Design

> **Sprint 2 Step 3 deliverable (rev 2 — design review).** Design only — **no implementation**.
>
> Parent spec: [`MATCHING_DESIGN.md`](./MATCHING_DESIGN.md)  
> Prerequisite context: [`MATCHER_DESIGN_REVIEW.md`](./MATCHER_DESIGN_REVIEW.md) — Maintenance and Automation Principles  
> Related debt: [`docs/TECH_DEBT.md`](../../docs/TECH_DEBT.md), [`QUERY_VOLUME_OPTIMIZATION.md`](./QUERY_VOLUME_OPTIMIZATION.md)

---

## 1. Problem and Goals

### Current state

Every figure entry in [`market_metadata.json`](./market_metadata.json) is hand-authored. The catalog contains **1,144 figures** across **109 series** and **6 brands** (785 Pop Mart figures today), and it grows continuously. Manual authoring does not scale for a single maintainer.

```
Catalog Figure
  → Human manually creates metadata entry
  → market_metadata.json
  → Matcher + snapshot pipeline
```

### Target state

Auto-generate **~90–95%** of metadata entries from catalog seed data. Human edits are limited to known exceptions in a small overrides file.

```
Catalog Figure
  → Generator derives baseline metadata
  → Small optional human review (exceptions only)
  → market_metadata.json
  → Matcher + snapshot pipeline
```

**Success criteria:** Adding a new catalog figure should produce usable baseline matching and search behavior without manual metadata work, except for genuine marketplace naming gaps (spelling drift, CJK aliases, community nicknames, verified false positives).

---

## 2. Architecture — Three-Layer Design

```
Catalog seed JSON
       ↓
generate_market_metadata.mjs          (future tool)
       ↓
generated_market_metadata.json        Layer A — committed, never hand-edited
       +
market_metadata_overrides.json        Layer B — small, hand-authored exceptions
       ↓  merge step
merge_market_metadata.mjs             (future tool; or pre-pipeline hook)
       ↓
market_metadata.json                  Layer C — consumed by matcher + snapshot pipeline
```

### Layer responsibilities

| Layer | File | Who edits | Purpose |
|-------|------|-----------|---------|
| **A** | `generated_market_metadata.json` | Generator only | Full-catalog baseline; regenerated on every catalog change |
| **B** | `market_metadata_overrides.json` | Maintainer | Sparse exceptions; reviewed in PRs |
| **C** | `market_metadata.json` | Merge output only | Pipeline input; same path and shape as today |

### Why three files, not one?

A single file mixing generated and manual fields is hard to diff, conflicts on regeneration, and couples two different editing workflows. Two source files (generated + overrides) with a merge step keeps overrides small and reviewable — appropriate for a single-engineer project.

**Rejected alternative — single file with `_generated` flags:** Easy to accidentally overwrite generated values; unclear what the generator preserves on re-run.

**Rejected alternative — hand-edit `market_metadata.json` forever:** Current bootstrap only; does not scale past ~1,144 figures.

### Scale review (1,144 → 5,000+ figures)

| Question | Assessment |
|----------|------------|
| **Sufficient for 1,144 figures?** | **Yes.** One generated JSON (~1,144 rows × ~8 fields) is trivial for Node merge and git. Overrides stay sparse (<5% target ≈ 60–120 rows). |
| **Sufficient for 5,000+ figures?** | **Yes, with operational guardrails.** Merge remains O(n). Layer A grows linearly (~2–4 MB JSON) — still fine for a single maintainer. Watch: PR diff noise on full regen, `aliasHints` review backlog, and snapshot query volume (~2.3 queries/figure today → ~11,500 queries at 5k — see [`QUERY_VOLUME_OPTIMIZATION.md`](./QUERY_VOLUME_OPTIMIZATION.md)). |
| **Additional layer needed?** | **No fourth persistence layer.** Optional **logical** layers only: catalog `ip`/`series` aliases (not metadata files) and a future **series** block in overrides (already mirrored in current `market_metadata.json`). |
| **Any layer unnecessary?** | **Layer C as a committed file is optional** — merge can write directly to the path the pipeline reads, or gitignore Layer C and generate in CI. **Layer A is necessary** (regen-safe bulk). **Layer B is necessary** (human exceptions). Do **not** collapse A+B into one file. |

**Tradeoffs:**

| Approach | Pros | Cons |
|----------|------|------|
| Commit Layer A + C | Reproducible pipeline input without running generator in CI | Large diffs on catalog-wide regen |
| Gitignore Layer C; commit A + B only | Small PRs; source of truth is explicit | CI / pre-pipeline must run merge |
| Runtime derive `searchTerms` (no store in A) | Smaller files; no search-term drift | Duplicates logic in generator + pipeline; harder to override per figure |

**Recommendation:** Keep three-layer model. Commit Layer A (generated) and Layer B (overrides). Treat Layer C as **generated artifact** (committed with `_comment` until CI merge is wired, then prefer gitignore).

### Data flow diagram

```
tools/seed/figures.json
tools/seed/series.json   ──┐
tools/seed/ips.json        ├──  generate_market_metadata.mjs  ──→  generated_market_metadata.json
tools/seed/brands.json   ──┘

market_metadata_overrides.json  ──┐
generated_market_metadata.json  ├──  merge_market_metadata.mjs  ──→  market_metadata.json
                                  │
                                  └── consumed by:
                                        _catalog_bundle.mjs
                                        _search_term_derivation.mjs (override path)
                                        _catalog_matcher.mjs
                                        compute_snapshots.mjs
```

---

## 3. Metadata Ownership Matrix

Based on fields available in `tools/seed/{figures,series,ips,brands}.json` and behavior already implemented in [`_search_term_derivation.mjs`](./_search_term_derivation.mjs).

### Classification key

| Class | Meaning |
|-------|---------|
| **Auto** | Generator produces final value; overrides rarely needed |
| **Manual** | Overrides only; generator emits empty/default |
| **Hybrid** | Generator baseline + human refinement via overrides |

### Figure-level fields

| Field | Auto | Manual | Hybrid | Owner / source | Move out of metadata? |
|-------|:----:|:------:|:------:|----------------|----------------------|
| Metadata key (`figure.id`) | ✓ | | | Catalog | **Yes** — key is catalog identity, not metadata content |
| `searchTerms` | ✓ | | ✓ | Generator via `_search_term_derivation.mjs`; override when unscopable | **Partial** — derivation stays in code; stored terms are pipeline cache + override surface. Do not duplicate in Firestore catalog. |
| `excludeTerms` (per-figure) | | | ✓ | Generator emits `[]`; global normalizer owns universal noise; overrides add collision terms | **No** — marketplace false-positive patterns are pipeline knowledge |
| `marketAliases` | | | ✓ | Generator copies `figure.aliases[]` when present; else `[]`; overrides for drift/CJK/nicknames | **Prefer catalog** for IP/series-wide aliases (`ips.json`, `series.json`). Figure-only gaps stay here. |
| `aliasHints` | ✓ | | | Generator only (Layer A) | **N/A** — not metadata for runtime; review queue only |
| `matchThreshold` | | | ✓ | Generator heuristic (§5); override when production proves otherwise | **No** — per-figure acceptance gate is pipeline tuning |
| `disabled` | | ✓ | | Maintainer | **No** |
| `notes` | | ✓ | | Maintainer | **No** |

### Fields that should leave metadata entirely (catalog-owned)

| Information | Correct home | Wrong home |
|-------------|--------------|------------|
| Brand spellings (`POP MART` / `POPMART`) | `brands.json` `aliases` | Per-figure `marketAliases` |
| IP marketplace names (`Labubu`, `Smiski`) | `ips.json` `aliases` | Per-figure overrides repeated N times |
| Series abbreviations (`BIE`, `Big Energy`) | `series.json` `aliases` | Per-figure `searchTerms` widening |
| Figure `displayName`, `isSecret`, series membership | `figures.json` | Metadata duplication |
| Universal listing noise (`custom`, `lot`, `replica`) | Normalizer global list | Per-figure `excludeTerms` unless collision-specific |

### Series- and brand-level metadata (see §10)

Current `market_metadata.json` already has a `series` block. Brand-level block is **not** in schema today — brand behavior is catalog + normalizer only.

### Search term formula

Reuse the same derivation logic as runtime search planning (already in `_search_term_derivation.mjs` / `extractSeriesDistinctive`):

| Component | Source |
|-----------|--------|
| Brand | `POP MART` and `POPMART` from `brands.json` (`pop_mart`) |
| IP anchor | First IP alias, else `ip.displayName` (e.g. `Labubu` for `the_monsters`) |
| Series distinctive | `extractSeriesDistinctive(series, ip)` — strips boilerplate (`Blind Box`, `Vinyl Plush`, IP prefix, etc.) |
| Figure name | `figure.displayName` |

**Example** — `the_monsters_big_into_energy_vinyl_plush_pendant_luck`:

| Term | Value |
|------|-------|
| Term 1 | `POP MART Labubu Big into Energy Luck` |
| Term 2 | `POPMART Labubu Big into Energy Luck` |

Marketplace sellers often write **Lucky** not **Luck**. That gap is handled by the **alias layer** (`marketAliases`), not by broadening `searchTerms`. Search terms retrieve candidate listings; matcher aliases confirm the figure.

### Minimal generated entry (no overrides)

```json
{
  "the_monsters_big_into_energy_vinyl_plush_pendant_luck": {
    "searchTerms": [
      "POP MART Labubu Big into Energy Luck",
      "POPMART Labubu Big into Energy Luck"
    ],
    "marketAliases": [],
    "excludeTerms": [],
    "matchThreshold": null,
    "aliasHints": ["Lucky"],
    "disabled": false,
    "notes": ""
  }
}
```

`aliasHints` is stripped by the merge step before writing Layer C (or ignored by the mapper). It exists only in Layer A for maintainer review.

### `aliasHints` — strict policy (design review)

**Should `aliasHints` ever participate in matcher execution?**

**No. Never.**

| Risk | Why hints must not run in matcher |
|------|-----------------------------------|
| False positives | Speculative `-y` rules (`Lamp` → `Lampy`) would accept wrong listings |
| Typo propagation | Unreviewed strings become permanent matcher signal |
| Matcher contamination | Hints bypass the human approval bar for `marketAliases` |
| Audit confusion | Indistinguishable from approved aliases in logs |

**Policy:**

1. `aliasHints` exists **only** in `generated_market_metadata.json` (Layer A).
2. Merge **strips** `aliasHints` — Layer C and `_catalog_matcher.mjs` never read the field.
3. Mapper / merge tests **assert** absence of `aliasHints` in output.
4. Promotion path: maintainer copies approved hint → `market_metadata_overrides.json` `marketAliases` (or catalog `figure.aliases`).
5. Optional: `generate_market_metadata.mjs --report-hints` prints a summary count for review; no runtime effect.

**Review workflow:** After catalog add/regen, scan new `aliasHints` rows (or report). Promote or dismiss. Target: <1 min per figure when hint is correct; zero action when empty.

---

## 4. Alias Generation Strategy

### What can be derived safely (auto-generated)

| Rule | Example | Action |
|------|---------|--------|
| Catalog `figure.aliases[]` | When populated in seed | Copy into `marketAliases` in generated entry |
| Conservative `-y` suffix hint | `Luck` → suggest `Lucky` | Add to `aliasHints` only — **not** auto-promoted to `marketAliases` |
| `-y` rule constraint | `displayName` ≤ 6 chars, ends in single consonant after vowel | Conservative; avoids `Lamp` → `Lampy` |

**`-y` suffix rule (hint only):**

```
IF displayName length <= 6
AND displayName matches [Vowel][Consonant] ending (single final consonant)
THEN aliasHints += displayName + "y"
```

Only `Luck → Lucky` is confirmed in production today. The generator surfaces hints; the maintainer promotes verified hints to `market_metadata_overrides.json`.

### What requires manual review (overrides file)

| Pattern | Example | Override field |
|---------|---------|----------------|
| CJK / localized names | `ラッキー`, `幸运` | `marketAliases` |
| Marketplace abbreviations | `BIE` for Big Into Energy | `marketAliases` or `series.aliases` in catalog |
| Community nicknames | Not derivable from `displayName` | `marketAliases` |
| Cross-series name collisions | `Angel` in unrelated IPs | `excludeTerms` and/or `matchThreshold` |
| All-caps short names | `SISI`, `HEHE`, `BABA` | Usually **no** spurious aliases — match well without extras |

### Catalog-first preference

Before adding a per-figure `marketAliases` entry, ask:

1. **IP-wide?** → Add to `ips.json` `aliases` (e.g. `Labubu` for The Monsters).
2. **Series-wide?** → Add to `series.json` `aliases` (e.g. `Big Energy`).
3. **Figure-only?** → `market_metadata_overrides.json`.

Enriching catalog aliases compounds across all figures in that IP/series and keeps overrides sparse.

---

## 5. Threshold Heuristic

Generator sets `matchThreshold: 0.80` when **both** are true:

1. `displayName` is a single English word ≤ 8 characters.
2. Word is in a fixed ambiguity list (explicit, not auto-detected):

```
luck, hope, love, star, magic, angel, wish, dream, joy, charm, faith, id
```

All other figures: `matchThreshold: null` (inherits global default **0.75** from [`_catalog_matcher.mjs`](./_catalog_matcher.mjs)).

Overrides in Layer B can raise or lower per figure when production data contradicts the heuristic.

**Rationale:** Short single-token figure names are structurally ambiguous on eBay. A fixed list is reviewable and predictable — preferable to ML or open-ended detection for a solo maintainer.

---

## 6. Exceptions and Override Strategy

Situations where auto-generation is insufficient — all live in `market_metadata_overrides.json`.

| Case | Example | Override approach |
|------|---------|-------------------|
| Catalog name ≠ marketplace name | `Luck` → `Lucky` | `marketAliases` in overrides |
| CJK / localized names | `幸运`, `ラッキー` | `marketAliases` in overrides |
| Community nicknames | `BIE Lucky` | `marketAliases` in overrides |
| Per-figure false-positive exclusions | `Angel` + Sanrio brand collision | `excludeTerms` in overrides |
| Raised threshold beyond heuristic | Unusual ambiguous name | `matchThreshold` in overrides |
| Figure that cannot be safely searched | `Secret` in secret-heavy series | `searchTerms: []` + `notes` in overrides |
| Disabled figures | Data quality investigation | `disabled: true` in overrides |

### Metadata key strategy (`figure.id`)

Replacing legacy slugs (`lucky_big_into_energy_popmart`) and [`METADATA_KEY_TO_CATALOG_FIGURE_ID`](./_catalog_bundle.mjs).

| Topic | Assessment |
|-------|------------|
| **Advantages** | One id everywhere (catalog, Firestore snapshots, metadata); no parallel slug vocabulary; overrides keyed like `market_snapshots` docs; removes join bugs |
| **Migration risks** | Existing hand-authored keys; dev seeds / docs referencing old slugs; `resolveCatalogFigureId` accepts three shapes today |
| **Long-term maintainability** | **High** — catalog `figure.id` is stable canonical identity |

**Compatibility layer (recommended for one migration sprint):**

1. Generator and merge emit **only** `figure.id` keys in Layer C.
2. Keep `resolveCatalogFigureId` + `METADATA_KEY_TO_CATALOG_FIGURE_ID` **read-only** for one release; log deprecation warning on legacy key hit.
3. `merge_market_metadata.mjs --check` fails if overrides use unknown keys or legacy slugs not in map.
4. Remove compatibility map after overrides migration + diff test green.

Optional `catalogFigureId` inside each entry is **redundant** when key === id — omit from Layer C.

### Merge semantics (per-field rules)

**Key:** `figure.id` (catalog figureId). Layer A contains **one row per catalog figure**.

| Field | Merge rule | Rationale |
|-------|------------|-----------|
| `searchTerms` | **Replace** if override field present; else generated | `[]` in override means “do not search”. Append would blend unsafe queries. |
| `excludeTerms` | **Union (dedupe)** — `uniq(generated ∪ override)` | Overrides typically **add** collision terms. Full replace forces duplicating generated lists. |
| `marketAliases` | **Replace** if override field present; else generated | Maintainer owns full approved alias set. |
| `matchThreshold` | **Override wins** when field present in override | Omit field in override to inherit generated heuristic (preferred over JSON `null` — see Open Questions). |
| `disabled` | **Override wins** when present | `true` disables regardless of generated |
| `notes` | **Override wins** when non-empty | Generated default `""` |
| `aliasHints` | **Strip** — never in Layer C | Review-only |

**Series block** (`market_metadata.json` → `series`): same rules keyed by `series.id`.

**Edge cases:**

| Case | Behavior |
|------|----------|
| Override for deleted catalog figure | `merge --check` **warns** (stale override); optional `--prune` |
| Catalog figure missing from Layer A | **CI fail** — generator bug |
| Override-only row (no generated counterpart) | **CI fail** — overrides are not the bulk source |
| `disabled: true` | Pipeline skips; coverage report classifies DISABLED |

---

## 7. Future Workflow

```
Add figure to catalog (Firestore / seed JSON)
          ↓
node tools/market_intel/generate_market_metadata.mjs
          ↓
Regenerates generated_market_metadata.json (Layer A)
          ↓
Review aliasHints in generated output (< 1 min per new figure typically)
          ↓
Add any needed entries to market_metadata_overrides.json  ← only if exceptions apply
          ↓
node tools/market_intel/merge_market_metadata.mjs
  (or auto-run as pre-pipeline step)
          ↓
market_metadata.json updated → run snapshot pipeline
```

### Expected manual work per new catalog figure

| Scenario | Expected work |
|----------|----------------|
| No exceptions (multi-word name, aliased IP) | **Zero** — regenerate + merge only |
| Luck-style catalog/market naming gap | One `marketAliases` line in overrides (~30 s) |
| IP-specific CJK aliases | 1–3 entries per IP in overrides or `ip.aliases` (one-time) |
| False-positive exclusions | Per-figure `excludeTerms` after debug tool / live review |
| Unscopable figure | `searchTerms: []`, `disabled`, `notes` in overrides |

**Goal:** 90–95% of new figures require zero override edits.

### Pre-snapshot checklist (steady state)

1. `node tools/market_intel/generate_market_metadata.mjs`
2. `node tools/market_intel/merge_market_metadata.mjs`
3. Optional: `node tools/market_intel/catalog_coverage_audit.mjs`
4. `node tools/market_intel/compute_snapshots.mjs --dry-run` (spot-check new figures)

---

## 8. Migration from Current `market_metadata.json`

### Current state

[`market_metadata.json`](./market_metadata.json) contains:

- **1 figure entry:** `lucky_big_into_energy_popmart` (legacy key; maps to `the_monsters_big_into_energy_vinyl_plush_pendant_luck` via [`METADATA_KEY_TO_CATALOG_FIGURE_ID`](./_catalog_bundle.mjs))
- **1 series entry:** `big_into_energy_popmart`

Both are hand-authored, including stored `searchTerms`.

### Migration steps (implementation sprint — not Sprint 3)

| Step | Action |
|------|--------|
| **1** | Implement `generate_market_metadata.mjs` → run against full catalog → commit `generated_market_metadata.json` |
| **2** | Create `market_metadata_overrides.json` from current hand-authored exceptions (aliases, excludes, notes). **Do not** copy auto-derivable `searchTerms` — generator reproduces them |
| **3** | Implement `merge_market_metadata.mjs` |
| **4** | Validate merged output: Luck matching behavior unchanged (`debug_matcher.mjs`, existing matcher tests) |
| **5** | Switch metadata keys from legacy slugs to `figure.id`; remove `METADATA_KEY_TO_CATALOG_FIGURE_ID` once overrides use canonical ids |
| **6** | Treat `market_metadata.json` as generated artifact (gitignored **or** committed with `_comment: "DO NOT EDIT — run merge"` — team choice at implementation time) |

### Overrides seed for Luck (after migration)

```json
{
  "figures": {
    "the_monsters_big_into_energy_vinyl_plush_pendant_luck": {
      "marketAliases": ["lucky"],
      "notes": "Catalog displayName is 'Luck'; eBay sellers overwhelmingly write 'Lucky'."
    }
  }
}
```

`custom`, `lot`, `bootleg`, `replica` need **not** appear in overrides — they belong in the global normalizer (per ownership matrix). Override `excludeTerms` only for **collision-specific** terms (e.g. `sanrio` on an `Angel` figure).

Generator produces `searchTerms`; overrides supply only marketplace-specific gaps.

### Migration rollback

| Step | Rollback |
|------|----------|
| After generator commit | Revert Layer A commit; keep hand-authored `market_metadata.json` |
| After merge wired | Point pipeline at previous `market_metadata.json` git tag |
| After key migration | Restore `METADATA_KEY_TO_CATALOG_FIGURE_ID` map + legacy overrides file from tag |

Keep a **migration tag** (`metadata-autogen-v1-pre`) before first full-catalog regen. Diff test (`debug_matcher.mjs` + matcher fixtures) is the rollback gate.

### No data loss guarantee

- `marketAliases` and `excludeTerms` from the hand-authored file move verbatim to overrides.
- `searchTerms` are regenerated from catalog using the same formula as [`deriveSearchTerms`](./_search_term_derivation.mjs); diff test confirms parity for Luck.

---

## 9. Coverage Validation

The **90–95% auto-generated** target means **90–95% of catalog figures require no override row** (or no non-default override fields). It does **not** mean 90–95% have snapshots — snapshot coverage depends on eBay data and query volume.

### Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| **Override rate** | `figures_with_non_empty_override / catalog_figures` | ≤ 5–10% |
| **Generation completeness** | `catalog_figures in Layer A / catalog_figures` | 100% |
| **Hint backlog** | `figures with non-empty aliasHints` | Trend down after review sprints |
| **Stale overrides** | `override keys ∉ catalog` | 0 (warn → fail) |
| **Matcher coverage** | From [`catalog_coverage_audit.mjs`](./catalog_coverage_audit.mjs) | Maintain ≥99% MATCHABLE (current: 1,137/1,144) |
| **Snapshot coverage** | `figures with snapshot doc / eligible figures` | Track separately; fixture mode until Marketplace Insights |

### Commands (recommended)

| Command | Role |
|---------|------|
| `node tools/market_intel/generate_market_metadata.mjs` | Regen Layer A |
| `node tools/market_intel/merge_market_metadata.mjs --check` | Validate keys, stale overrides, strip hints |
| `node tools/market_intel/metadata_coverage_audit.mjs` (future) | Override rate, hint backlog, field histogram |
| `node tools/market_intel/catalog_coverage_audit.mjs` | Matcher/search-term structural risks (exists today) |
| `node tools/market_intel/coverage_report.mjs` (future) | Metadata + snapshot join per [`MATCHER_DESIGN_REVIEW.md`](./MATCHER_DESIGN_REVIEW.md) |

### CI policy (recommended)

| Check | Severity |
|-------|----------|
| Layer A missing catalog figure | **Fail** |
| Merge output differs from committed Layer C without regen | **Fail** (if Layer C committed) |
| Override key not in catalog | **Fail** (after migration grace period) |
| `aliasHints` present in Layer C | **Fail** |
| Override rate > 15% | **Warn** — drift from automation goal |
| Non-empty `aliasHints` count > 50 | **Warn** — review backlog |
| `NO_SEARCH_TERMS` figures (catalog audit) | **Warn** today; **Fail** before production snapshots |
| Matcher regression vs baseline | **Fail** |

### How we know generation quality is improving

1. **Override rate** decreases release-over-release for static catalog.
2. **catalog_coverage_audit** `NO_SEARCH_TERMS` and `ambiguousFigureName` counts decrease as catalog aliases enrich.
3. **Snapshot validation audit** false-positive / skip-reason mix improves on fixture + live samples.
4. **Hint promotion rate** — most hints dismissed or promoted within one sprint (process metric).

---

## 10. Future Metadata Layers

Figure-only metadata is **not** enough for all marketplace knowledge. Use a **catalog-first, layer-appropriate** model:

| Layer | Belongs here | Examples |
|-------|--------------|----------|
| **Brand** | `brands.json` aliases; normalizer brand tokens | `POPMART`, `Dreams`, `Rolife` seller spellings — **not** a metadata file today |
| **IP** | `ips.json` aliases | `Labubu` (The Monsters), `Smiski`, `Sonny Angel` community names |
| **Series** | `series.json` aliases + optional `market_metadata.json` `series` block | `BIE` / `Big Energy`; Smiski Series 2 distinctive fix; series-scoped `searchTerms` for series-level snapshots |
| **Figure** | Generated + overrides | `Luck`→`Lucky`, per-figure `excludeTerms`, `matchThreshold`, `disabled` |

### Recommendations by example

| Brand/IP | Series-level | Figure-level |
|----------|--------------|--------------|
| **Labubu / The Monsters** | Series aliases for seller abbreviations | Short names (`Luck`, `Hope`) — aliases + threshold |
| **Smiski** | **Critical** — empty `extractSeriesDistinctive` for Series 2 → fix `series.aliases` | Per-figure only if name collision across IPs |
| **Sonny Angel** | Generic distinctive (`Marine`, `Flower`) — enrich series alias to full marketplace phrase | `excludeTerms` if false positives confirmed |
| **Rolife** | Brand alias gap in catalog (per TECH_DEBT) — fix in `brands.json` / IP, not 500 figure overrides | — |

**Rule:** If an exception applies to **all figures in a series or IP**, fix catalog or series metadata block — never N per-figure overrides.

---

## Summary — Design Decisions

| Decision | Chosen approach | Rationale |
|----------|-----------------|-----------|
| Architecture | Three-layer: generated + overrides → merge → output | Scales to 5k+ figures; overrides stay reviewable |
| Metadata keys | `figure.id` + temporary legacy read map | Canonical identity; safe migration |
| `searchTerms` | Auto-generated in Layer A | Full-catalog coverage; aligns with query volume reality |
| `excludeTerms` merge | **Union** (not replace) | Overrides add collision terms without copying baselines |
| `matchThreshold` | Heuristic 0.80 for fixed ambiguity list; else null | Proactive guard; override when production contradicts |
| `aliasHints` | Layer A only; **never** in matcher | Human approval gate for aliases |
| Aliases | Catalog-first; overrides last resort | Smiski / Sonny Angel fixes at series/IP |
| Coverage target | ≤5–10% override rate | Measurable automation success |
| Implementation timing | Design complete; generator deferred | Matcher + pipeline already generalized |

---

## Design Review Findings

Critical review performed against 1,144-figure catalog, generalized matcher (99.4% MATCHABLE), and working snapshot pipeline. **No implementation was performed.**

### Part 1 — Architecture

- **1,144 figures:** Architecture is sufficient. Bulk in Layer A, exceptions in Layer B, merge is O(n).
- **5,000+ figures:** Still sufficient; monitor JSON regen diff size and eBay query volume (~2.3× figure count per full run).
- **No extra persistence layer** required. Catalog `ip`/`series` enrichment is a parallel concern, not a fourth JSON file.
- **Layer C optional as committed artifact** — prefer generating in CI once merge is stable.

### Part 2 — Metadata ownership

- Expanded matrix (§3) clarifies Auto / Manual / Hybrid per field.
- **Move out of metadata:** brand/IP/series identity, universal exclude noise, anything in catalog seed.
- **Stay in metadata:** per-figure marketplace drift, collision excludes, thresholds, operational disable.

### Part 3 — Alias safety

- **`aliasHints` must never participate in matcher execution** (§3, §4).
- Auto-promoting hints to `marketAliases` would reintroduce manual maintenance at scale with worse quality control.

### Part 4 — Key strategy

- **`figure.id` keys are correct** long-term.
- **Temporary compatibility layer required** — do not delete `METADATA_KEY_TO_CATALOG_FIGURE_ID` until overrides and dev seeds migrate.
- Redundant `catalogFigureId` field in entries should be dropped from Layer C.

### Part 5 — Future layers

- Figure-only metadata is insufficient for Smiski, Sonny Angel, Rolife-class catalog gaps (§10).
- **Series block** in metadata remains valid for series-scoped search (existing bootstrap).
- **Brand metadata file** not recommended — use `brands.json`.

### Part 6 — Merge semantics

- Original “replace all arrays” rule is **wrong for `excludeTerms`** — union merge recommended (§6).
- `searchTerms` and `marketAliases` remain **replace** semantics.
- Stale override detection and optional `--prune` are required operational tools.

### Part 7 — Coverage validation

- 90–95% target = **low override rate**, not snapshot completeness (§9).
- `metadata_coverage_audit.mjs` should be added alongside existing `catalog_coverage_audit.mjs`.
- CI fail/warn policy defined in §9.

### Part 8 — Technical debt interaction

| Debt item | After autogen |
|-----------|---------------|
| [`QUERY_VOLUME_OPTIMIZATION.md`](./QUERY_VOLUME_OPTIMIZATION.md) | **Harder short-term** — full-catalog autogen enables full-catalog queries (~2,300+). Reinforces need for query dedup before production scale. |
| Matcher coverage validation | **Simpler** — baseline metadata exists for every figure; audit focuses on matcher not missing rows. |
| Catalog metadata quality audit | **Partially simpler** — surfaces as `NO_SEARCH_TERMS` / empty distinctive; fix in catalog aliases, not 1,144 overrides. |
| Marketplace Insights integration | **Unchanged** — sold-listing source still blocked; autogen does not fix fetch. |
| Snapshot scheduler | **Unchanged** — still manual CLI. |

**New debt introduced:**

- Stale overrides for removed catalog figures
- `aliasHints` review backlog
- Layer A regen PR noise
- Generator / `_search_term_derivation.mjs` drift if not sharing one module
- False confidence from 100% metadata rows with poor marketplace aliases

### Part 9 — Previously missing topics

Now addressed: migration rollback (§8), generated file ownership (Layer A generator-only), CI validation (§9), stale override detection (§6), dead alias cleanup (see Recommended Changes). **Still thin:** metadata schema versioning — see Open Questions.

---

## Recommended Changes

Applied in this document revision:

1. **Adopt union merge for `excludeTerms`** — overrides add; do not replace.
2. **Enforce `aliasHints` strip** in merge with CI assertion on Layer C.
3. **Add temporary legacy key compatibility** during migration; remove after one sprint.
4. **Define override-rate metric** as the 90–95% automation KPI.
5. **Remove redundant global excludes** from per-figure override examples (`custom`, `lot`, etc.).
6. **Prioritize catalog fixes** for Smiski Series 2, Sonny Angel generics, Rolife brand aliases before figure overrides.
7. **Share derivation code** — generator must import `deriveSearchTerms` from `_search_term_derivation.mjs`, not fork formula.
8. **Add `metadata_coverage_audit.mjs`** in implementation sprint (override rate, stale keys, hint count).
9. **Migration rollback tag** before first full regen.

Not changed (confirmed sound):

- Three-layer architecture
- `figure.id` keys
- `aliasHints` as review-only
- Threshold heuristic list (with production override escape hatch)

---

## Open Questions

| # | Question | Options |
|---|----------|---------|
| 1 | **Commit Layer C or gitignore?** | Commit with `_comment` until CI merge exists; then gitignore |
| 2 | **`matchThreshold: null` in override** — inherit or clear? | Prefer **omit field** in overrides; `null` explicitly clears to global 0.75 |
| 3 | **Auto-copy `figure.aliases[]` → `marketAliases`?** | Yes when catalog populated; until then hints only |
| 4 | **Heuristic 0.80 threshold without production evidence?** | Keep as conservative pre-filter; catalog audit `ambiguousFigureName` (109 figures) may suffice — validate on fixtures first |
| 5 | **Metadata schema version field?** | `_schemaVersion: 1` in Layer C for future merge migrations |
| 6 | **Series block autogen?** | Generate series `searchTerms` in Layer A for all 109 series, or only when pipeline uses series-level fetch |
| 7 | **Dead alias cleanup** | Periodic report: overrides referencing deleted figures; aliases with zero matcher hits in review log |

---

## Future Extensions

| Extension | Description | When |
|-----------|-------------|------|
| `metadata_coverage_audit.mjs` | Override rate, stale keys, hint backlog, field histogram | Implementation sprint |
| `coverage_report.mjs` | Metadata + snapshot join | After first production snapshot run |
| `merge --prune` | Remove stale override keys | When catalog deletes figures |
| Query dedup layer | Shared search pool across figures (QUERY_VOLUME) | Before 5k figures or production cadence |
| `figure.aliases[]` catalog enrichment | Luck/Hope/Love in seed → generator propagates | Catalog quality sprint |
| Brand metadata block | **Not recommended** — use `brands.json` | — |
| IP-level override file | **Not recommended** — use `ips.json` | — |
| Compact override format | Override file lists only `{ figureId, marketAliases }` sparse rows | When override rate stays <10% |
| Metadata schema v2 | Confidence / provenance per field (`source: generated|override`) | Only if audit trail becomes necessary |

---

## Key Files Referenced

| File | Role |
|------|------|
| [`market_metadata.json`](./market_metadata.json) | Current hand-authored seed (Layer C today) |
| [`MATCHER_DESIGN_REVIEW.md`](./MATCHER_DESIGN_REVIEW.md) | Maintenance principles; future `coverage_report.mjs` |
| [`MATCHING_DESIGN.md`](./MATCHING_DESIGN.md) | §2 searchTerm rules, §3 exclude rules |
| [`_search_term_derivation.mjs`](./_search_term_derivation.mjs) | Runtime derivation formula to mirror in generator |
| [`tools/seed/figures.json`](../seed/figures.json) | 1,144 figures |
| [`tools/seed/series.json`](../seed/series.json) | 109 series |
| [`tools/seed/ips.json`](../seed/ips.json) | IP aliases for search term formula |
| [`QUERY_VOLUME_OPTIMIZATION.md`](./QUERY_VOLUME_OPTIMIZATION.md) | Query scale implications of full autogen |
| [`CATALOG_COVERAGE_REPORT.md`](./CATALOG_COVERAGE_REPORT.md) | Matcher generalization baseline (99.4%) |
| [`docs/TECH_DEBT.md`](../../docs/TECH_DEBT.md) | Catalog metadata quality audit items |
