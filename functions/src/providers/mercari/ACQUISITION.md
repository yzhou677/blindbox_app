# Mercari gateway — acquisition boundary

Three layers (do not collapse):

| Layer | Responsibility | Location |
|-------|----------------|----------|
| **Acquisition** | How raw provider rows are obtained | `runtime/*MercariRuntime.ts` |
| **Normalization** | Provider chaos → stable wire DTO | `mercariNormalize.ts`, `mercariParser.ts` |
| **Gateway response** | HTTP handler, cache, cursor, `meta` | `mercariBrowse.ts` |

The Flutter app only sees the gateway wire contract. It must not depend on acquisition strategy.

## Runtimes

| Strategy | Class | Status |
|----------|-------|--------|
| `fetch` (default) | `FetchMercariRuntime` | HTTP + Mercari search APQ |
| `playwright` | `PlaywrightMercariRuntime` | Reserved — not implemented |
| `fixture` | inline in `mercariBrowse.ts` | Deterministic samples (`MERCARI_GATEWAY_MODE=fixture`) |

Select acquisition for live mode:

```bash
MERCARI_ACQUISITION_RUNTIME=fetch   # default
# MERCARI_ACQUISITION_RUNTIME=playwright  # future browser runtime
```

## Long-term direction

**Product priority:** official marketplace APIs (eBay Browse first). Manual cookie headers and non-official acquisition are **not** the Product path.

Live Mercari internal test is **paused** (gateway fixture-only in production). Code below is retained for future experiments.

Live providers remain a long-term option where official APIs exist or partnerships allow. Browser automation (Playwright/headless) is an acceptable future acquisition strategy for **internal** experiments only — not a scraping platform. Graceful degradation (fixture fallback, calm app UX) remains core.

Manual cookie headers (`MERCARI_EXTRA_HEADERS_JSON`) are a **bridge** for `FetchMercariRuntime`, not the permanent product architecture.
