# Testing notes

Operational guidance for manual and scripted verification — complements unit/widget tests.

**Primary RC workflow:** run the automated gate below, then manual smoke as needed. Detailed manual checklists live in [`release_candidate_test_plan.md`](release_candidate_test_plan.md) (historical supplement). Catalog runtime behavior: [`CATALOG_ARCHITECTURE.md`](CATALOG_ARCHITECTURE.md). Search behavior: [`SEARCH_ARCHITECTURE.md`](SEARCH_ARCHITECTURE.md).

---

## Release Candidate gate (automated)

Before manual RC or merge on `feature/catalog-refresh-architecture` (or successor RC branch):

```bash
flutter analyze
flutter test
```

**Target:** full suite green (`flutter test` — 878 tests at v1.0.0 polish). Feature tests that touch catalog must override `catalogBundleProvider` — do not rely on the 12s Firestore timeout in unit tests.

**Focused smoke** (when iterating on a subsystem):

```bash
flutter test test/catalog_search_service_test.dart
flutter test test/collection_modal_overlays_test.dart
flutter test test/widget_test.dart
```

---

## Emulator smoke scripts — ADB text input

When driving the Flutter UI from shell scripts (`adb shell input text`), **spaces must use `%s`**, not URL encoding.

| Do | Don't |
|----|--------|
| `adb shell input text hello%skitty%smonsters` | `EscapeDataString()` → `%20` |
| `adb shell input text popmart` (no spaces — plain text OK) | `adb shell input text hello%20kitty%20monsters` |

**Why:** `adb shell input text` treats `%s` as a space. It does **not** decode `%20`. PowerShell `[uri]::EscapeDataString()` (or similar) produces `%20` and will type literal `%20` or otherwise garble multi-word catalog searches — producing false “No matches” results even when Search V2 and the bundle are correct.

**Example (catalog search smoke):**

```bash
adb shell input text hello%skitty%smonsters
adb shell input text the%smonsters%shello%skitty
adb shell input text popmart
```

**Rule of thumb:** Any emulator smoke script that types a query with spaces → use `%s` between words. Do not use `EscapeDataString()` for ADB input.

---

## Automated tests

- Feature tests: `test/<feature>_…_test.dart`
- Widget smoke: `test/widget_test.dart`
- After behavior changes: run `flutter analyze` and the relevant `flutter test` targets (see [`.cursor/rules/project-architecture.mdc`](../.cursor/rules/project-architecture.mdc)).
