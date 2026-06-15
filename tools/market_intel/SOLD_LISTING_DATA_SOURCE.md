# Technical Debt — Sold Listing Data Source Migration

> **Status: Blocked by external platform limitations**

---

## Background

Sprint 2 Step 3B.1 investigation confirmed:

- Legacy Finding API is decommissioned
- `findCompletedItems` is unavailable
- Current OAuth credentials function correctly
- Browse API returns active listings only
- Marketplace Insights access has not been granted

This is not a code defect.

This is a platform capability issue.

Probe tool: [`debug_ebay_live_probe.mjs`](./debug_ebay_live_probe.mjs)

---

## Current Development Strategy

Continue development using:

- fixture mode
- matcher
- aggregator
- snapshot persistence

until a production sold-listing source becomes available.

---

## Candidate Future Solutions

### Option A — Marketplace Insights API

Requirements:

- eBay approval
- `buy.marketplace.insights` scope

Preferred official solution.

Endpoint (when granted): `GET /buy/marketplace/insights/v1_beta/item_sales/search`

### Option B — Third-party sold listing provider

Examples:

- Apify
- marketplace data vendors

Requires separate evaluation of:

- cost
- reliability
- TOS compliance

### Option C — Alternative market intelligence architecture

Use active listings plus historical snapshots instead of completed sales.

Requires separate product review.

---

## Revisit Trigger

Re-evaluate after:

- snapshot pipeline is complete
- production architecture is stable
- Marketplace Insights access decision is known
