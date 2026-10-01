# Decisions

One decision per file, numbered: `NNNN-short-title.md`. Record the decisions someone might
want to undo without knowing why they were made: architecture, contracts between services,
tools and process.

A decision is not edited when it changes: add a new one that supersedes it, and set the old
one's status to `Superseded by NNNN`. That keeps the reasoning of each moment.

## Template

```markdown
# NNNN · Title

- Status: Proposed | Accepted | Superseded by NNNN
- Date: YYYY-MM-DD

## Context
What problem there was and which constraints mattered.

## Decision
What was decided, in one or two sentences.

## Alternatives considered
Which other options were weighed and why they were not chosen.

## Consequences
What it implies: what we gain, what it costs and what to watch.
```
