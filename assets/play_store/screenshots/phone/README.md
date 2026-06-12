# Phone screenshots — capture guide

Place finalized PNG or JPEG files in this folder using the filenames below.  
**Target:** 1080 × 2400 (9:20) or 1080 × 1920 (9:16) — Google Play accepts 320–3840 px per side.

## Filenames (upload order)

| # | File | Screen | How to capture |
|---|------|--------|----------------|
| 1 | `01_collection.png` | **Collection** | Cold launch → Collection tab. Populate shelf with 2–3 series if empty (shows filters + summary). |
| 2 | `02_insights.png` | **Insights** | Collection → tap collector type / journey card → **Insights** page (`CollectionInsightsScreen`). |
| 3 | `03_discover.png` | **Discover** | Discover tab → scroll to show **Latest drops** + **Official updates** rails. |
| 4 | `04_market.png` | **Market** | Market tab → POP MART or Any brand filter → list with prices visible. |
| 5 | `05_figure_detail.png` | **Figure detail** | Collection → open a series → figure gallery or preview sheet with hero art + metadata. |

## ADB quick capture (device connected)

```powershell
# From repo root; unlock phone first
$serial = "<adb-serial>"   # adb devices
$out = "assets/play_store/screenshots/phone"

adb -s $serial shell screencap -p /sdcard/ss.png
adb -s $serial pull /sdcard/ss.png "$out/01_collection.png"
# Navigate to next screen, repeat with 02_… 05_…
```

Optional resize (if capture is not 1080-wide):

```powershell
python -c "from PIL import Image; p=r'assets/play_store/screenshots/phone/01_collection.png'; im=Image.open(p); im.resize((1080, int(im.height*1080/im.width)), Image.Resampling.LANCZOS).save(p)"
```

## Store tips

- Use **light mode** or **dark mode** consistently across all five.
- Hide status bar clutter; full battery/Wi‑Fi is fine.
- No misleading “#1” badges or fake review stars.
- Figure detail shot should feel **image-first** (catalog art or gallery), not a form.
