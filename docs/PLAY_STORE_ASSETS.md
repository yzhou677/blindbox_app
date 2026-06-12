# Google Play Store listing assets — Shelfy

**Package:** `app.shelfy.collector`  
**Brand purple:** `#6652A5` (primary), `#252030` (deep background)  
**Regenerate rasters:** `python tools/play_store/generate_listing_assets.py`

---

## Generated assets (ready to upload)

| Asset | Spec | File | Status |
|-------|------|------|--------|
| **High-res app icon** | 512 × 512 PNG, ≤ 1 MB, 32-bit | [`assets/play_store/icon_512.png`](../assets/play_store/icon_512.png) | ✅ Generated from current logo |
| **Feature graphic** | 1024 × 500 PNG or JPEG, ≤ 15 MB | [`assets/play_store/feature_graphic_1024x500.png`](../assets/play_store/feature_graphic_1024x500.png) | ✅ Generated (Shelfy + messaging) |

### Feature graphic copy (on-art)

- **Shelfy**
- Track your collectibles
- Discover new releases
- Explore the market

---

## Phone screenshots (required: 2–8)

Capture into [`assets/play_store/screenshots/phone/`](../assets/play_store/screenshots/phone/) using the plan below.

| Upload order | Filename | Screen |
|--------------|----------|--------|
| 1 | `01_collection.png` | Collection shelf |
| 2 | `02_insights.png` | Collection Insights |
| 3 | `03_discover.png` | Discover (Latest + Official) |
| 4 | `04_market.png` | Market browse |
| 5 | `05_figure_detail.png` | Figure gallery / preview detail |

**Recommended capture size:** 1080 × 2400 px (portrait)  
**Accepted range:** 320–3840 px per side; aspect between 16:9 and 9:16  
**Format:** PNG or JPEG, ≤ 8 MB each  

See [`assets/play_store/screenshots/phone/README.md`](../assets/play_store/screenshots/phone/README.md) for navigation + ADB steps.

---

## Tablet screenshots (captured)

**Emulator:** Pixel Tablet · Android 15 (API 35) · landscape **2560 × 1600**

| Upload order | 10" file (`tablet_10/`) | 7" file (`tablet_7/`) | Screen |
|--------------|-------------------------|------------------------|--------|
| 1 | `01_collection.png` | `01_collection.png` | Collection |
| 2 | `02_insights.png` | `02_insights.png` | Insights |
| 3 | `03_discover.png` | `03_discover.png` | Discover |
| 4 | `04_market.png` | `04_market.png` | Market |
| 5 | `05_figure_detail.png` | `05_figure_detail.png` | Figure detail |

| Slot | Spec | Status |
|------|------|--------|
| **10-inch tablet** | shortest side ≥ 1200 px | ✅ `2560 × 1600` native |
| **7-inch tablet** | shortest side ≥ 1080 px | ✅ `1920 × 1080` export |

Regenerate: `python tools/play_store/capture_tablet_screenshots.py`

## Other optional Play assets

| Asset | Spec | Notes |
|-------|------|--------|
| Promo video | YouTube URL | — | Optional; 30s max recommended |
| TV banner | 1280 × 720 | `tv_banner_1280x720.png` | Only if Android TV listed |

---

## Play Console upload map

| Console section | Upload this file |
|-----------------|------------------|
| **Main store listing → App icon** | `assets/play_store/icon_512.png` |
| **Main store listing → Feature graphic** | `assets/play_store/feature_graphic_1024x500.png` |
| **Main store listing → Phone screenshots** | `screenshots/phone/01_…` … `05_…` |
| **Store listing → 10-inch tablet** | `screenshots/tablet_10/01_…` … `05_…` |
| **Store listing → 7-inch tablet** | `screenshots/tablet_7/01_…` … `05_…` |
| **Privacy policy** | `https://yzhou677.github.io/blindbox_app/privacy-policy.html` |
| **Short description** (80 chars) | See release notes / listing copy in prior session |
| **Full description** | See release notes / listing copy |

---

## Short & full description (reference)

**Short (≤ 80 characters)**

```
Track blind boxes & designer toys. Browse drops, build your shelf, explore market.
```

**Full description** — use the English Play listing copy from project release notes, or:

```
Shelfy is a collectible collection and marketplace companion.

• My collection — track series, figures, owned & wishlist; works offline
• Discover — latest catalog drops, trending series, official POP MART updates
• Market — browse listings and search when live gateway is enabled

Image-first, calm UI built for collectors. Your shelf stays on your device.
```

---

## Brand checklist before submit

- [ ] Icon matches launcher (`assets/images/app_icon.png`) — no seasonal variant
- [ ] Feature graphic readable at thumbnail size (no text below ~24px effective height)
- [ ] All five phone screenshots same theme (all light or all dark)
- [ ] No personal data visible in screenshots (real names, DMs, etc.)
- [ ] Contact email in policy: `yzhou677@gmail.com`

---

## File tree (submission bundle)

```
assets/play_store/
├── icon_512.png                    # Play Console app icon
├── feature_graphic_1024x500.png    # Play Console feature graphic
└── screenshots/
    ├── phone/                      # Phone (capture from device)
    ├── tablet_10/                  # 2560×1600 — 10" Play slot
    └── tablet_7/                   # 1920×1080 — 7" Play slot

tools/play_store/
├── generate_listing_assets.py      # Icon + feature graphic
└── capture_tablet_screenshots.py   # Tablet emulator captures
```

---

*Raster specs per [Google Play graphic assets](https://support.google.com/googleplay/android-developer/answer/9866151) as of 2026.*
