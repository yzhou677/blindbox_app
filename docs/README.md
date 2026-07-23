# Documentation Index

Human-oriented notes for the Shelfy app.

Repository documentation should fit one of four roles:

1. **README** - project introduction and orientation
2. **Decision** - durable "why" in ADRs and PDRs
3. **Architecture** - current implementation, ownership, data flow, operations
4. **Archive** - historical reports, completed phases, release-specific notes

Avoid creating documents that mix past, current implementation, and durable
product philosophy without naming which role they serve.

## Entry Points

- Project introduction: [`../README.md`](../README.md)
- AI agent entry point: [`../AGENTS.md`](../AGENTS.md)
- Durable decisions: [`decisions/`](decisions/)
- Current architecture: [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md)
- Historical archive: [`archive/`](archive/)

**GitHub Pages:** [Site home](https://yzhou677.github.io/blindbox_app/) -
[Privacy Policy (HTML)](privacy-policy.html)

## Decisions

- [`decisions/`](decisions/) - ADRs and PDRs
- [`ADR-001: Recommendation Semantics`](decisions/architecture/ADR-001-recommendation-semantics.md)
- [`PDR-001: Collector Type Semantics`](decisions/product/PDR-001-collector-type-semantics.md)
- [`PDR-002: Completion Semantics`](decisions/product/PDR-002-completion-semantics.md)
- [`PDR-003: Dreamer Semantics`](decisions/product/PDR-003-dreamer-semantics.md)

## Current Architecture And Implementation

- [`figure-recognition.md`](figure-recognition.md) - **canonical** Figure
  Recognition product + architecture guide (pipeline, policy, UX, navigation)
- [`CATALOG_ARCHITECTURE.md`](CATALOG_ARCHITECTURE.md) - catalog runtime, cache,
  providers, Search V2, availability UX
- [`SEARCH_ARCHITECTURE.md`](SEARCH_ARCHITECTURE.md) - search normalization,
  token AND, haystack, ranking
- [`COLLECTION_ARCHITECTURE_NOTES.md`](COLLECTION_ARCHITECTURE_NOTES.md) -
  Collection implementation notes, resolver policy, thresholds, compatibility
- [`ARCHITECTURE_NOTES.md`](ARCHITECTURE_NOTES.md) - operational architecture
  notes, performance baselines, market identity notes
- [`PROJECT_OVERVIEW.md`](PROJECT_OVERVIEW.md) - product outline and current scope
- [`TESTING.md`](TESTING.md) - current automated and smoke verification guidance
- [`FIGURE_RECOGNITION_ENDPOINT.md`](FIGURE_RECOGNITION_ENDPOINT.md) -
  `recognizeFigureV1` callable contract and deploy notes
- [`FIGURE_SUBJECT_LOCATOR_ENDPOINT.md`](FIGURE_SUBJECT_LOCATOR_ENDPOINT.md) -
  `subjectLocatorV1` framing suggestion callable
- [`FIGURE_RECOGNITION_PR7.md`](FIGURE_RECOGNITION_PR7.md) - local whole-image
  quality precheck and scan intake behavior
- [`KNOWN_RUNTIME_NOTES.md`](KNOWN_RUNTIME_NOTES.md) - debug/logcat triage
- [`TECH_DEBT.md`](TECH_DEBT.md) - non-blocking debt and future triggers
- [`FIREBASE_LOCAL_SETUP.md`](FIREBASE_LOCAL_SETUP.md) - Firebase local setup and
  release checklist
- [`EBAY_GATEWAY.md`](EBAY_GATEWAY.md)
- [`MERCARI_GATEWAY_FUNCTIONS.md`](MERCARI_GATEWAY_FUNCTIONS.md)
- [`MERCARI_SANDBOX.md`](MERCARI_SANDBOX.md)

Feature implementation notes that describe current shipped surfaces:

- [`COLLECTION_EMOTIONAL_INTELLIGENCE.md`](COLLECTION_EMOTIONAL_INTELLIGENCE.md)
- [`COLLECTION_PERSONAL_MEMORY.md`](COLLECTION_PERSONAL_MEMORY.md)
- [`COLLECTIBLE_RELATIONSHIP_SURFACES.md`](COLLECTIBLE_RELATIONSHIP_SURFACES.md)
- [`COLLECTIBLE_IMMERSIVE_PRESENTATION.md`](COLLECTIBLE_IMMERSIVE_PRESENTATION.md)
- [`COLLECTIBLE_MARKET_INTELLIGENCE.md`](COLLECTIBLE_MARKET_INTELLIGENCE.md)

Release/store references:

- [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md)
- [`privacy-policy.html`](privacy-policy.html)
- [`PRIVACY_POLICY_DATA_SAFETY.md`](PRIVACY_POLICY_DATA_SAFETY.md)
- [`PLAY_STORE_ASSETS.md`](PLAY_STORE_ASSETS.md)

Legacy pointer retained for old links:

- [`RECOMMENDATION_SEMANTICS.md`](RECOMMENDATION_SEMANTICS.md) - points to
  ADR-001

## Historical figure-recognition milestones

These remain useful engineering history. Prefer
[`figure-recognition.md`](figure-recognition.md) for current production behavior.

- [`FIGURE_RECOGNITION_M1.md`](FIGURE_RECOGNITION_M1.md)
- [`FIGURE_RECOGNITION_M2.md`](FIGURE_RECOGNITION_M2.md)
- [`FIGURE_RETRIEVAL_M3.md`](FIGURE_RETRIEVAL_M3.md)
- [`FIGURE_RECOGNITION_PR4.md`](FIGURE_RECOGNITION_PR4.md)
- [`FIGURE_RECOGNITION_PR5.md`](FIGURE_RECOGNITION_PR5.md)
- [`FIGURE_RECOGNITION_EVALUATION.md`](FIGURE_RECOGNITION_EVALUATION.md)
- [`FIGURE_RECOGNITION_CALIBRATION.md`](FIGURE_RECOGNITION_CALIBRATION.md) -
  calibration tooling; production thresholds summarized in
  `figure-recognition.md`

## Archive

- [`archive/`](archive/) - historical reports, release-specific plans, completed
  phase notes, and generated report snapshots

## Agent Navigation

- [`../AGENTS.md`](../AGENTS.md)
- [`../lib/features/collection/insights/AGENTS.md`](../lib/features/collection/insights/AGENTS.md)
- [`CURSOR_RULES.md`](CURSOR_RULES.md)
- [`.cursor/rules/`](../.cursor/rules/)

