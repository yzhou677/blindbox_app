---
name: release-check
description: >-
  Checks a Shelfy Play internal release before it starts. Use when the user
  wants to ship, tag a release, run the Release workflow, or asks about
  versionName, versionCode, draft, or a failed release re-run.
---

# Release check

Read [docs/RELEASE.md](../../../docs/RELEASE.md) and follow it. The workflow is [.github/workflows/release.yml](../../../.github/workflows/release.yml). A pull request does not upload to Play.

The store build uses the tag, not `pubspec.yaml`. Bump `pubspec.yaml` in the commit you tag only when the repo version name should match the tag. The workflow does not edit `pubspec.yaml` and does not fail if they differ.

## Steps

1. On clean `main`, confirm the version name you want.
2. If the repo should show that name, set `pubspec.yaml` `version:` to `X.Y.Z+N`. Keep `N` below `100000`. CI versionCode is `100000 + github.run_number`.
3. Tag must be exactly `vX.Y.Z` (`vMAJOR.MINOR.PATCH`). `1.2.3`, `v1.2`, and `v1.2.3-beta` fail before tests.
4. Only a tag that was successfully created cannot be reused. Check with `git ls-remote --tags origin`. If the release fails before the GitHub Release step creates the tag, start a new manual run with the same version. Do not click Re-run. `v1.0.14` already shipped as a draft and that tag exists. The next release needs a new version.
5. Leave `play_status` at **draft**. A tag push is always draft. Use `completed` only after the Play app itself is published, and only on a manual run.
6. Ship from `main` with either:
   - `git tag vX.Y.Z` then `git push origin vX.Y.Z`, or
   - Actions → Release → Run workflow, branch `main`, version `vX.Y.Z`, `play_status` draft.
7. If the run fails, do not click Re-run. A re-run keeps the same versionCode and Play rejects it. If the tag was not created, start a new workflow_dispatch with the same version. If the tag exists, use a new version.

## After a failure

Use the table in [docs/RELEASE.md](../../../docs/RELEASE.md) under "What to check when it fails". The log names a missing secret. It does not print secret values.
