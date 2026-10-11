# 05 — Record & Decisions

## record pipeline

Input: text, evidence, kind (default `discovery`), expert? (optional), actor.

| Step | Action | Failure |
|---|---|---|
| 1 | Trim text. Validate text constraint (03). | E_TEXT_INVALID |
| 2 | Content lint (12). Secrets → reject. Other findings → `warn`. | E_SECRET |
| 3 | Parse evidence; ≤`max_evidence` refs; validate each (03). | E_EVIDENCE_INVALID (names the bad ref) |
| 4 | Check kind↔evidence requirement (03). | E_EVIDENCE_KIND |
| 5 | Assign expert (below). | E_UNKNOWN_EXPERT (if `--expert` given and absent) |
| 6 | Similarity vs candidates (below). | — |
| 7 | Branch on best score (below). | — |
| 8 | Write (txn), append events; regenerate registry if rule count changed. | E_LOCK_TIMEOUT, E_FILE_TOO_LARGE |
| 9 | Emit output + nudges. | — |

### Step 5 — assignment

1. `--expert` given → that expert (`_unassigned` allowed explicitly).
2. Else run route scoring (08) with `files` = evidence path refs, `task` = text. Take experts with score ≥ 0.5 (the `always` expert is never scored).
   - 0, evidence has ≥1 path ref → `_unassigned` (uncovered area; spawn candidate).
   - 0, no path refs (only user/commit/pr/issue) → the `always` expert if present, else `_unassigned`.
   - 1 → it.
   - ≥2 and top score − second score ≥ 0.25 → top.
   - ≥2 otherwise → **assign decision** (after step 6/7 produce no duplicate; duplicate short-circuits).

### Step 6 — candidates

All active rules in all experts + all lessons (open or pending) in all experts and `_unassigned`. Score each with similarity (07). Keep top 3 by score (ties: ID ascending).

### Step 7 — branch

| Best score `s` | Result |
|---|---|
| `s ≥ duplicate` | **confirm**: if the new evidence adds ≥1 ref not already on the target, or actor differs from every prior confirmer, or last confirmation > 24 h ago: target.c += 1 and absorb(target, evidence); else no increment, `warn: W_NO_NEW_EVIDENCE`. Rule target: v=today either way. No lesson created. `status: confirmed`. Event lesson.confirmed (with `counted: true/false`). Assignment decision skipped. |
| `related ≤ s < duplicate` | Create lesson with status `pending`; open **similar decision**. If assignment was ambiguous, the similar decision carries an extra `assign` field (see below). `status: needs_decision`. |
| `s < related`, assignment ambiguous | Create lesson `pending` in top expert; open **assign decision**. `status: needs_decision`. |
| `s < related`, assignment resolved | Create lesson `open`. `status: ok`. |

Output on create: `lesson: <L-id>`, `expert: <name>`. On confirm: `confirmed: <id>`, `confirmations: <n>`. On decision: decision block (below).

`absorb(target, refs)`: lesson target → `evidence` field; rule target → `src`. Union, dedupe, newest first, cap `max_evidence`; path refs preferred over `user` when trimming.

### Step 9 — nudges (say lines)

Emitted after a successful write when true:

| Condition | say |
|---|---|
| a lesson (not rule) reaches `c ≥ min_confirmations` | `<id> is ready to promote; suggest "curate experts" to the user when convenient` |
| expert open lessons > `lessons_per_expert` | `<expert> has <n> open lessons; suggest curate` |
| `_unassigned` has ≥ `min_cluster` lessons in one cluster | `possible new expert; suggest "experts spawn"` |

Nudges never cause the binary or protocol to run loops automatically.

## Decisions

Decision output block:

```
status: needs_decision
decision: D-1c9e0f
type: similar
subject: L-7f3a2c "Refund calls must pass idempotency_key derived from refund_id."
candidate: L-42aa10 0.71 "Refunds require an idempotency key."
candidate: R-0d22b7 0.52 "Money is integer minor units ..."
ask: Is the subject the same as a candidate, a correction of one, or distinct?
option: merge:<id>
option: replace:<id>
option: distinct
option: discard
default: distinct
next: experts resolve D-1c9e0f <option> [--text "<text>"] [--note "<why>"]
```

### Types and options

**similar** — subject lesson (pending) vs 1–3 candidates.

| Option | Precondition | Effect | Events |
|---|---|---|---|
| `merge:<id>` | id ∈ candidates | Subject removed. Target.c += subject.c; absorb(target, subject evidence). Rule target: v=today. If `--text`: target text := text (rule: rule.edited). | decision.resolved, lesson.merged, [rule.edited] |
| `replace:<id>` | id ∈ candidates | Target is wrong/outdated. Lesson target: removed (lesson.replaced); subject → open. Rule target: rule text := `--text` or subject text; c := subject.c; v=today; src := subject evidence, then absorb old src; subject removed. | decision.resolved, lesson.replaced or rule.edited |
| `distinct` | — | Subject → open. `--text` ignored. If decision carries `assign_option`, `--to <expert\|_unassigned>` is required (else E_USAGE) and the lesson moves there. | decision.resolved, [lesson.moved] |
| `discard` | — | Subject removed. | decision.resolved, lesson.discarded |

Default on expiry: `distinct` (with assign: keep top expert).

**assign** — subject lesson (pending) placed in top expert; ambiguous between ≥2 experts.

| Option | Effect |
|---|---|
| `<expert-name>` (∈ listed) | Lesson moved there (if different), → open. |
| `_unassigned` | Moved to `_unassigned`, → open. |

Default on expiry: keep current (top) expert, → open.

Combined (similar + assign): a single decision of type `similar` with keys `assign_option: <name>` list. Resolving `distinct` requires `--to <expert|_unassigned>`. `merge`/`replace`/`discard` ignore assignment.

### Resolve rules (decisions)

```
experts resolve <D-id> <option> [--text "..."] [--to <expert>] [--note "..."]
```

| Condition | Result |
|---|---|
| Decision closed | E_NOT_PENDING (exit 7), `say` shows how it was closed |
| Decision unknown | E_UNKNOWN_ID |
| Option not in list | E_BAD_OPTION, `option` lines repeated |
| `--text` fails text constraint/lint | E_TEXT_INVALID / E_SECRET |
| Subject or target gone | decision.cancelled, E_NOT_PENDING |
| OK | Effects applied atomically; `status: ok`; `next` lists other open decisions created in the same record/ingest call, if any |

Resolution within a loop: decisions opened inside a loop belong to it; resolving returns the loop's next task (06).

## Agent guidance carried in output

`ask` wording is fixed per type. Protocol (09) tells the agent: choose `replace` only if the user corrected the old statement or code evidence contradicts it; choose `merge` when one is a restatement; when unsure, ask the user; never default silently.
