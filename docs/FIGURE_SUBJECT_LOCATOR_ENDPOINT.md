# Figure Subject Locator Endpoint (PR7 Part 3A)

## Boundary

`subjectLocatorV1` is a narrow, App Check-protected Gen 2 callable Function.
It exists only to suggest the initial rectangle for the local subject-framing
sheet. It performs request validation, Sharp EXIF orientation normalization,
the existing `GooglePrimarySubjectLocator`, the existing
`PrimarySubjectCandidateSelector`, and normalized response mapping.

It does not run refinement, blur evaluation, segmentation, crop generation,
embedding, retrieval, recognition, persistence, or Collection/Catalog
mutation.

The bounded client-side encoding is transport-only. The original acquired
local image remains the source of truth for framing coordinates, the confirmed
crop, selected-subject quality evaluation, embedding, and retrieval. A
transport image must never replace `CatalogPhotoSelection.file` downstream.

## Transport and contract

The callable accepts one JSON request:

```json
{
  "version": 1,
  "image": {
    "dataBase64": "...",
    "mimeType": "image/jpeg"
  },
  "requestId": "locator-1"
}
```

Allowed MIME types are JPEG, PNG, and WebP. Decoded payloads are limited to
6 MiB, dimensions to 12,000 pixels per side, and decoded area to 50 megapixels.
No URL, local path, Storage reference, filename, batch, or arbitrary content
type is accepted.

A suggestion response contains only a rectangle in
`normalized_oriented_image` coordinates, oriented dimensions, and locator and
selector contract versions. A valid empty result or unusable structured model
output returns `no_suggestion`. Raw candidates, scores, prompts, model output,
image data, and credentials are never returned.

Recoverable callable errors use sanitized reasons:

- `invalid_request`
- `unsupported_mime_type`
- `payload_too_large`
- `invalid_image`
- `image_dimensions_unsupported`
- `locator_timeout`
- `locator_unavailable`

Flutter maps these into suggestion, no-suggestion, or unavailable gateway
results. Generation-scoped requests prevent a stale response from being used
for a newer photo. PR7 Part 3A provides the gateway but does not yet invoke it
from the framing UI.

## Security and runtime

The function requires Firebase App Check (`enforceAppCheck: true`). Shelfy uses
Play Integrity for Android release builds and App Attest with DeviceCheck
fallback for Apple release builds. Debug builds use Firebase App Check debug
providers. Register debug tokens only in non-production development workflows.
The locator transport is currently mobile-only; web App Check is intentionally
not configured.

The endpoint does not require Firebase Authentication. App Check identifies a
valid Shelfy app instance; it is not a user identity or authorization system.
Abuse is additionally bounded by one image per request, strict payload limits,
45-second function timeout, concurrency 1, and at most 10 instances. Configure
Vertex AI project quotas and budget alerts outside the repository.

Logs contain only success/failure, result status or sanitized reason, and
elapsed time. They never contain bytes, Base64, EXIF, filenames, URLs, raw model
output, candidates, scores, tokens, or credentials.

Runtime configuration:

```text
export: subjectLocatorV1
Functions region: us-central1 (or FUNCTION_REGION)
Vertex location: us (central primary-subject configuration)
timeout: 45 seconds
memory: 1 GiB
concurrency: 1
max instances: 10
authentication: Vertex AI ADC
```

Enable the Vertex AI API. The deployed Functions runtime service account needs
Vertex prediction permission, normally `roles/aiplatform.user`. No API key or
service-account JSON belongs in the repository.

### Android debug-token registration

Debug builds activate `AndroidDebugProvider` immediately after the default
Firebase app is initialized. Release builds use `AndroidPlayIntegrityProvider`
and never run debug-token diagnostics. During debug startup Shelfy forces one
token refresh so the native Android SDK prints a line like this to logcat:

```text
DebugAppCheckProvider: Enter this debug secret into the allow list in the Firebase Console for your project: <secret>
```

The secret is a development credential. Never commit it, paste it into issue
trackers, or include it in shared logs. To register it:

1. Run a debug build of `app.shelfy.collector` on the development device.
2. Capture only the `DebugAppCheckProvider` line, for example:

   ```powershell
   adb logcat -s com.google.firebase.appcheck.debug.internal.DebugAppCheckProvider flutter
   ```

3. Open Firebase Console for `blindbox-collection`.
4. Go to **Build > App Check**, then select **Apps**.
5. Locate the Android app `app.shelfy.collector`.
6. Open its overflow menu and choose **Manage debug tokens**.
7. Add the exact secret printed for this device and give it a descriptive local
   label. Do not paste an App Check JWT, Firebase API key, or placeholder text.
8. Restart the debug app. Startup should print `Debug token exchange succeeded`.
9. If an invalid token was previously registered or the installed app retains a
   stale secret, remove the stale Console entry, clear/reinstall the debug app,
   capture the newly generated secret, and register that exact value.

After registration, invoke both scan steps and verify the Cloud Functions logs
contain `Subject locator request completed` and `Figure recognition request
completed`, with no `app: INVALID` callable-verification entry. Both callable
gateways remain in `us-central1`, and both Functions continue enforcing App
Check.

Before production deployment, configure and enforce Firebase App Check for the
registered Android and Apple apps. Release/Play signing fingerprints required
by the chosen attestation providers must be registered in Firebase as part of
that rollout.

## Build, test, and deploy

From `functions/`:

```powershell
npm run build
npm test
```

Deploy only this export:

```powershell
npm run deploy:subject-locator -- --project blindbox-collection
```

Equivalent command:

```powershell
npx firebase deploy --only functions:market:subjectLocatorV1 --project blindbox-collection
```

Do not use an unscoped `firebase deploy`; the `market` codebase contains other
exports. Automated tests use fakes and never call Firebase, Vertex AI, Storage,
Firestore, or a paid API.
