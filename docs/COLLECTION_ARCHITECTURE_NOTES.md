# Collection Architecture Notes

Last updated: 2026-06

This document records intentional Collection architecture decisions, tradeoffs, and future scaling considerations.

The purpose is to preserve design intent and prevent future contributors from accidentally "fixing" behavior that is currently working as designed.

---

## Current Status

Collection is considered:

**Stable / Maintenance Mode**

Core functionality is complete (see also [`ARCHITECTURE_NOTES.md`](ARCHITECTURE_NOTES.md) § Collection Feature Status for the current feature matrix and low-priority deferrals):

* Collection shelf
* Ownership tracking
* Wishlist tracking
* Custom series
* Custom figure support (create, edit, **add figure** from edit sheet)
* Brand filter
* IP filter
* Collection insights
* Collector identity
* Journey system
* Canonicalized custom taxonomy
* Edit custom series
* Input hardening

Future work should prioritize:

* Bug fixes
* UX polish
* Catalog expansion
* Performance profiling

Avoid major architectural rewrites unless real-world usage demonstrates a need.

---

## Intentional Architecture Decisions

### Single Snapshot Persistence

Collection data is stored as a single serialized snapshot in SharedPreferences.

Reasons:

* Simplicity
* Reliability
* Offline-first behavior
* Small expected data volume

Current architecture is considered appropriate for:

* Typical collectors
* Hundreds of figures
* Low-frequency edits

Future scaling should be evaluated using real-world collection sizes rather than theoretical limits.

---

### Collector Identity Is A Snapshot

Collector identity is intentionally not recomputed continuously.

Behavior:

* User explicitly reveals identity
* Identity is cached
* Metadata edits do not automatically overwrite the revealed identity

Reason:

The feature is intended to feel like a collectible personality reveal, not a constantly fluctuating dashboard.

Evolution is surfaced separately through Evolution Hints.

---

### Journey History Is Historical

Journey data represents what happened when actions occurred.

Editing metadata later does not rewrite historical events.

Example:

Series added under:

Baby Three

may later be edited to:

THE MONSTERS

Current shelf:

* Shows THE MONSTERS

Historical journey:

* May still reference Baby Three exploration

This is intentional.

Journey reflects collection history, not current taxonomy state.

---

### ipSeriesDepth Is Add-Time History

`ipSeriesDepth`

tracks the IP associated with a series when it was first introduced into the collection.

It is not currently migrated when a user edits taxonomy metadata.

Reason:

Depth measures exploration history rather than current categorization.

Future migration support may be added if user feedback indicates confusion.

---

### Custom Metadata Ownership

Custom series belong to the user.

Users are allowed to:

* Edit series name
* Edit brand
* Edit IP
* Edit notes
* Change cover image

The application should not attempt to second-guess or override user intent.

Catalog data remains authoritative.

Custom data remains user-controlled.

---

## Known Tradeoffs

### Journey vs Current Shelf

Possible:

Current Shelf ≠ Historical Journey

This is expected.

---

### Collector Identity vs Live Shelf

Possible:

Live Shelf ≠ Cached Identity

This is expected.

Revealing again updates identity.

---

### Snapshot Size Growth

Current storage is optimized for simplicity rather than extreme scale.

Monitor:

* cold start time
* snapshot size
* save latency

before introducing:

* local databases
* split persistence
* paging
* isolate serialization

---

## Future Evaluation Triggers

Consider architecture review if any of the following become common:

* > 200 series
* > 1000 figures
* snapshot size > 1 MB
* noticeable startup delay
* noticeable save delay
* user requests journey history migration
* user confusion around collector identity caching

Until then:

**Prefer simplicity over infrastructure complexity.**
