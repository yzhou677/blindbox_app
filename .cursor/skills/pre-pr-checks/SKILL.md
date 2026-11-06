---
name: pre-pr-checks
description: >-
  Runs the checks required before a Shelfy pull request. Use when the user
  is about to open or push a PR, asks for analyze, tests, coverage, or
  hits a Windows golden mismatch.
---

# Pre-PR checks

Behavior changes need tests. What to test is in [`.cursor/rules/pr-tests.mdc`](../../rules/pr-tests.mdc) and [docs/TESTING.md](../../../docs/TESTING.md). Do not copy those rules here.

## Steps

1. `flutter analyze` — must be clean.
2. Full tests, same flags as `.github/workflows/pr-ci.yml`:

```text
flutter test --coverage --reporter=expanded --timeout=120s
```

The test step also has `timeout-minutes: 20`. The job cap stays 60 minutes.
3. Coverage is report-only. CI posts it from `coverage/lcov.info` via `.github/scripts/report_pr_coverage.mjs`. Low coverage does not fail the job ([docs/CI.md](../../../docs/CI.md)).
4. Windows golden failures are a known raster difference. Linux CI is the baseline. Do not update `test/goldens/` from Windows. Refresh only through the Linux job in [docs/CI.md](../../../docs/CI.md) ("Golden baselines").
5. If tests hang, read the last few log lines and any `[E]` lines. The last test name is not always the stuck test ([docs/CI.md](../../../docs/CI.md)).

## Temp directories

Do not pass `Directory.systemTemp` itself to code that deletes a directory. `ShelfExportStaging.delete()` refuses that path and throws `StateError`.

Create a child directory and delete that child:

```dart
Directory.systemTemp.createTempSync('shelfy_staging_')
```

That pattern is already used in `test/shelf_import_flow_test.dart`, `test/shelf_backup_sheet_test.dart`, and `test/shelf_export_archive_test.dart`.
