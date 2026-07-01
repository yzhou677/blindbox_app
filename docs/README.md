# Documentation index

Human-oriented notes for the Blindbox app. **Agent rules and architecture live under `.cursor/`, not here.**

## In this folder

- [`CATALOG_ARCHITECTURE.md`](CATALOG_ARCHITECTURE.md) — **canonical** catalog spec (Firestore → cache → providers, Search V2, availability UX)
- [`SEARCH_ARCHITECTURE.md`](SEARCH_ARCHITECTURE.md) — **canonical** search spec (normalization, token AND, haystack, ranking)
- [`PROJECT_OVERVIEW.md`](PROJECT_OVERVIEW.md) — product goals and feature outline
- [`ARCHITECTURE_NOTES.md`](ARCHITECTURE_NOTES.md) — recent architecture decisions (catalog sync, market identity, figure IDs, brand/IP rules, collection scope, **dashboard performance baseline**)
- [`KNOWN_RUNTIME_NOTES.md`](KNOWN_RUNTIME_NOTES.md) — logcat / debug noise vs actionable failures (Firebase, images, Android)
- [`TESTING.md`](TESTING.md) — emulator smoke scripts, ADB `input text` (`%s` for spaces)
- [`TECH_DEBT.md`](TECH_DEBT.md) — non-blocking debt items (analyzer warnings, cleanup when convenient)
- [`COLLECTION_ARCHITECTURE_NOTES.md`](COLLECTION_ARCHITECTURE_NOTES.md) — intentional Collection decisions, tradeoffs, and scaling triggers (maintenance mode)
- [`FIREBASE_LOCAL_SETUP.md`](FIREBASE_LOCAL_SETUP.md) — Firebase local setup, services scope, and **release checklist**
- [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) — consumer privacy policy (Play Store / GitHub Pages)
- [`privacy-policy.html`](privacy-policy.html) — HTML version for GitHub Pages
- [`PRIVACY_POLICY_DATA_SAFETY.md`](PRIVACY_POLICY_DATA_SAFETY.md) — Google Play Data safety alignment notes
- [`PLAY_STORE_ASSETS.md`](PLAY_STORE_ASSETS.md) — Play listing icons, feature graphic, screenshot plan
- [`CURSOR_RULES.md`](CURSOR_RULES.md) — pointer to where Cursor rules and architecture actually live

## For Cursor agents and contributors

- **Architecture:** [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md)
- **Rules:** [`.cursor/rules/`](../.cursor/rules/)
- **Checklist:** [`.cursor/CONFORMITY_AUDIT.md`](../.cursor/CONFORMITY_AUDIT.md)
