# Shelfy

> **Display name:** Shelfy (package: `blindbox_app`, application id: `app.shelfy.collector`)

> **Implementation architecture (current codebase):** see [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md).  
> **Stack as built today:** collection persistence uses **SharedPreferences** (not Hive/Isar); market HTTP uses the **`http`** package (Dio is not in use).  
> **Deep dives:** [Catalog architecture](./CATALOG_ARCHITECTURE.md) · [Search architecture](./SEARCH_ARCHITECTURE.md) · [Testing notes](./TESTING.md)

## Project Goal

Build a modern Flutter mobile app for designer toy and blind box collectors.

The app should feel premium, minimal, visual-first, and collection-focused.

Inspired by:
- POP MART
- Collectr
- StockX
- Pinterest
- modern iOS collectible apps

The goal is NOT to build a social media platform.

The goal is to help users:
- track collections
- discover latest drops
- organize collectibles
- monitor market trends

---

# Core Features

## 1. Discover (Home)

A visual discovery surface built on the **read-only catalog universe** (Firestore `brands` / `ips` / `series` / `figures`).

Each release-style row includes:
- image (`imageKey` → resolver)
- name
- series
- brand
- release date

UI style:
- large image cards
- rounded corners
- soft shadows
- modern minimal spacing
- horizontal scrolling sections (latest releases, official drops, trending)

Catalog runtime:
- Firestore is authoritative at runtime; a persisted disk cache provides offline baseline after first successful sync
- Shared **Search V2** (token-based, deterministic) across catalog browse, Add Series, Collection search, and related surfaces
- See [Catalog architecture](./CATALOG_ARCHITECTURE.md) and [Search architecture](./SEARCH_ARCHITECTURE.md)

---

## 2. Market Section

Live marketplace browse via **eBay Browse API** through the Firebase market gateway (`functions/` + client `MarketSource`).

Features (shipped):
- keyword search and brand/IP filters
- paginated listing browse
- listing detail with external “View on eBay”
- price sorting on browse (search stays relevance-first)

Mercari gateway code remains in-repo for internal sandbox use but is **paused for Product** — see [`MERCARI_SANDBOX.md`](./MERCARI_SANDBOX.md).

Market listings are a **separate universe** from catalog reference data and shelf state.

This section should feel lightweight and fast — not a full marketplace.

---

## 3. My Collection

Local-first collection tracking.

No login required for MVP.

Users can:
- add catalog series or custom series to the shelf
- track owned vs wishlist figure states
- save purchase price and notes
- use custom series with canonical taxonomy fields
- filter and sort the shelf (brand, IP, completion-oriented browse)

Collection intelligence (shipped):
- **Summary** — Figures, Wishlist, Completed Series, Master Complete
- **Insights** — at-a-glance progress, collector type reveal, editorial tone
- **Completion tiers** — regular series complete vs all secrets owned (`Master Complete`)

Local persistence (implemented):
- **SharedPreferences** — `CollectionSnapshot` encoded via `collection_snapshot_codec` (schema v2)
- Local-first; no cloud sync in MVP

Collection view should feel like:
- Pinterest
- collectible shelf
- visual gallery

NOT spreadsheet-like.

---

# Design Philosophy

The app should feel:
- cozy
- modern
- visual
- collectible-focused
- emotionally pleasing

Avoid:
- enterprise dashboard style
- cyberpunk UI
- overly technical design
- cluttered screens

Prioritize:
- whitespace
- typography
- large images
- smooth animations
- polished loading states

---

# Navigation

Bottom navigation with 3 tabs (cold start on Collection):

1. **Collection**
2. **Discover**
3. **Market**

---

# Tech Stack

## Framework
Flutter

## State Management
Riverpod

## Routing
go_router

## Local Storage
SharedPreferences (collection snapshot codec)

## Backend (catalog-only)
Firebase Firestore + Storage for read-only catalog metadata and art resolution — not shelf sync

## Networking
`http` package — eBay gateway client in `features/market/data/`; Firebase Functions for market gateway

## Image Caching
cached_network_image; catalog art via `CatalogImageResolver` (`imageKey` only in UI)

---

# Architecture

Current folder structure:

```text
lib/
  core/           # router, theme, layout, Firebase init
  features/       # catalog, collection, home, market (primary slices)
  models/         # legacy shared presentation models (frozen)
  shared/widgets/ # cross-feature UI only
```

See [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md) for boundaries (catalog vs shelf vs market).

Three universes — do not mix:
- **Catalog** — read-only reference
- **Collection** — user-private shelf
- **Market / Home** — listings and discovery surfaces

Use:
- repository pattern
- async state handling
- feature-based structure

Avoid:
- massive widget files
- business logic inside UI
- global mutable state

---

# UI Direction

Inspired by:
- Apple Today cards
- Pinterest grids
- Collectr app
- StockX modern cards

Cards should:
- use large collectible images
- have rounded corners
- feel premium but playful

Animations:
- hero transitions
- smooth page transitions
- shimmer loading states

---

# MVP Scope

DO NOT overbuild.

MVP should only include:
- catalog-backed discovery
- live market listings (eBay)
- local collection tracking with completion and insights surfaces

No:
- social features
- chat
- comments
- authentication
- cloud sync of shelf
- payments

---

# User Pain Points (Research)

Users currently complain about:
- outdated collectible databases
- missing new series
- inability to create custom lists
- using spreadsheets instead of apps
- poor collection organization

The app should prioritize:
- easy browsing
- fast updates
- visual organization
- collectible completeness

---

# Product Personality

The app should feel like:
"A beautiful digital shelf for collectors."

# Development Priority

Prioritize shipping a polished MVP quickly.

Prefer:
- simpler implementations
- clean UI
- maintainable code
- fast iteration

Avoid premature optimization and unnecessary abstractions.

# Theme

Support both light mode and dark mode.

Default design direction should prioritize:
- warm neutral backgrounds
- soft shadows
- collectible-focused visuals

Avoid overly saturated colors.

# Visual Priority

Collectible images are the most important UI element.

Layouts should prioritize:
- large imagery
- clean presentation
- consistent aspect ratios
- smooth image loading

Text should support the visuals, not dominate the screen.

## Current Backend Status

**Catalog:** Firestore + Storage (read-only); offline disk cache after sync; Search V2 over in-memory bundle.

**Collection:** SharedPreferences codec only — local-first, no Firestore sync.

**Market:** eBay Browse via Firebase gateway is the live Product path. Mercari gateway retained but paused.

**Docs to read before changing runtime behavior:**
- [Catalog architecture](./CATALOG_ARCHITECTURE.md)
- [Search architecture](./SEARCH_ARCHITECTURE.md)
- [eBay gateway](./EBAY_GATEWAY.md)
- [Testing notes](./TESTING.md)

## Integration Roadmap (future)

Possible next capabilities (not all shipped):
- sold/completed price research
- additional official marketplace providers beyond eBay
- optional account/sync for shelf (explicit product decision required)
