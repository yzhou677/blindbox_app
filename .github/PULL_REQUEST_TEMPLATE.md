# Summary

> One or two paragraphs describing the overall purpose of the PR.
>
> Focus on the product outcome rather than the implementation.
>
> A reviewer should understand what this PR accomplishes without reading the code.

---

# Background

Describe the problem this PR solves.

Helpful questions:

- What was difficult before?
- Why wasn't the previous behavior sufficient?
- Why is this worth changing?

Avoid describing implementation here.

---

# User Impact

How does this improve the experience for collectors?

Focus on user-visible behavior.

Example:

- Faster browsing
- More trustworthy data
- Better discoverability
- Simpler workflows
- Clearer navigation

---

# Product Decisions

Document important product principles or trade-offs.

If this PR changes a durable product semantic, update or add a PDR under
`docs/decisions/product/`. If it changes a durable architecture decision, update
or add an ADR under `docs/decisions/architecture/`.

Examples:

### Collection sorting is flat per bucket (no hidden IP ordering).

### Official content is curated, not algorithmic.

### Collector identity is a reveal, not a live scoreboard.

### Discover is exploration-first.

This section should explain **why the product behaves this way**, not simply what the code does.

---

# Technical Design

Explain the architecture behind the feature.

Useful topics:

- major components
- data flow
- provider/notifier boundaries
- persistence
- performance considerations
- important invariants

Prefer describing responsibilities over listing files.

---

# Performance

Only include meaningful performance considerations.

Examples:

- caching
- debounce
- lazy rendering
- reduced rebuilds
- bounded memory
- async loading
- optimistic updates

If there are no meaningful performance implications, simply write:

> No meaningful performance impact beyond the normal declarative rebuild model.

---

# Testing

Describe how the feature was verified.

Examples:

- Unit tests
- Widget tests
- Integration tests
- Manual verification
- Edge cases

---

# Notes

Optional.

Capture architectural intent, future extensibility, or important boundaries that reviewers should understand.

Examples:

- future extension points
- intentional limitations
- ADR references
- non-goals
