# Shelfy Privacy Policy

**Last updated:** May 29, 2026

**App:** Shelfy (`app.shelfy.collector`)  
**Contact:** [yzhou677@gmail.com](mailto:yzhou677@gmail.com)

---

## Introduction

Shelfy is a collectible collection and marketplace companion app. We built it for collectors who want to browse catalog releases, track what they own, and explore market listings—without turning your shelf into a social network or a data product.

This policy explains what information Shelfy handles, where it stays, and what leaves your device. If anything here is unclear, email us at the address above.

---

## Summary

| Topic | What Shelfy does |
|--------|------------------|
| **Your collection** | Stored **on your device only**. We do not sync your shelf to our servers. |
| **Your photos** | Optional cover or figure photos you choose stay **on your device**. |
| **Accounts** | **No** user accounts, logins, or profiles. |
| **Payments** | **No** in-app purchases or payment processing. |
| **Ads** | **No** advertising SDKs are enabled in the app today. |
| **Selling your data** | **We do not sell** your personal information. |
| **Catalog content** | Public-style reference data (brands, series, figures, images) may be loaded from **Google Firebase** (Firestore and Storage). |
| **Market browse** | When enabled, the app may request **listing data from third-party marketplace services** to show browse results. Shelfy does not send your collection contents to those services as part of normal browse. |

---

## Information we do not collect

Shelfy does **not** require you to create an account. We do **not** collect:

- Name, email address, or phone number through the app
- Precise location
- Contacts, calendar, or SMS content
- Health, financial, or government ID information
- Messages between users (there is no social messaging feature)

Because there are no accounts, we do not operate a cloud backup of your personal collection tied to your identity.

---

## Information stored on your device

### Collection data (local only)

When you add series, mark figures as owned or on your wishlist, or create custom entries, that information is saved **locally on your phone or tablet** using the app’s on-device storage (for example, via the platform’s local preferences storage).

- This data **stays on your device** unless you uninstall the app, clear app data, or delete items yourself.
- **Uninstalling Shelfy** typically removes this local collection data.
- We do **not** upload your shelf contents to Firebase or other Shelfy-operated servers.

### Photos you choose (local only)

If you attach a photo to a custom series or figure, Shelfy stores that image **on your device** and references it from your local collection record.

- We do **not** upload your personal photos to Firebase Storage for shelf use.
- Catalog artwork shown in Discover and search is separate public reference media (see below), not your private uploads.

### On-device caches

To improve offline browsing, Shelfy may cache catalog images and catalog bundle data on your device. Cached files are used to display the app faster and can be cleared when you clear app storage or uninstall.

---

## Information loaded from the internet

### Firebase (catalog reference only)

Shelfy uses **Google Firebase** services in a **read-oriented, catalog-only** way:

- **Cloud Firestore** — reference documents such as brands, IPs, series, and figures (release metadata, identifiers, and similar catalog fields).
- **Cloud Storage** — hosted **catalog images** referenced by the app’s image system.

When your device contacts Firebase, Google processes that network traffic under [Google’s Privacy Policy](https://policies.google.com/privacy). Firebase project configuration is tied to the app package; **no Shelfy user account** is created as part of this flow.

We do **not** use Firebase to store your private shelf state in the current version of the app.

### Official updates feed

Discover may show curated “official updates” items loaded from Firestore (`official_feed_items`). These are editorial links and product references (for example, brand announcement URLs), not your personal collection.

### Market browse (optional network feature)

The Market tab may fetch **third-party marketplace listing data** (for example, search and browse results from configured gateway services) so you can explore listings related to collectibles.

- Requests are made to retrieve **public listing information** (titles, prices, images, URLs, and similar fields).
- Shelfy is **not** a checkout or payment flow; purchases happen on external sites or apps if you choose to follow a link.
- We do not design this feature to transmit your local shelf contents as search identity; queries are driven by in-app browse and filter controls.

Third-party services have their own privacy practices. Review their policies if you open an external listing.

### Opening external links

When you tap an official update, market listing, or similar link, Shelfy may open your **system browser** or the relevant external app. Once you leave Shelfy, the other site’s policy applies.

---

## Permissions

Shelfy may request limited device permissions:

| Permission / access | Why |
|---------------------|-----|
| **Internet** | Load catalog data, images, optional market listings, and official feed items. |
| **Photos / media (when you pick an image)** | Let you choose optional cover or figure photos for your **local** collection. Shelfy only accesses images you explicitly select. |

Shelfy does not use your microphone or continuous background location for core features described in this policy.

---

## Children’s privacy

Shelfy is not directed at children under 13 (or the minimum age required in your country). We do not knowingly collect personal information from children. If you believe a child has provided personal information through the app, contact us and we will help address the concern within our technical limits (noting that shelf data is stored locally on the device).

---

## Data retention and deletion

- **Local collection and photos:** Remain on your device until you edit or remove them, clear app data, or uninstall Shelfy.
- **Cached catalog data:** May persist on device until cache is cleared or the app is removed.
- **Server-side catalog:** Maintained by the app operator as reference content, independent of any single user.

Because we do not operate per-user cloud accounts for your shelf, there is no separate “account deletion” step on our servers for collection data—you control deletion on your device.

---

## Security

We use industry-standard practices appropriate for a local-first app: on-device storage for personal collection state, HTTPS for network requests, and Firebase security rules for catalog data access patterns. No method of storage or transmission is 100% secure; please keep your device updated and protected with a screen lock.

---

## International users

Shelfy may be used from different countries. Catalog and market data are fetched over the internet and may be processed by service providers (such as Google Firebase and marketplace API hosts) located in various regions. See those providers’ policies for transfer details.

---

## Changes to this policy

We may update this policy when features, providers, or legal requirements change. We will revise the **Last updated** date at the top. Material changes may also be noted in release notes on Google Play. Continued use after an update means you accept the revised policy.

---

## Your rights and contact

Depending on where you live, you may have rights to access, correct, or delete personal information. Because your collection is stored **locally**, you can review and delete it inside the app or by removing app data.

For privacy questions or requests:

**Email:** [yzhou677@gmail.com](mailto:yzhou677@gmail.com)

Please include your device type and app version if reporting a concern.

---

## Google Play

This policy is provided for Shelfy on Google Play. A web version suitable for GitHub Pages is available at [`privacy-policy.html`](./privacy-policy.html).

For how this maps to Google Play **Data safety** declarations, see [`PRIVACY_POLICY_DATA_SAFETY.md`](./PRIVACY_POLICY_DATA_SAFETY.md).
