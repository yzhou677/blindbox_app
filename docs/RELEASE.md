# Shelfy Android release

This is the Play **internal** track pipeline. It does not publish to
production.

The workflow is [`.github/workflows/release.yml`](../.github/workflows/release.yml).
It runs only when you push a tag like `v1.2.3`, or when you start it by hand
from the Actions tab. Opening a pull request does **not** upload anything.
[`.github/workflows/pr-ci.yml`](../.github/workflows/pr-ci.yml) is unchanged and
still builds a debug APK with the CI stub `google-services.json`.

## What a release uses for its version

| Piece | Where it comes from | Example |
| --- | --- | --- |
| versionName | The tag, with the leading `v` removed | tag `v1.2.3` → `1.2.3` |
| versionCode | `100000 + github.run_number` | run 1 → `100001` |

`pubspec.yaml` is `version: 1.0.14+27` today. Flutter maps the name to
Android `versionName` and the number after `+` to `versionCode`. That `27` is
the last **manual** build number. The release workflow does not read it and
does not edit `pubspec.yaml`. It passes `--build-name` and `--build-number`
for that one build.

`github.run_number` on a new workflow starts at 1. Play rejects a versionCode
that is not higher than the newest upload, so `1` cannot be used while `27`
may already be on Play. `100000 + run_number` stays above the pubspec build
number. Failed runs leave gaps. Gaps are fine. A lower code is not.

Keep hand-built versionCodes below `100000`. Do not set the pubspec `+`
number to `100000` or higher, or a local upload can collide with CI.

Bump `pubspec.yaml` yourself in the commit you tag if you want the repo to
show the same version name. The store build still follows the tag.

## How to ship

From a clean `main`:

```bash
git checkout main
git pull
git tag v1.2.3
git push origin v1.2.3
```

Rules for the tag:

- Exactly `vMAJOR.MINOR.PATCH`, for example `v1.2.3`.
- `1.2.3`, `v1.2`, and `v1.2.3-beta` fail when the version is parsed, before
  analyze and tests. Nothing is uploaded.
- Do not reuse a tag name. Play can take another versionCode, but the GitHub
  Release for that tag already exists.

Manual run (same job, no need to push a tag first):

1. GitHub → **Actions** → **Release** → **Run workflow**.
2. Branch must be **main**. Any other branch stops immediately.
3. Input `version`: `v1.2.3`.
4. Input `play_status`: leave **draft** unless the Play app is already
   published. See [Play upload status](#play-upload-status).

A tag push has no `play_status` input. It always uploads as **draft**.

That run creates the tag on the `main` commit it checked out. The tag push
does not start a second release: GitHub does not re-fire workflows from
`GITHUB_TOKEN`.

## What the job does

1. Require every secret listed below, immediately after checkout and before
   Flutter is installed. A missing secret fails in about a minute. The log
   names it. Secret values are not printed. Nothing is built.
2. Parse the tag after Flutter is on PATH and before analyze. An illegal or
   missing tag stops the job before the test suite.
3. `flutter analyze`, then the full `flutter test` suite. A failure stops
   the job. No AAB, no Play upload, no GitHub Release.
4. Decode the upload keystore into the runner temp directory, and point
   `android/key.properties` `storeFile` at that absolute path. Decode the
   real `google-services.json`. The PR CI stub is not used.
5. `flutter build appbundle --release` with the tag versionName and the CI
   versionCode.
6. Upload the AAB to the Play **internal** track only. Status is **draft**
   unless a manual run chooses `completed`.
7. Create a GitHub Release on that tag, attach the AAB, and generate notes
   from pull requests merged since the previous tag.
8. Delete `android/key.properties`, the temp keystore, and
   `google-services.json` even when a later step failed.

## Play upload status

The upload step uses `status: ${{ inputs.play_status || 'draft' }}`.

| How you start the job | Play status |
| --- | --- |
| Push a `v1.2.3` tag | `draft` |
| Actions → Run workflow, leave the default | `draft` |
| Actions → Run workflow, choose `completed` | `completed` |

While the app in Play Console is still a **draft app**, the API only accepts
`draft`. `completed` is rejected. After a draft upload, open Play Console and
roll that internal release out yourself. The workflow does not click rollout.

After the app is published (it is no longer a draft app), a manual run can
choose `completed`. Tag pushes stay `draft` until you change the workflow.

## Do not Re-run a failed release

Do not click **Re-run failed jobs** or **Re-run all jobs**.

A re-run keeps the same `github.run_number`. versionCode is
`100000 + run_number`, so the new AAB has the same versionCode Play already
saw, and Play rejects it.

Start a new run instead:

- Actions → **Release** → **Run workflow** again (a new dispatch gets a new
  run number), or
- Push a new tag.

The old AAB is still on the failed run as an artifact if the build step
finished. Downloading it does not change the versionCode. Uploading that
same file again hits the same Play rejection.

Local release builds are unchanged. `android/app/build.gradle.kts` uses
`android/key.properties` when that file exists, and otherwise signs release
with the debug key. CI creates the file on the runner. Your machine does
not get a keystore from CI. `key.properties` stays gitignored.

## Secrets

Add these under **GitHub → Settings → Secrets and variables → Actions**.
Repository secrets are enough. Do not commit any of these files.

| Secret | What to paste | Encoding |
| --- | --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Upload keystore (`.jks`) | one-line base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore store password | plain text, one line |
| `ANDROID_KEY_ALIAS` | Key alias. Local file uses `upload` | plain text |
| `ANDROID_KEY_PASSWORD` | Key password | plain text, one line |
| `GOOGLE_SERVICES_JSON_BASE64` | Real `android/app/google-services.json` | one-line base64 |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play service-account JSON key | **raw JSON**, not base64 |

`GOOGLE_SERVICES_JSON_BASE64` must be the Firebase Android config for package
`app.shelfy.collector`. The job checks the package name and stops if it does
not match. It does not print the file.

### Base64 (Windows PowerShell)

Run this in the folder that contains the file. The output is one line with
no newline. Paste that entire line into the secret.

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Content -NoNewline -Encoding ascii keystore.b64.txt
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\google-services.json")) | Set-Content -NoNewline -Encoding ascii google-services.b64.txt
```

Delete `keystore.b64.txt` and `google-services.b64.txt` after the secrets are
saved. Do not commit them.

### Base64 (bash)

```bash
base64 -w 0 upload-keystore.jks > keystore.b64.txt
base64 -w 0 android/app/google-services.json > google-services.b64.txt
```

macOS `base64` has no `-w`. Use this instead:

```bash
base64 < upload-keystore.jks | tr -d '\n' > keystore.b64.txt
base64 < android/app/google-services.json | tr -d '\n' > google-services.b64.txt
```

Delete the `.b64.txt` files after pasting.

## Play Console (one-time)

Package name must stay `app.shelfy.collector`.

1. In [Google Cloud Console](https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com),
   select the project you want the service account to live in and **Enable**
   the Google Play Android Developer API.
2. **IAM & Admin → Service accounts → Create service account**. Do not grant
   it project IAM roles. Open the account → **Keys → Add key → JSON**. That
   downloaded file is `PLAY_SERVICE_ACCOUNT_JSON` (the whole file, raw).
3. Play Console → **Users and permissions → Invite new users**. Paste the
   service account email (`…@….iam.gserviceaccount.com`).
4. **App permissions → Add app → Shelfy**. Check:
   - **View app information**
   - **Release apps to testing tracks**
5. Do not check production release permissions. This account should not be
   able to ship the production track.
6. Invite the user.

This pipeline uploads only to Internal testing because the workflow sets
`track: internal`. The Play permission above can cover other testing tracks.
The workflow is what keeps this job on Internal. Do not change that track.

### First AAB is manual

The Play Developer API cannot create the app. If Play has never seen an AAB
for `app.shelfy.collector`, the action fails with **Package not found**.

Do this once:

1. Build a signed AAB locally (`flutter build appbundle --release`) with your
   real `android/key.properties` and `google-services.json`.
2. Play Console → **Test and release → Testing → Internal testing → Create
   release**.
3. Upload that AAB and roll the internal release out.
4. After that, tag pushes can upload.

If an internal release already exists for this package, skip this step.

## What to check when it fails

| Log says | What it means |
| --- | --- |
| `Missing GitHub Actions secret(s): …` | That secret is empty. The job stops before Flutter setup. Nothing was built. Add it, then start a **new** run. Do not Re-run. |
| `PLAY_SERVICE_ACCOUNT_JSON must be the raw service-account JSON` | The secret is base64 or not JSON. Paste the `.json` file contents. |
| `GOOGLE_SERVICES_JSON_BASE64 did not decode to JSON` | Bad base64, or the secret is the raw JSON. Encode the file. |
| `no Android client for app.shelfy.collector` | Wrong Firebase app. Use the Shelfy Android config, not the CI stub. |
| `No release tag` / `Illegal release tag` | Tag was not `v1.2.3`. Analyze and tests did not run. Nothing was uploaded. |
| `Manual release must be started from main` | workflow_dispatch was pointed at another branch. |
| `flutter analyze` or `flutter test` failed | Fix the code. The job stops before signing. |
| `Package not found` | First AAB was never uploaded by hand. See above. |
| Version code has already been used | The run reused a versionCode. Do not click Re-run. See [Do not Re-run a failed release](#do-not-re-run-a-failed-release). |
| Play says the upload certificate does not match | `ANDROID_KEYSTORE_BASE64` is not the upload keystore enrolled in Play App Signing. |

The AAB is also saved as a workflow artifact named
`shelfy-vX.Y.Z-<versionCode>` before the Play upload. If Play fails, download
that artifact. It is not uploaded to production.

## What this does not do

- No production track, no staged rollout percentage.
- No iOS build.
- No Firebase rules or Cloud Functions deploy. See
  [`FIREBASE_LOCAL_SETUP.md`](FIREBASE_LOCAL_SETUP.md).
- No Play listing screenshots. See [`PLAY_STORE_ASSETS.md`](PLAY_STORE_ASSETS.md).
- No change to the manual test gate in [`TESTING.md`](TESTING.md). CI runs
  `flutter analyze` and `flutter test` again on the tag.
