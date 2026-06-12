# Google Play Data Safety — Shelfy alignment notes

Use this checklist when completing **Play Console → App content → Data safety** for Shelfy (`app.shelfy.collector`). It aligns with [`PRIVACY_POLICY.md`](./PRIVACY_POLICY.md).

**Privacy policy URL (GitHub Pages):** after enabling Pages from `/docs` on `main`:

`https://yzhou677.github.io/blindbox_app/privacy-policy.html`

Replace the GitHub username/org if your Pages URL differs.

---

## 1. High-level declarations

| Play Console question | Recommended answer | Notes |
|----------------------|-------------------|--------|
| Does your app collect or share user data? | **Yes** (limited) | “Collect” in Play terms includes data processed on-device and data received from network APIs, even without accounts. Scope is narrow. |
| Is all user data encrypted in transit? | **Yes** | HTTPS for Firebase and marketplace gateway requests. |
| Can users request data deletion? | **Yes** (device-level) | No cloud account; users delete via in-app edits, **Clear storage**, or uninstall. Explain in the form’s free-text if offered. |
| Independent security review | **No** (unless you have one) | Update if you complete a third-party review. |
| Prominent disclosure / consent | **N/A for account data** | Photo picker is system-mediated; user selects files explicitly. |

---

## 2. Data types — recommended mapping

### A. Data **not collected** (declare **No**)

Shelfy does **not** collect these for Play purposes in the current build:

| Data type | Declare |
|-----------|---------|
| Name | No |
| Email address | No |
| User IDs / account identifiers | No |
| Address | No |
| Phone number | No |
| Race and ethnicity | No |
| Political or religious beliefs | No |
| Sexual orientation | No |
| Other personal info (government ID, etc.) | No |
| Precise location | No |
| Coarse location | No |
| SMS or MMS | No |
| Installed apps | No |
| In-app search history (server-stored, account-linked) | No |
| Browsing history (account-linked) | No |
| Emails | No |
| SMS | No |
| Other messages | No |
| Health info | No |
| Fitness info | No |
| Payment info | No |
| Credit score | No |
| Other financial info | No |
| Health connections | No |
| Fitness connections | No |
| User payment info for purchases **in Shelfy** | No |

---

### B. Data **processed / collected** — declare **Yes** where noted

#### Photos and videos

| Field | Value |
|-------|--------|
| **Collected?** | **Yes** (optional) |
| **Shared?** | **No** |
| **Ephemeral?** | No |
| **Required or optional?** | **Optional** — only when user picks a cover/figure photo |
| **Purpose** | **App functionality** (personal shelf presentation) |
| **Processed on device only?** | **Yes** — stored locally; not uploaded to Shelfy/Firebase for shelf media |

#### App activity (if Play groups local collection state here)

Some forms ask about “other user-generated content.” If your form version lists **Other user-generated content**:

| Field | Value |
|-------|--------|
| **Collected?** | **Yes** |
| **Shared?** | **No** |
| **Purpose** | **App functionality** |
| **On-device only** | **Yes** — collection entries in local storage |

If your form instead treats purely local data as “not collected,” you may answer **No** for server-bound types; **Google’s definition has shifted over time**—when unsure, declare local shelf metadata as collected **on-device, not shared**.

#### App info and performance (diagnostics)

| Field | Value |
|-------|--------|
| **Crash logs / Diagnostics** | **No** unless you add Firebase Crashlytics or similar (not in current scope) |
| **Other app performance data** | **No** unless you enable analytics |

#### Device or other IDs

| Field | Value |
|-------|--------|
| **Device or other IDs** | **No** for Shelfy-operated tracking |
| **Note** | Firebase/Google Play services may process installation/instance identifiers under their own policies; declare per current Google guidance if the form requires third-party SDK disclosure. Shelfy does not use ads SDKs. |

---

### C. Data received from the network (not “user-provided” but disclosed)

Play Console focuses on data **from users**. Still document in policy (already done):

- **Catalog metadata** from Firestore (not personal).
- **Catalog images** from Firebase Storage (not personal).
- **Market listing payloads** from third-party APIs (public listing fields).
- **Official feed URLs** (editorial links).

Typically **do not** mark catalog/market payloads as “personal data collected from the user” unless the form explicitly requires third-party content caching disclosure.

---

## 3. Data sharing

| Question | Answer |
|----------|--------|
| Do you **sell** user data? | **No** |
| Do you **share** user data for advertising? | **No** |
| Do you **share** for analytics today? | **No** (no analytics SDK enabled) |
| Third-party processors | **Google (Firebase)** for catalog delivery; **marketplace API providers** for optional browse. Sharing is **service operation**, not sale. Mark “shared” only if the form treats Firebase processing as sharing user data—in most Shelfy configurations, **personal shelf data is not shared**. |

---

## 4. Security practices (Data safety form)

| Practice | Status |
|----------|--------|
| Data encrypted in transit | **Yes** (HTTPS) |
| Data encrypted at rest (your servers) | **N/A** for user shelf — not stored on your servers |
| Users can request deletion | **Yes** — uninstall / clear app data |
| Committed to Play Families policy | Only if you opt into Designed for Families |

---

## 5. Permissions ↔ policy consistency

Ensure Store Listing and policy match Android behavior:

| Permission / behavior | Policy section |
|----------------------|----------------|
| `INTERNET` | Catalog, Firebase, market browse, official feed |
| Photo picker (runtime) | Optional local shelf photos |
| External browser (`url_launcher`) | Official + market links |

---

## 6. Pre-submission checklist

- [x] Contact email set to `yzhou677@gmail.com` in policy and HTML.
- [ ] Enable **GitHub Pages** (Settings → Pages → Source: `main` / folder: `/docs`).
- [ ] Paste privacy URL into Play Console **Privacy policy** field.
- [ ] Complete **Data safety** using sections 1–4 above.
- [ ] Confirm **no ads SDK** in release `build.gradle` / `pubspec.yaml` before declaring “No ads.”
- [ ] If you add **Firebase Analytics, Crashlytics, or ads**, update policy + this file before next release.

---

## 7. Version stamp

| App version referenced | `1.0.0+4` |
| Package name | `app.shelfy.collector` |
| Policy date | May 29, 2026 |
| Accounts | None |
| Shelf sync | Local only |

---

*This is an internal compliance aid, not legal advice. Have a lawyer review before production launch if your jurisdiction or data practices change.*
