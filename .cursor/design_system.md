# Shelfy Design System

Canonical UI reference for humans and agents (Cursor / Codex / Claude).  
**Read this before inventing new radii, button recipes, icon styles, type roles, or raw `Duration`s.**

Architecture boundaries stay in [ARCHITECTURE.md](ARCHITECTURE.md). Product tone stays in [rules/product-principles.mdc](rules/product-principles.mdc).

**Code sources of truth**

| Concern | File |
|--------|------|
| Icons + button recipes | `lib/core/theme/shelfy_symbols.dart` |
| Typography roles | `lib/core/theme/app_typography.dart` |
| Domain type hierarchy | `lib/core/theme/collectible_typography.dart` |
| Radii | `lib/core/theme/app_radii.dart` (+ `collectible_shape.dart`) |
| Motion | `lib/core/theme/collectible_motion.dart` |
| Feed spacing | `lib/core/layout/feed_rhythm.dart` |

Extend these APIs. Do not fork parallel token files per screen.

---

## Icons

**Family:** Material Symbols **Rounded** (`Symbols.*_rounded`).

**Defaults** (`ShelfySymbols.ensureInitialized()` at app start):

| Token | Value | Use |
|-------|-------|-----|
| fill | `0` (outline) | Default chrome |
| fill | `1` (solid) | Selected nav / active wishlist / emphasis |
| weight | `400` | Default |
| grade | `0` | Default |
| opsz | `24` | Default |

**AppBar / IconButton chrome**

- Theme `iconButtonTheme`: min size `AppIconPadding.buttonMin` (40)
- AppBar `iconTheme` / `actionsIconTheme`: size `AppIconSizes.navigation` (24)
- Leading back / sheet close: prefer explicit `AppIconSizes.navigation`
- Search clear / toolbar Share: `AppIconSizes.toolbar` / `clear` (20)

**Optical sizes** (`AppIconSizes`):

| Role | dp | Use |
|------|----|-----|
| `navigation` | 24 | Bottom nav |
| `standard` | 22 | Search / camera / field chrome |
| `toolbar` / `clear` | 20 | Share, clear, detail CTA icons |
| `metadata` | 18 | Sort, menu chevrons |
| `expand` | 20 | Section expand/collapse |
| `quickAction` | 20 | Wishlist heart / remove wells |
| `cta` | 22 | Sticky / filled button leading icons |
| `headerQuiet` | 16 | Quiet header Add |
| `secondaryShare` | 15 | Outlined Share companion |
| `emptyHero` | 78 | Empty-state heroes |

**Padding / hit** (`AppIconPadding`): camera 48 hit / 36 well; quick action 40 hit / 32 well; toolbar button min 40.

**Empty-state heroes** (Wishlist reference):

- size `AppIconSizes.emptyHero`, weight `250`, opsz `48`, fill outline
- Collection / Market empty use the same optical recipe (different glyphs by emotion)
- Wrap decorative heroes in `ExcludeSemantics` when adjacent text already labels the state

**Stateful favorites:** same `Symbols.favorite_rounded` glyph — communicate via fill + color, not `favorite_border_*`.

**Do not** reintroduce `Icons.*` Material Icons in product UI. Prefer existing shared glyph widgets over one-off SVGs for chrome.

---

## Buttons

Use `ShelfyButtonStyles` for shared recipes:

| Role | Recipe | Notes |
|------|--------|-------|
| **Primary sticky CTA** | `ShelfyButtonStyles.stickySheetCta()` | Sheet Add / Create — mat radius, min height 48 |
| **Secondary Share** | `ShelfyButtonStyles.secondaryShare(scheme)` | Outlined companion — field radius |
| **Icon button** | Theme `IconButton` + Symbols | Header / toolbar chrome |

**Intentional exceptions** (do not “unify away”):

- Header quiet Add series / tonal Share (lighter than sticky CTA)
- Recognition Stadium CTAs (ceremony surface)
- Achievement / Master Complete emoji glyphs (not chrome icons)

---

## Radius

Use `AppRadii` / `CollectibleShape` — do not invent new corner values.

| Token | dp | Typical use |
|-------|----|-------------|
| inset | 14 | Inner windows, nested clips |
| mat | 18 | Mats, sticky CTAs, soft metric tiles |
| field | 20 | Search fields, Share outline, tonal blocks |
| card | 22 | Browse rows, recommendation tiles |
| figureGallery | 24 | Gallery frames |
| spotlight | 26 | Hero covers, sheet top corners |
| shell | 28 | Product shells, listing tiles, shelf rows |
| pill | ~999 / stadium | Chips only when already established |

Rough mental ladder (user-facing): **14 → 18 → 20 → 22 → 26 → 28**. Prefer the named token over a raw number.

---

## Typography

Prefer **named roles** over `textTheme.*.copyWith(...)` in widgets.

### Cross-screen roles — `AppTypography`

| Role | Job |
|------|-----|
| `tabTitle` | Main-tab AppBar titles (Discover, Market, Collection, Insights) |
| `screenTitle` | Full-screen / overlay editorial titles |
| `sectionTitle` | `CollectibleSectionHeader` titles |
| `sectionLabel` | Quiet Brand / IP labels above chip rails |
| `cardTitle` / `cardMeta` | Card & list row primary / meta |
| `deckText` / `supportive` | Flavor under sections; quiet meta lines |
| `emptyStateTitle` / `emptyStateBody` | Centered empty compositions (Collection / Wishlist / Market) |
| `insightsHeroName` / `insightsBecause` | Collector Type hero name + Because line |
| `insightsTotals` / `insightsFlavor` / `insightsCaption` | Insights totals, flavor, quiet captions |

### Domain hierarchy — `CollectibleTypography`

IP → series → figure naming and shelf/catalog row weights. Delegate here when the role already exists; add new cross-screen roles to `AppTypography` instead of more inline `copyWith`.

**Conservative rule:** Share export cards, recognition ceremony, and specialized Insights beat numerals may stay on `CollectibleTypography` — do not mass-rewrite every `fontSize` for sameness. Empty-state **titles** should share `AppTypography.emptyStateTitle` even when layout/copy differs by job.

**Shared widgets:** taxonomy labels → `TaxonomyFilterSectionLabel` (not a local `_FilterLabel`).

---

## Motion

Prefer aliases over raw `Duration(milliseconds: …)` for everyday UI:

| Alias | Duration | Use |
|-------|----------|-----|
| `CollectibleMotion.fast` | 200ms | Chips, chevrons, light expands, opacity flickers |
| `CollectibleMotion.medium` | 280ms | Cross-surface soft transitions, expand/collapse body |
| `CollectibleMotion.sheet` | 360ms | Modal sheet open (`sheetAnimationStyle`) |
| `CollectibleMotion.sectionReveal` | 320ms | Tab scroll-to-top, soft route fades |

Specialized durations (gallery, recognition finding, collector-type ceremony, glow/shimmer) stay named on `CollectibleMotion` — do not collapse them into `fast`/`medium`.

**Do not** sprinkle raw `Duration(milliseconds: 200)` (or 280 / 360) in new UI — use `fast` / `medium` / `sheet` (or another named token).

Default curves: `CollectibleMotion.easeOut` / `easeIn` (calm cubic — no bounce gimmicks).

---

## Surfaces (keep different on purpose)

| Surface | Feel | Do not force |
|---------|------|----------------|
| Shell cards | Deeper shelf shadow, shell radius | Same padding as soft Insights tiles |
| Soft cards / metric tiles | Quieter fill, mat radius | Shell shadow |
| Collection empty | Warm-start / shelf voice | Wishlist heart composition |
| Wishlist empty | Symbols heart + empty type roles | Collection warm-start copy |

Different **jobs** may share tokens without sharing layout.

---

## PR checklist

Before merging UI work:

1. Icons are Symbols Rounded with Shelfy fill/weight/opsz (or documented exception)
2. Sticky / Share buttons use `ShelfyButtonStyles` when applicable
3. Radii come from `AppRadii` / `CollectibleShape`
4. New text uses `AppTypography` / `CollectibleTypography` roles
5. New micro-motion uses `CollectibleMotion.fast` / `.medium` / `.sheet` (or a named specialized duration)
6. Spacing prefers `FeedRhythm` / `AppSpacing` over one-off padding inflation
