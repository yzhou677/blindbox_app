# Shelfy ??Release Candidate Test Plan

> **Historical supplement.** This document predates the catalog-refresh architecture merge. For current RC workflow use **[`TESTING.md`](../../TESTING.md)** (automated gate + ADB notes) and **[`CATALOG_ARCHITECTURE.md`](../../CATALOG_ARCHITECTURE.md)** (catalog runtime). Update manual scenarios here only when they diverge from those sources.

**Branch / build under test:** RC branch or tagged RC build (e.g. `feature/catalog-refresh-architecture`)  
**Display name:** Shelfy (package id: `app.shelfy.collector`, Firebase project: `blindbox-collection`)  
**Tester mindset:** Collector app ??image-first, local shelf, messy navigation, poor network.

This plan is **architecture-aware** and targets regressions that unit tests do not catch: overlay lifecycle, router races, ownership semantics, cache behavior, and Android gesture edge cases.

---

## 1. Release scope summary

### Stabilized for RC (in scope)

| System | What ?œgood??means |
|--------|-------------------|
| **Shell navigation** | Cold launch on **Collection** tab; bottom nav order: **Collection ??Discover ??Market**; Discover uses explore icon + label |
| **Collection (local-first)** | `CollectionNotifier` + `SharedPreferences` codec; optimistic add/remove; debounced persist; collapsible insights dashboard (`CollectionInsightsDashboardHost`) isolated from shelf rebuilds |
| **Ownership presentation** | `CollectionSeriesShelfCtaPresentation` ??same semantics on search rows, Latest releases, Home save chip, add sheet, catalog browse, **preview sticky CTA** (`previewSticky`) |
| **Ownership detection** | `resolveCollectionSeriesOwnership()` ??template id + **canonical brand+series** (no taxonomy false positives) |
| **Modal overlays** | `showCollectibleBottomSheet` / `showCollectionModalBottomSheet`; `CollectionModalOverlayRegistry.dismissAll()` reentrancy guard |
| **Nested sheets** | Add sheet ??catalog preview on **branch** navigator (not root stack); leaving Collection tab dismisses overlays |
| **Catalog load** | `CatalogBundleCache` ??`catalogBundleProvider`: Firestore one-shot `.get()`; persisted `catalog_bundle_v1.json` offline; `catalogAvailabilityProvider` for loading/offline/refresh UX ??**no** APK metadata seed fallback |
| **Catalog images** | `CatalogImageResolver`: bundled ??disk cache (LRU ~150MB, TTL) ??Storage ??placeholder; stale-while-revalidate; bounded concurrent refresh; session negative cache for 404s |
| **Discover / Home** | Latest drops, trending, official feed (`official_feed_items`), catalog browse push |
| **Market** | Browse filters (taxonomy ids from catalog bundle only); listing detail; expandable description |
| **Preview UX** | Sticky catalog preview CTA; handle area supports **downward drag dismiss** (chrome in fixed header) |
| **Firebase rules (draft)** | `firestore.rules` / `storage.rules` in repo ??**deploy is a separate gated step** (Â§6) |

### Intentionally out of scope (RC)

- Renaming `applicationId`, bundle id, repo folder `blindbox_app`, or Firebase project
- Cloud sync of shelf / `firebase_auth` / multi-device collection
- Mercari live gateway as primary market source (Functions exist; **product default is live eBay gateway** via `MARKET_GATEWAY_EBAY=true`)
- Full catalog ingestion pipeline (external Admin tooling)
- Performance benchmarking / automated E2E framework build-out
- iOS parity beyond smoke (Android is primary stress target per recent stabilization)

### Known automated coverage (sanity, not a substitute)

Before manual RC, run on the candidate build:

```bash
flutter analyze
flutter test test/collection_modal_overlays_test.dart
flutter test test/collection_series_shelf_cta_presentation_test.dart
flutter test test/add_to_collection_sheet_search_ownership_test.dart
flutter test test/catalog_series_preview_sheet_layout_test.dart
flutter test test/catalog_image_resolver_disk_cache_test.dart
flutter test test/widget_test.dart
```

---

## 2. Critical path tests (P0)

**Rule:** Any failure here is a **release blocker** unless explicitly downgraded in Â§9.

### 2.1 Cold launch & shell

| # | Steps | Pass criteria |
|---|--------|----------------|
| P0-1 | Kill app ??cold launch | Lands on **Collection** (?œMy collection??; launcher name **Shelfy** |
| P0-2 | Observe first paint | No red error screen; shelf empty or restored from prior session |
| P0-3 | Tap each tab once | Collection / Discover / Market all load; selected icon + label correct |

### 2.2 Collection core

| # | Steps | Pass criteria |
|---|--------|----------------|
| P0-4 | Add series via **Add a series** ??search ??**Add** (not row tap alone) | Series appears on shelf; summary counts update |
| P0-5 | Open series ??figures sheet ??toggle owned/wishlist | State updates immediately; survives kill + relaunch |
| P0-6 | Remove series (confirm dialog) | Series gone after confirm; persist after relaunch |
| P0-7 | Brand filter chips | Filter/reset works; no crash on empty brand shelf |

### 2.3 Ownership sync (cross-surface)

Use one catalog series you can add from **search** and **Latest releases** if possible.

| # | Steps | Pass criteria |
|---|--------|----------------|
| P0-8 | Add from add-sheet search | Row shows **In collection** (disabled check), not **Add** |
| P0-9 | Open same series **preview** from search | Sticky CTA: **In collection** (disabled), not **Add to shelf** |
| P0-10 | Add from Discover **Latest drops** save control | Chip shows owned state; matches add-sheet after return |
| P0-11 | **Canonical-owned custom entry** (same brand+series name, no template id) | Search + preview show owned without adding duplicate |

### 2.4 Discover & catalog browse

| # | Steps | Pass criteria |
|---|--------|----------------|
| P0-12 | Discover ??scroll Latest / Trending | Images load or placeholder; no infinite spinner blocking scroll |
| P0-13 | Discover ??catalog search (`/home/catalog`) | Rows open preview; ownership CTA matches shelf |
| P0-14 | Official updates section (if feed populated) | Items load or section empty gracefully; tap opens external URL |

### 2.5 Market

| # | Steps | Pass criteria |
|---|--------|----------------|
| P0-15 | Market tab ??browse list | List renders; filters change results |
| P0-16 | Open listing detail | Hero, facts, price; description **Read more** expands fully (no UI ellipsis clamp when expanded) |
| P0-17 | Back from detail | Returns to Market without stuck overlay |

#### Optional ??Market device smoke (`tools/*.py`, adb)

Requires a connected Android device (`adb devices`), the app already running with live Market gateway flags (see `docs/EBAY_GATEWAY.md`), and Python 3 on the host. Scripts use `uiautomator` dumps ??unlock the device; layout coordinates assume a typical phone resolution.

| Script | Command | Use |
|--------|---------|-----|
| Full release checklist | `python tools/market_release_smoke.py` | Chasers/feed/search/route/pagination heuristics; prints PASS/MINOR/FAIL summary |
| Quick price-sort + load-more | `python tools/device_smoke_run.py` | Short POP MART / Price ??/ Load more / Nommi search pass |
| Minimal adb taps + logs | `python tools/market_smoke_adb.py` | Tap Market ??filter ??load more; prints recent `MarketSearch` / `MarketPriceSort` logcat lines |

These are **optional** QA helpers (not CI); failures may be flaky if OEM UI or screen size differs.

### 2.6 Preview sheets & drag dismiss

| # | Steps | Pass criteria |
|---|--------|----------------|
| P0-18 | Add sheet ??open series preview | Second sheet stacks; parent handle not ?œstuck??visually after dismiss |
| P0-19 | **Drag down on preview handle/header** | Sheet dismisses naturally (not only tap outside / back) |
| P0-20 | Owned series preview | **In collection** CTA visible; tap does not add duplicate |

### 2.7 Navigation & back

| # | Steps | Pass criteria |
|---|--------|----------------|
| P0-21 | Collection ??**Insights** ??system back | Returns to Collection shelf (page route), not black screen |
| P0-22 | Leave Collection tab while add sheet open | Sheet dismissed; no phantom touch blocker |
| P0-23 | Android back from nested preview | Pops preview then add sheet (or single pop per stack), no `Future already completed` crash |

### 2.8 Persistence

| # | Steps | Pass criteria |
|---|--------|----------------|
| P0-24 | Add shelf content ??force-stop ??relaunch | Shelf restored; no data loss |
| P0-25 | Custom series + local cover photo | Photo still displays after relaunch (device path valid) |

---

## 3. Regression-prone systems

These areas had **explicit stabilization work** or historically caused user-trust bugs. Test even if P0 passed once.

### 3.1 Modal overlay registry (`CollectionModalOverlayRegistry`)

**Risk:** Double `popUntil`, `StateError: Future already completed`, sheet left open under transparent barrier.

| Test | Steps | Watch for |
|------|--------|-----------|
| R-OV-1 | Open add sheet ??switch to Discover **during** open animation | Sheet closes; Collection tab usable |
| R-OV-2 | Open add sheet ??rapid tap Collection tab 3? | Exactly one dismiss; no crash in log |
| R-OV-3 | `dismissAll` while pop animating (re-tap tab) | No double-complete; idempotent within frame |
| R-OV-4 | Open sheet ??navigate to Insights (page) ??back | Insights page intact; no accidental mass pop |

**Code touchpoints:** `main_shell_scaffold.dart` (leave Collection ??`dismissAll`), `collection_screen.dart` router listener (`path.startsWith('/collection')`), `collection_modal_overlays.dart`.

### 3.2 Router / shell branch order

**Risk:** Stale `GoRouter` shell index between tests or after deep link; wrong tab highlighted.

| Test | Steps | Watch for |
|------|--------|-----------|
| R-NAV-1 | Cold launch | Index 0 = Collection |
| R-NAV-2 | Discover ??Market ??Collection | Highlight matches visible screen |
| R-NAV-3 | Re-tap **Collection** while on Collection | Scroll-to-top on shelf; optional overlay dismiss + reset branch |

**Constants:** `kCollectionShellBranchIndex = 0`, `kHomeShellBranchIndex = 1`, `kMarketShellBranchIndex = 2`.

### 3.3 Nested sheets (branch vs root)

**Risk:** Root navigator preview leaves parent drag handle pinned; double modal stack.

| Test | Steps | Watch for |
|------|--------|-----------|
| R-SH-1 | Add sheet ??preview ??dismiss preview | Parent sheet handle + scroll normal |
| R-SH-2 | Catalog browse (Discover) preview | Uses root navigator by design ??dismiss does not break Collection tab |
| R-SH-3 | Open preview ??add from CTA | Commits shelf + pops; parent lists update |

### 3.4 Ownership presentation drift

**Risk:** Row says ?œIn collection??but preview still ?œAdd to shelf??(fixed via `previewSticky` + `resolve()`).

| Surface | Layout key |
|---------|------------|
| Add sheet search / suggestions | `compactTrailing` |
| Catalog browse rows | `catalogBrowse` |
| Home Latest Drops | `homeReleaseIcon` / filled |
| Catalog series preview | `previewSticky` |

| Test | Steps | Watch for |
|------|--------|-----------|
| R-OWN-1 | Own via search ??open preview without adding again | Disabled **In collection** |
| R-OWN-2 | Remove series ??return to search | **Add** restored |
| R-OWN-3 | Custom shelf row matching catalog brand+series | Owned on search without template id |

### 3.5 Catalog image resolver & cache

**Risk:** Storage 404 spam, UI jank from unbounded refresh, stale wrong image after key change, offline regression.

| Test | Steps | Watch for |
|------|--------|-----------|
| R-IMG-1 | Scroll long catalog list online | No log flood of repeated 404 for same `imageKey` |
| R-IMG-2 | View series ??kill network ??scroll same area | Disk/bundled art still visible where cached |
| R-IMG-3 | Airplane mode cold launch ??browse catalog | Seed/bundled/placeholder; app usable |
| R-IMG-4 | Online after offline | Stale-while-revalidate may swap image; no hang |
| R-IMG-5 | Open figure gallery | Precache neighbors; swipe smooth enough |

**Code touchpoints:** `catalog_image_resolver.dart`, `catalog_image_disk_cache.dart`, `catalog_image_cache_policy.dart`, `CatalogImageFromKey`.

### 3.6 Collection write coalescing

**Risk:** Rapid figure toggles cause ANR-style hitch or lost final state.

| Test | Steps | Watch for |
|------|--------|-----------|
| R-PER-1 | Rapidly tap 10+ figure slots | UI keeps up; final state correct after 1s idle |
| R-PER-2 | Kill app within 500ms of last tap | Relaunch shows last intended states (debounce flush on dispose) |

### 3.7 Market session / browse cache

**Risk:** Filter change shows stale listings; memory growth from unbounded cache (FIFO cap exists ??verify no leak symptoms).

| Test | Steps | Watch for |
|------|--------|-----------|
| R-MKT-1 | Change brand/IP chips rapidly | Results match filter; no crash |
| R-MKT-2 | Scroll long browse list | Lazy sliver scroll; no multi-second freeze |

---

## 4. Stress / chaos testing

Simulate impatient collector behavior for **??5 minutes** on a physical Android device (Samsung preferred).

| ID | Scenario | Pass criteria |
|----|-----------|----------------|
| C-1 | **Tab spam:** Collection ??Discover ??Market as fast as possible for 30s | No stuck overlay; no duplicate sheets; app responsive |
| C-2 | **Re-tap storm:** Tap Collection tab 10? while scrolling shelf | Scroll resets or stable; no crash |
| C-3 | **Sheet spam:** Open add sheet ??preview ??dismiss ?10 | No accumulating routes; memory stable |
| C-4 | **Add/remove spam:** Add series, remove, search again ?5 | Ownership CTAs always match shelf |
| C-5 | **Background during modal:** Open add sheet ??home button ??return | Sheet dismissed or restored predictably; no ghost barrier |
| C-6 | **Rotate / fold** (if supported) during preview sheet | No lost state or irrecoverable layout |
| C-7 | **Low memory warning** (Developer options) then open gallery | Graceful degradation, no hard kill loop |
| C-8 | **Search while navigating:** Type in add search ??switch tab mid-query | No exception; returning to sheet sane |
| C-9 | **Open Insights during sheet** (if reachable) | No `popUntil` eating Insights page |
| C-10 | **Market detail:** Expand description ??scroll ??back ??re-enter | Expanded state reasonable; no layout explosion |

**Log watch (debug build):** `Future already completed`, `permission-denied`, unbounded `CatalogImageResolver` storage lines for same key.

---

## 5. Offline / cache validation

### 5.1 Bundled assets

| # | Steps | Pass |
|---|--------|------|
| O-1 | First install, airplane mode, open catalog images in seed-heavy series | Bundled `assets/catalog/**` shows where present |
| O-2 | Series with no bundled asset | Placeholder (not broken-image icon storm) |

### 5.2 Disk cache

| # | Steps | Pass |
|---|--------|------|
| O-3 | Online: browse until Storage images load | Files written under app cache (`cache_index.json` lifecycle) |
| O-4 | Airplane mode: revisit same screens | Cached images render without network |
| O-5 | Clear app storage ??relaunch | Cache rebuilds; no crash |

### 5.3 Stale-while-revalidate & refresh cap

| # | Steps | Pass |
|---|--------|------|
| O-6 | Load image online ??background refresh | No UI freeze; at most bounded concurrent Storage probes |
| O-7 | Flap airplane mode while scrolling Discover | Placeholders/cached/disk layers rotate without deadlock |

### 5.4 Storage miss / 404 behavior

| # | Steps | Pass |
|---|--------|------|
| O-8 | Series with known missing Storage object | One debug miss per key (debug build); UI placeholder |
| O-9 | Scroll past many missing keys | Log volume stays bounded (negative session cache) |

### 5.5 Cache invalidation sanity

| # | Steps | Pass |
|---|--------|------|
| O-10 | After long session, disk near policy limit | LRU eviction; app still responsive; no crash |

---

## 6. Firebase production hardening verification

**Scope:** Shelfy uses Firebase Core, Firestore, Storage, and the market HTTPS Cloud Function. It does **not** use Firebase Auth, Google Sign-In, Phone Auth, App Check, Analytics, Crashlytics, or FCM. **Release SHA registration is not a functional requirement** for Â§6 checks.

**Prerequisite:** Backend deployed to `blindbox-collection` ??see [`FIREBASE_LOCAL_SETUP.md` ??Firebase release checklist](../../FIREBASE_LOCAL_SETUP.md#firebase-release-checklist-v100). Rules/indexes/functions in git ??live in console.

Deploy (staging first, then production):

```bash
npx --prefix functions firebase deploy --only firestore:rules,storage --project blindbox-collection
npx --prefix functions firebase deploy --only firestore:indexes --project blindbox-collection
npx --prefix functions firebase deploy --only functions:market --project blindbox-collection
```

Use `storage`, not `storage:rules` (single-bucket config ??see `FIREBASE_LOCAL_SETUP.md`).

### 6.0 Backend deployment sign-off

| # | Check | Pass |
|---|--------|------|
| F-0a | Firestore rules live match repo draft (public catalog + official feed read) | Y/N |
| F-0b | Storage rules live (public `catalog/**` read) | Y/N |
| F-0c | `firestore.indexes.json` deployed (`official_feed_items` composite) | Y/N |
| F-0d | `functions:market` deployed; live eBay env if Market in ship scope | Y/N / N/A |
| F-0e | Release build includes `google-services.json` for `app.shelfy.collector` | Y/N |

**SHA:** Not required for F-0a?“F-0e. Optional SHA sync is log-noise mitigation only ??see `FIREBASE_LOCAL_SETUP.md`.

**Future:** If Auth, Sign-In, or App Check is added later, add Release / Play App Signing SHA to the release gate at that time.

### 6.1 Read paths (client, unauthenticated)

| # | Check | Pass |
|---|--------|------|
| F-1 | Cold launch online | Catalog loads from Firestore (or persisted cache on repeat launch) without permission errors; availability card reflects ready/offline state |
| F-2 | Discover official feed | Query succeeds or empty; no `permission-denied` spam |
| F-3 | Catalog images | `catalog/series/*`, `catalog/figures/*` download or cache |
| F-4 | Airplane mode after cache warm | Â§5 still passes |

### 6.2 Write denial (client must fail closed)

Use debug build or temporary dev probe ??**not shipped to users**.

| # | Check | Pass |
|---|--------|------|
| F-5 | Client attempt write to `brands/{id}` | Denied |
| F-6 | Client attempt upload to `catalog/figures/...` | Denied |

### 6.3 Admin / ingestion (must still work)

| # | Check | Pass |
|---|--------|------|
| F-7 | `node tools/official_feed/push_official_feed.mjs` (service account / ADC) | Succeeds |
| F-8 | External catalog pipeline (Admin SDK) | Unaffected by client rules |

### 6.4 Failure signatures

| Symptom | Likely cause |
|---------|----------------|
| Empty catalog + `permission-denied` in log | Rules too strict or wrong project |
| Images all placeholder, metadata OK | Storage rules or bucket path |
| Official feed empty, catalog OK | Missing composite index or rules on `official_feed_items` |
| App fine, push script fails | Admin credentials, not client rules |

---

## 7. UI consistency checks

| Area | Check |
|------|--------|
| **Ownership CTA** | ?œIn collection??never looks tappable (muted/disabled/check); ?œAdd??uses primary tint |
| **Preview sticky CTA** | Always visible; scroll does not hide behind system nav |
| **Preview vs row** | Same owned/addable semantics for same series |
| **Discover label** | Bottom nav **Discover** + explore icon; screen title **Discover** |
| **Collection label** | Launcher **Shelfy**; in-app ?œMy collection??|
| **Drag handle** | Visible on sheets; downward drag dismisses preview |
| **Empty shelf** | Calm empty state; CTA to add/browse |
| **Market description** | Collapsed = truncated; expanded = full text (literal `...` in source copy OK) |
| **Figure gallery** | Back dismisses; no Collection tab bleed-through |

---

## 8. Android-specific behavior

**Primary device:** Samsung (One UI) or equivalent gesture-nav Android 13+.

| # | Scenario | Pass criteria |
|---|----------|----------------|
| A-1 | **Predictive back / edge back** from preview sheet | Pops sheet; does not exit app unexpectedly |
| A-2 | Back from add sheet | Sheet closes; shelf interactive |
| A-3 | Back from Collection Insights | Returns to shelf |
| A-4 | **Keyboard** in add-sheet search | Field visible; dismiss keyboard + sheet OK |
| A-5 | **Resume** from recents after 5+ min | State restored; images rehydrate |
| A-6 | **Split screen / PiP** (if used) | No permanent overlay block |
| A-7 | **Permission deny** for photos (custom series) | Snackbar/error; no crash |
| A-8 | Long scroll shelf (lazy `SliverList`) | No multi-second jank each frame |
| A-9 | **TalkBack** (spot check) | Ownership semantics labels sane on preview CTA |

**ANR / freeze red flags (treat as P0 if reproducible):**

- Tap after closing sheet ??no response for >2s  
- Tab switch hangs with dimmed scrim  
- Repeated ?œApp isn?™t responding??on shelf filter change  

---

## 9. Release blocker definitions

### P0 ??Ship blocker

- Crash or unrecoverable navigation loop on critical paths (Â§2)  
- Data loss on collection persist / corrupt shelf after normal use  
- Wrong ownership (**Add** when owned, or duplicate add from preview) on reproducible path  
- Modal overlay leaves app unusable (touch blocked, sheet cannot dismiss)  
- `Future already completed` or similar navigation crash on common back/tab path  
- Catalog completely unavailable online with rules **not** intentionally deployed  
- Mass Storage `permission-denied` for all images post-rules deploy  

### P1 ??Acceptable for RC with documented workaround

- Occasional placeholder for missing Storage asset (known catalog gap)  
- Official feed empty when Firestore collection empty  
- Minor scroll jank on very large shelf (??0 series)  
- Market browse uses asset/fixture data (known product mode)  
- iOS-specific cosmetic-only issues if Android ship target  

### P2 ??Cosmetic / post-release

- Copy typos, spacing nits, non-blocking animation preference  
- Rare image flicker on stale-while-revalidate swap  
- Log noise in debug only  

**Document every P1 with:** steps, device, build id, screenshot, workaround.

---

## 10. Recommended execution cadence

### Day 0 ??Build & smoke (30??5 min)

1. Install RC APK on primary Android device.  
2. Run automated commands (Â§1).  
3. Execute **Â§2 P0** only.  
4. If any P0 fails ??stop; file blocker.

### Day 1 ??Deep candidate pass (2?? hours)

1. **Â§3** regression matrix (overlays, ownership, images).  
2. **Â§7** UI consistency sweep.  
3. **Â§8** Android back/gesture subset.

### Day 2 ??Chaos + offline (1?? hours)

1. **Â§4** stress scenarios on one device.  
2. **Â§5** offline/cache with airplane mode toggling.

### Day 3 ??Firebase gate (if deploying rules)

1. Deploy rules to **staging** ??full **Â§6**.  
2. Repeat P0-12, P0-13, P0-8, image spot checks.  
3. Production deploy only after staging sign-off.

### Day 4?? ??Overnight casual usage

- Real collector session: add 3?? series, browse Discover, check Market, relaunch next morning.  
- Note emotional trust issues (wrong CTA, stuck sheet, lost shelf).

### Final RC sign-off (30 min)

- Re-run **Â§2 P0** on release binary.  
- Confirm no open P0; P1 list reviewed by owner.  
- Tag build; freeze feature branch.

---

## Sign-off template

| Field | Value |
|-------|--------|
| Build / commit | |
| Device(s) | |
| Tester | |
| Date | |
| P0 failures | None / list |
| P1 accepted | list |
| Firestore + Storage rules deployed? | Y/N, environment |
| Firestore indexes deployed? | Y/N |
| Market function deployed (if in scope)? | Y/N / N/A |
| `google-services.json` in release build? | Y/N |
| **RC recommendation** | Ship / Hold |

---

*This document reflects Shelfy architecture as of the release-stabilization branch (Collection-first shell, unified ownership CTA, overlay registry, catalog disk cache, draft Firebase rules). Update when ship scope changes.*
