---
name: env-setup
description: >-
  Sets up a new machine for this Flutter repo. Use when the user clones
  Shelfy, installs Flutter, fixes a local Android JDK, or asks where
  google-services.json and the keystore go.
---

# Environment setup

Follow [docs/FIREBASE_LOCAL_SETUP.md](../../../docs/FIREBASE_LOCAL_SETUP.md) and [docs/RELEASE.md](../../../docs/RELEASE.md). Do not commit secrets.

## Steps

1. Flutter version used by CI is **3.41.9** stable (`.github/workflows/pr-ci.yml`). Check with `flutter --version`. `pubspec.yaml` SDK constraint is `^3.11.5`.
2. Cloud Functions CI uses Node **22** (same workflow).
3. Android SDK path is local. `android/local.properties` is gitignored (`android/.gitignore`). CI installs Temurin JDK 17 because the app targets Java 17.
4. Put the machine JDK in the user Gradle file, not in the repo:

```text
%USERPROFILE%\.gradle\gradle.properties
```

```properties
org.gradle.java.home=<full JDK or Android Studio JBR path>
org.gradle.java.installations.paths=<same path>
```

Do not commit those keys in `android/gradle.properties`. Release CI fails the build if they are present. See [docs/RELEASE.md](../../../docs/RELEASE.md).

5. Firebase Android file, gitignored:

```text
android/app/google-services.json
```

Project `blindbox-collection`. Package `app.shelfy.collector`. Template: `android/app/google-services.json.example`. Tracked Firebase CLI template: `cp firebase.json.example firebase.json` (`firebase.json` is gitignored).

6. Signing stays local. Gitignored:

- `android/key.properties` (`android/.gitignore`)
- `*.jks` and `*.keystore` (`android/.gitignore`, and `*.jks` in the root `.gitignore`)

Release CI builds `key.properties` on the runner from GitHub secrets. It does not write your keystore into the repo.

This repo does not document which JDK folder to use on a given PC. Point the user file at a JDK that actually exists there.
