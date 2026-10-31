# PR CI

How GitHub Actions validates pull requests that target `main`.

Workflow file: [`.github/workflows/pr-ci.yml`](../.github/workflows/pr-ci.yml).  
This is separate from [`.github/workflows/deploy-pages.yml`](../.github/workflows/deploy-pages.yml) (GitHub Pages) — do not merge the two.

---

## Triggers

Runs on `pull_request` to `main` for `opened`, `synchronize`, and `reopened`.

Concurrency: one active run per PR; newer pushes cancel older runs.

---

## Jobs

| Job | What it does |
| --- | --- |
| **Flutter analyze / test / APK** | `flutter analyze`, `flutter test --coverage` (lcov), debug APK artifact |
| **PR coverage comment block** | Replaces the PR description coverage region (report-only) |
| **Cloud Functions** | Only if the PR touches `functions/**` — Node 22, `npm ci`, lint, build, test |

Permissions stay minimal: workflow default is `contents: read`. Only the coverage job adds `pull-requests: write`.

---

## Flutter version & caching

CI pins **Flutter 3.41.9** (stable), matching this repo’s local toolchain (`flutter --version`).  
`subosito/flutter-action` enables pub cache (`cache: true`).

---

## `google-services.json`

`android/app/google-services.json` is gitignored.

| Step | Needs the file? |
| --- | --- |
| `flutter analyze` | No |
| `flutter test` | No |
| `flutter build apk --debug` | Yes (Gradle `google-services` plugin) |

CI copies a **non-secret stub** from [`.github/ci/google-services.ci.json`](../.github/ci/google-services.ci.json) into `android/app/google-services.json` before the APK build. It uses package name `app.shelfy.collector` and placeholder project/API values so Gradle can parse the file. **Do not** commit real Firebase credentials. No GitHub Actions secret is required for analyze / test / debug APK today.

Tracked `lib/firebase_options.dart` is enough for Dart-side compile in tests.

---

## Coverage block in the PR description

Markers (must stay exactly like this):

```text
<!-- coverage:start -->
…auto-generated table…
<!-- coverage:end -->
```

On each push to the PR, [`.github/scripts/report_pr_coverage.mjs`](../.github/scripts/report_pr_coverage.mjs):

1. Reads `coverage/lcov.info` from the Flutter job artifact
2. Computes **total line coverage** (sum of `LH` / `LF`)
3. Lists coverage for **changed `*.dart` files** in the PR
4. **Replaces** the marked block in the PR body (does not append duplicates; leaves the rest of the description alone)

Coverage is **report-only** — low coverage never fails the build.

**Fork PRs:** the coverage job detects `head.repo != base.repo` and skips the body update (default token cannot safely write to the base repo).

---

## Known failures (do not skip in CI)

Local baseline when this pipeline was added (`flutter analyze` + `flutter test --coverage`):

### Analyzer

- **Error:** `test/collection_input_widget_test.dart` — `CustomSeriesFormSubmit` argument type mismatch (also prevents that test file from loading)

### Tests

| Environment | Pass | Skip | Fail |
| --- | ---: | ---: | ---: |
| Local (Windows) | ~2212 | 1 | 33 |
| GitHub Actions (first run) | 2208 | 1 | **37** |

Representative failing groups (list drifts — re-run to refresh):

- Goldens / screenshots: `collection_insights_dashboard_release_audit_test`, `collection_ip_filter_qa_widget_test`, `collection_series_card_spacing_screenshot_test`, `ip_introduction_ownership_screenshot_test`, `completion_visual_verification_test`
- Catalog / home refresh: `catalog_bundle_propagation_test`, `home_feed_catalog_refresh_test`
- Collector type: `collector_type_explainability_test`, `collector_type_reveal_record_test`, `collector_type_signal_ownership_test`, `collector_type_reveal_lifecycle_contract_test`
- Recommendations: `recommendation_repository_test` (2 cases)
- Shelf smoke: `widget_test` Collection tab; `collection_ip_filter_widget_test`
- Compile fail: `collection_input_widget_test` (same analyzer error)

**Cloud Functions:** path-filter correctly skipped when `functions/**` is untouched. Locally, `npm run lint` / build / test were green on Node 22 (one intermittent flake observed once).

CI **does not** mark these as skipped to go green. Expect a red Flutter job until they are fixed productively.

### Approximate coverage

From a local `flutter test --coverage` run that still wrote lcov despite failures: **~82.4%** line coverage (19133 / 23218). Numbers on the PR come from the Actions run (see the coverage block).

### Linux CI notes

- `android/gradle.properties` may contain Windows-only `org.gradle.java.home` / `org.gradle.java.installations.paths`. The workflow strips those lines in the runner workspace before `flutter build apk --debug`.
- CI installs **Temurin JDK 17** (`actions/setup-java`) because the app targets Java 17 and newer runner default JDKs (e.g. 25.x on ubuntu-26.04) break AGP `assembleDebug`.

### Golden baselines

Widget goldens live under [`test/goldens/`](../test/goldens/). `docs/screenshots/` stays gitignored (human dumps) and is **not** used as CI baselines.

Rasterization differs across macOS / Windows / Linux — refresh baselines only on Linux:

```bash
gh workflow run update-goldens.yml --ref <branch>
# wait for the run, then:
gh run download <run-id> -n linux-goldens -D test/goldens
```

Workflow: [`.github/workflows/update-goldens.yml`](../.github/workflows/update-goldens.yml).

---

## Artifacts

| Artifact | Contents |
| --- | --- |
| `lcov-info` | `coverage/lcov.info` |
| `changed-dart-files` | List of changed `.dart` paths |
| `app-debug-apk` | Debug APK |

---

## Manual steps for maintainers

1. Merge this PR (or land the workflow on `main`) so subsequent PRs get CI.
2. No secrets are required for the current pipeline. If a future step needs Firebase or signing material, add a repository secret and document it here — CI must still degrade gracefully when the secret is absent.
3. Fix the listed analyzer/test failures over time; do not paper over them with `skip` in CI.
