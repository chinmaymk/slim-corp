# 01 — Model

## Concepts

| Term | Definition |
|---|---|
| Expert | Named, scoped body of project knowledge. One directory under `.experts/`. |
| Scope | Globs of repo paths an expert covers. |
| Trigger | Lowercase term that routes task text to an expert. |
| Always expert | The single project-wide expert (`always: true`), loaded on every route. |
| Rule | Durable, promoted statement in an expert. Has ID, section, confirmations, verified date, sources. |
| Lesson | Recorded observation awaiting promotion. Has ID, text, evidence, kind, confirmations. |
| Evidence | Reference justifying a lesson: path, path:line(s), commit, pr, issue, user. |
| Decision | Question the binary needs answered before completing a write. |
| Loop | Multi-step procedure (init, curate, spawn, verify) executed one task at a time. |
| Task | One step of a loop handed to the agent. |
| Inbox | Raw lessons written without the binary. |
| Event | Append-only log entry recording a state change. |

## Invariants

- I1 Files are the source of truth for content (experts, rules, lessons). The log is the source of truth for history, pending decisions, and loop state. The binary never rebuilds content from the log.
- I2 Every lesson has ≥1 valid evidence ref at record time.
- I3 Every rule is traceable: `src` lists evidence refs (or `-` for hand-written rules); source lesson IDs are in its `rule.promoted` event.
- I4 Rule text/section changes only via: curate tasks, verify tasks, `promote`, `forget`, `resolve` of a similar decision (`merge:R-* --text`, `replace:R-*`), init confirm-seeds, or a human editing the file. `c`/`v` additionally change via duplicate records and `affirm`.
- I5 No write happens outside `.experts/` except `init` (pointer files, AGENTS.md block, `.gitattributes`, `.gitignore`).
- I6 Exactly one active loop per repo.
- I7 IDs are unique within the repo across all kinds and all time (log included).
- I8 Every state change appends ≥1 event.
- I9 Binary output is deterministic for identical repo state, arguments, `EXPERTS_NOW`, and `EXPERTS_SEED`.
- I10 Hand edits are legal. The binary tolerates and repairs (`check --fix`) but never discards unknown content.

## Lifecycles

### Lesson

| From | Trigger | To | Event |
|---|---|---|---|
| — | record, no similar | open | lesson.recorded |
| — | record, duplicate | (not created; target c+1) | lesson.confirmed |
| — | record, related | pending | lesson.recorded + decision.opened |
| pending | resolve distinct, or decision expired | open | decision.resolved / decision.expired |
| pending | resolve merge:X | removed; X.c += c | decision.resolved + lesson.merged |
| pending | resolve replace:X | X lesson: X removed, subject → open. X rule: rule rewritten from subject, subject removed | decision.resolved + lesson.replaced / rule.edited |
| pending | resolve discard | removed | decision.resolved + lesson.discarded |
| open | curate promote | removed; rule created/updated | rule.promoted |
| open | curate triage discard, forget | removed | lesson.discarded |
| open | spawn, split, merge, triage move | moved to other expert | lesson.moved |

### Rule

| From | Trigger | To | Event |
|---|---|---|---|
| — | promote (curate, `promote`, init seed confirm) | active | rule.promoted |
| active | duplicate lesson recorded | c+1, v=today | lesson.confirmed |
| active | verify holds / `affirm` | v=today | rule.verified |
| active | verify edit, replace decision, compress rewrite | text changed, v=today | rule.edited |
| active | split/merge | moved | rule.moved |
| active | verify obsolete, forget, compress drop | removed | rule.retired |

### Expert

| From | Trigger | To | Event |
|---|---|---|---|
| — | init confirm, spawn, split | active | expert.created |
| active | rename | active (new name) | expert.renamed |
| active | curate fix-scope, merge (as target), split (reused name) | active | expert.updated |
| active | merge (as source), split (as source), forget | removed (dir deleted) | expert.retired |

The `always` expert (default name `project`, scope `**`) holds project-wide knowledge; routed on every task; never scored, merged, or split.

`_unassigned` is a pseudo-expert: holds lessons only, never rules, never routed, never retired.

### Decision

| From | Trigger | To | Event |
|---|---|---|---|
| — | record finds related candidate or ambiguous expert | open | decision.opened |
| open | resolve | closed | decision.resolved |
| open | age > `decision_ttl_days` (checked lazily on any command) | closed, default option applied | decision.expired |
| open | subject or candidate no longer exists | closed, no-op | decision.cancelled |

### Loop

| From | Trigger | To | Event |
|---|---|---|---|
| — | loop command, no active loop | active | loop.started |
| active | task issued | active | loop.step |
| active | task resolved | active | loop.step (with result) |
| active | no work left, or step budget hit | finished | loop.finished |
| active | `experts loop abort` | aborted | loop.aborted |
| active | another loop requested and last step older than `loop_ttl_hours` | aborted | loop.aborted (reason=stale) |
