# Technical Debt — Snapshot Query Volume Optimization

> **Status: Deferred** — do not implement before Sprint 4 is complete.

---

## Observation

Current search-term derivation produces approximately:

- ~1,100+ figures
- ~2–3 search terms per figure
- ~2,300+ eBay queries per full snapshot run

This volume is acceptable during initial development and validation.

---

## Reason For Deferral

The system is not yet operating on real production snapshot data.

The following must be completed first:

1. Live eBay completed-sales fetch working
2. Matcher integrated
3. Aggregator integrated
4. Firestore snapshot persistence integrated
5. At least several production snapshot runs reviewed

Optimization before real-world usage would be premature.

---

## Potential Future Optimizations

### Query Cache

Cache query results by:

- normalized search term
- date window

Avoid re-fetching identical searches during the same run.

### Incremental Refresh

Instead of rebuilding all snapshots:

- fetch only recently changed figures
- refresh figures with new sales activity

### Shared Query Pool

Many figures in the same series generate overlapping searches.

Future architecture may allow:

- query once
- match many figures

instead of:

- query per figure

### Snapshot Scheduling

Support:

- daily snapshot
- weekly full rebuild

instead of full-catalog fetch every run.

---

## Trigger For Re-Evaluation

Revisit only if:

- runtime becomes problematic
- API quota becomes constrained
- operational costs become noticeable
- production metrics justify optimization

**After Sprint 2 Step 3C (matcher + aggregator pipeline):** evaluate the following **before any production-scale snapshot runs**:

- query cache (normalized search term + date window, within a single run)
- cross-run cache (reuse fetch results across scheduled runs)
- incremental refresh (figures with new sales activity only)
- query deduplication across figures (shared query pool — query once, match many)

Full catalog scale today: **~1,144 figures** and **~2,300 search queries** per run.

Until then:

**Prefer correctness and maintainability over optimization.**
