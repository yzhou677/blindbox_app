# Immersive collectible presentation (Phase 6)

Calm exhibition pacing — premium restraint, not gamified motion.

## Principles

- **Slower, softer** transitions via shared [`CollectibleMotion`](../lib/core/theme/collectible_motion.dart)
- **Focus states** dim the world around the collectible (gallery scrim, sheet barrier, stage vignette)
- **Image-first** — longer settle fades ([`AppImageStyles.imageFadeIn`](../lib/core/theme/app_image_styles.dart)), softer shimmer
- **No novelty per screen** — sheets, gallery, capsules, and shelf glow all pull from the same tokens

## Shared primitives

| Primitive | Role |
|-----------|------|
| `CollectibleMotion` | Durations, curves, gallery scale, sheet `AnimationStyle` |
| `CollectibleImmersion` | Barrier/scrim colors |
| `CollectiblePresenceFade` | Gentle fade when gallery pages appear |
| `CollectibleSheetFocusFrame` | Soft top gradient on sheet bodies |
| `FeedRhythm.collectionShelfCardGap` | More air between shelf rows |

## Surfaces

- **Figure gallery** — deeper scrim, 0.99 enter scale, presence fade per page, radial vignette on stage
- **Bottom sheets** — softer barrier + `sheetAnimationStyle`
- **Shelf cards** — calmer completion glow (smaller scale hump, longer duration)
- **Figure capsules** — unified press + art crossfade curves

## Non-goals

- AR/VR, particles, 3D gimmicks, addictive scroll mechanics, per-feature animation frameworks
