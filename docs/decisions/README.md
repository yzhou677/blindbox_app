# Shelfy Decisions

Durable Shelfy decisions live here.

A feature can be replaced or removed; a decision should still be able to stand.
Use this folder only for product or architecture choices that should survive UI
rewrites, refactors, and implementation churn.

## Structure

- [`architecture/`](architecture/) - ADRs: structural and technical decisions
- [`product/`](product/) - PDRs: collector-facing semantics and product meaning

Do not add more categories without a clear long-term owner.

## When To Add A Decision

Add an ADR or PDR when forgetting the decision would lead a future engineer or
agent to build the wrong product or architecture.

Do not add one for:

- short-lived implementation notes
- UI polish details
- temporary audits
- bug-fix explanations
- formulas that belong in implementation docs

## Format

ADRs should answer: Decision, Context, Rationale, Consequences, Alternatives
Considered.

PDRs should answer: Product Principle, Why, User Impact, Non-goals, Related
Decisions.

Keep records concise. Link to implementation docs instead of copying them.

