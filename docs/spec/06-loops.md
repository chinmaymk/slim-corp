# 06 — Loops

Loop kinds: `init`, `curate`, `spawn`, `verify`. (`reflect` is not a loop; see end.)

## Engine

State of the active loop is derived from log events with its `P-` id:

| Field | Source |
|---|---|
| kind, scope, args | loop.started |
| steps | count of loop.step events with `result` (tasks resolved) |
| phase | last loop.step `phase` |
| skipped | item keys from loop.step results with verb `skip`/`keep` |
| current | last loop.step without result, if any |
| proposals | results stored by loop.step (init proposals, seeds) |

### Next-task function

```
next(loop):
  if open decision d with d.loop == loop.id: return needs_decision(d)   # oldest first
  for phase in phases(kind) starting at loop.phase:
    run automatic actions of phase (idempotent)
    item = first eligible item in phase, deterministic order, key ∉ skipped
    if item: issue task(item); return task
  finish(loop); return done
```

- Eligibility is recomputed from current files every call. Concurrent edits are safe.
- Phase pointer is monotonic: earlier phases are not revisited in the same loop (new items there wait for the next loop).
- Clustering and item selection consider only `open` lessons; `pending` lessons wait for their decision.
- `max_steps` (default `loop_max_steps`) applies to curate and verify. init and spawn are bounded by construction.
- Any actor may resolve a task; the loop is repo state, not conversation state.
- Item key = `<phase>:<sorted IDs or names>`. Same key is never re-offered in one loop after skip/keep.
- Decisions opened inside a loop (its automatic actions, e.g. ingest) carry `loop: <P-id>` in decision.opened and are returned before the next task, with `loop:` in output. Resolving one returns `next(loop)`. Decisions not owned by the loop are handled in curate's `decisions` phase (scope-filtered) and likewise return `next(loop)` after resolve.

### Issuing a task

1. New `T-id`. `basis` = sha256 of canonical JSON of the referenced items (IDs + text + c + section, or frontmatter for experts).
2. Event loop.step {task, task_kind, basis, phase} (no result).
3. Output:

```
status: task
task: T-8b21c4
loop: P-30a1ff curate step 3/25 phase promote
kind: summarize-cluster
ask: <fixed instruction for this kind>
context: <item line>                 # repeatable
read: src/billing/refund.ts:30-60    # repeatable; files the agent should open
verb: promote --text "<rule>" --section <Invariants|Conventions|Pitfalls|Decisions>
verb: update:<R-id> --text "<rule>"
verb: keep
verb: discard --note "<why>"
schema: <name>                       # only for --file submissions
example: <one-line JSON>             # only for --file submissions
next: experts resolve T-8b21c4 <verb> [flags]
```

### Resolving a task

```
experts resolve <T-id> <verb> [--text ...] [--section ...] [--note ...] [--file <path|->]
```

| Check | Failure |
|---|---|
| T is the current task of the active loop | E_NOT_PENDING |
| basis matches recomputed basis | E_TASK_STALE; `next: experts <kind>` (re-issues a fresh task) |
| verb valid for task kind | E_BAD_OPTION |
| flags/payload valid | E_TEXT_INVALID, E_SECRET, E_PAYLOAD, E_OVER_BUDGET, E_SCOPE_EMPTY … (task stays current; agent retries) |

On success: effects applied in one txn; event loop.step {task, result}; steps += 1. If `steps ≥ max_steps` → finish with `remaining` counts. Else return `next(loop)`.

### Resume, abort, staleness

| Situation | Behavior |
|---|---|
| Same loop command, loop active, same kind | Return current task (same T-id) if basis valid; else mark stale (loop.step result=`stale`) and issue fresh. `--expert`/args mismatch → E_LOOP_ACTIVE. |
| Different loop kind requested, active loop last step < `loop_ttl_hours` | E_LOOP_ACTIVE; `next: experts <active-kind>` and `next: experts loop abort` |
| Different loop kind requested, active loop stale | loop.aborted reason=stale; new loop starts; `warn: W_LOOP_ABORTED_STALE` |
| `experts loop abort` | loop.aborted; effects already applied stay. |
| `experts loop status` | loop id, kind, phase, steps, current task (full task block). |

### Finish output

```
status: done
loop: P-30a1ff curate
say: promoted 4 rules, edited 1, retired 2, discarded 3 lessons, created expert search-index
say: remaining: 2 clusters, 1 over-budget expert (step budget reached; run "experts curate" again)
say: review with: git diff -- .experts/
```

Counts are derived from the loop's events.

### Submissions via --file

- `--file -` reads stdin. Otherwise any readable path given explicitly.
- Max 256 KiB. JSON object. Unknown keys → E_PAYLOAD. Schemas below.

## Task catalog

Common verbs: `skip` (all tasks except confirm-*): item key → skipped, no effect.

### propose-experts (init)

- context: scan summary — manifests, top-level dirs with file counts, co-change clusters (paths), hotspots (08).
- read: README*, docs/**/*.md (≤10, by size), ADR files.
- ask: Propose 1–7 domain experts. Domains, not technologies. Scopes must match existing files. Do not propose a project-wide expert; `project` is created automatically.
- verb: `submit --file` schema `experts-proposal`:
  `{"experts":[{"name":"billing-ledger","summary":"…","scope":["src/billing/**"],"triggers":["refund"]}]}`
- validate: 1–7 entries; each passes frontmatter constraints; unique names; every non-negated glob matches ≥1 file; `W_SCOPE_OVERLAP` if a file matches >2 experts.
- effect: none on files; proposal stored in step result.

### confirm-experts (init)

- context: proposal, one line per expert.
- ask: Show this list to the user. Submit exactly what the user approves. Do not approve on the user's behalf.
- verbs: `accept` | `submit --file` (schema `experts-proposal`, user-edited) | `cancel` (aborts loop).
- effect: create each expert (EXPERT.md with empty body, created=updated=today), plus `project` (`always: true`, scope `["**"]`, summary `Project-wide conventions, tooling, workflow.`) unless an `always` expert exists or the name is taken (then `project-wide`). Registry. Events expert.created.
- seed-rules is also issued for `project` (read: README, CONTRIBUTING, manifests, CI config).

### seed-rules (init, one task per created expert)

- context: expert frontmatter.
- read: ≤10 files: hottest files in scope from scan, then docs mentioning scope dirs.
- ask: Propose ≤5 non-obvious rules a newcomer would get wrong. Each with evidence. No generic advice.
- verb: `submit --file` schema `seed-rules`:
  `{"rules":[{"text":"…","section":"Invariants","evidence":"src/billing/ledger.ts:10-30"}]}` (0–5)
- validate: text constraint, lint, evidence valid (path or commit only), section valid; two seeds in the same submission scoring ≥ `duplicate` → E_PAYLOAD.
- effect: seeds stored in step result, labeled `S1..Sn` across all experts.

### confirm-seeds (init, once, after all seed-rules)

- context: `S<n> <expert> <section> <text>` lines.
- ask: Show these to the user. Submit what the user approves.
- verbs: `accept-all` | `reject-all` | `submit --file` schema `seed-confirm`:
  `{"accept":["S1","S3"],"edit":{"S3":"new text"}}`
- validate: labels exist; edited texts pass text constraint and lint.
- effect: accepted seeds → rules `c=1 v=today src=<evidence>`. Rejected seeds dropped (not recorded). Events rule.promoted (lessons=[]).

### summarize-cluster (curate: promote)

- item: cluster (07) of open lessons in one expert, Σc ≥ `min_confirmations`. Order: Σc desc, then oldest `when`.
- context: each lesson (`L-id c text evidence`); up to 2 existing rules in the expert with similarity ≥ `related` to the cluster centroid text (`R-id c section text`).
- ask: Write one rule (≤200 chars) capturing these lessons, or fold into an existing rule.
- verbs:
  - `promote --text --section` → new rule; c=Σc; v=today; src = absorb(∅, all lesson evidence) (05); lessons removed.
  - `update:<R-id> --text` (R-id ∈ context) → rule text := text; c += Σc; v=today; absorb(rule, all lesson evidence); lessons removed.
  - `keep` → skipped.
  - `discard --note` → lessons removed (lesson.discarded each).

### triage-lesson (curate: triage)

- item: open lesson (any expert, incl. `_unassigned`) with c < `min_confirmations` and age(max(`when`, `triaged`)) > `lesson_ttl_days`. Oldest first.
- verbs: `promote --text --section` (not for `_unassigned`) | `move --to <expert>` | `keep` (sets lesson key `triaged: <today>`) | `discard --note`.

### define-expert (curate: spawn; spawn loop)

- item: cluster in `_unassigned` with size ≥ `min_cluster` (curate), or per spawn args.
- context: lessons with evidence; existing expert names + scopes.
- ask: Define a new expert covering these lessons. Scope must match evidence paths.
- verbs: `submit --file` schema `expert-def`: `{"name":"…","summary":"…","scope":[…],"triggers":[…]}` | `skip` | `cancel` (spawn loop only; aborts).
- validate: frontmatter constraints; name unused; scope covers ≥1 evidence path of the cluster (if any path evidence exists).
- effect: create expert; move cluster lessons; then re-assign every `_unassigned` lesson whose route score for the new expert ≥ 0.5. Events expert.created, lesson.moved.

### fix-scope (curate: scope)

- item: expert with ≥1 non-negated glob matching no file (code moved/deleted).
- context: frontmatter; rule `src` paths that still exist; scan areas nearest the dead globs.
- ask: Repair the scope to cover where this code lives now, or retire the expert.
- verbs: `submit --file` schema `expert-def` (name must equal current; updates summary/scope/triggers; expert.updated) | `retire` (only if 0 rules; else E_EXPERT_NOT_EMPTY; lessons → `_unassigned`) | `skip`.

### merge-experts (curate: merge)

- item (never includes the `always` expert): expert pair with scope overlap ≥ 0.5 (|files(A)∩files(B)| / min(|files(A)|,|files(B)|)) and mean best rule similarity ≥ `related`. Order: overlap desc.
- context: both experts' frontmatter and rules.
- verbs: `merge --into <A|B> [--text "<summary>"]` | `keep`.
- effect: source rules/lessons moved to target; scope := union (deduped); triggers := target's then source's, deduped, cap 12; summary := `--text` or target's; source retired (reason=merged, into). Duplicate rules after merge are not auto-collapsed (next compress handles).

### compress-expert (curate: compress)

- item: expert with tokens > budget.
- context: body with rule IDs and sections; `tokens: <n>/<budget>`.
- ask: Rewrite to fit the budget. Every rule ID must be kept, merged, or dropped explicitly.
- verb: `submit --file` schema `compress`:
  `{"keep":[{"id":"R-…","text":"…","section":"…"}],"merge":[{"ids":["R-a","R-b"],"text":"…","section":"…"}],"drop":[{"id":"R-…","note":"…"}],"preamble":"…"}`
- validate: every current rule ID appears exactly once across keep/merge.ids/drop; resulting tokens ≤ budget (else E_OVER_BUDGET, re-ask); texts pass constraints.
- effect: keep → rule.edited if text/section changed. merge → first listed ID kept, text/section replaced, c=Σc, v=max(v) (`-` = oldest), src=absorb over all; others rule.retired (reason=merged, into). drop → rule.retired.
- Order note: split runs before compress, so an expert >2× budget is split first and its parts compressed after.
- verbs also: `skip`.

### split-expert (curate: split)

- item (never the `always` expert; it is compressed only): expert with tokens > 2×budget, or rules > `max_rules`.
- verb: `submit --file` schema `split`:
  `{"experts":[{"name":"…","summary":"…","scope":[…],"triggers":[…],"rules":["R-…"]}]}` (2–3 entries)
- validate: each rule ID assigned exactly once; names valid; at most one entry reuses source name; scopes valid.
- effect: entries create/update experts; rules moved; source retired if no entry reuses its name; lessons re-assigned by route score (fallback: the entry with most of the lesson's evidence paths; else first entry).
- verbs also: `skip`.

### verify-rule (verify)

- item: rule in scope where `v` is `-`, or older than `stale_days`, or any path in `src` changed in git since `v`. Order: `v=-` first, then oldest `v`. `--rule` → that rule only.
- context: rule (`R-id section c v text`), expert.
- read: path refs in `src` (line ranges widened ±20); if none, top 3 hottest files in expert scope.
- ask: Check the rule against the current code.
- verbs: `holds` (v=today, rule.verified) | `edit --text [--section]` (rule.edited, v=today) | `obsolete --note` (rule.retired) | `skip`.

## Phases per loop

| Loop | Phases (in order) | Automatic actions |
|---|---|---|
| init | scan → propose → confirm → seed → confirm-seeds | scan; create experts on confirm |
| curate | ingest → decisions → scope → promote → triage → spawn → merge → split → compress → report | ingest inbox; index at finish |
| spawn | define | — |
| verify | verify | — |

curate `--expert X` restricts decisions/scope/promote/triage/compress/split items to X; spawn skipped; merge offered only for pairs containing X.

`report` phase: no tasks; adds `say` lines for: stale rule count (suggest `experts verify`), check findings (E_ only), inbox size.

spawn args: `--from <L-ids>` → cluster = those lessons (must exist; any expert). `--name <n>` → name prefilled in context; if no `--from` and no `_unassigned` cluster qualifies, define-expert runs with empty lesson context ("user-requested expert"). No qualifying cluster and no `--name` → `status: done`, `say: nothing to spawn`.

## reflect (non-loop)

```
experts reflect --files <paths> [--task "<text>"]
```

Read-only. Returns ≤3 questions; answers use ordinary commands. Never blocks other loops.

| Order | Question type | Selected when | Answer commands |
|---|---|---|---|
| 1–2 | rule-check | rules in routed experts (excluding `always`) whose `src` paths ∩ files, else scope ∩ files; oldest `v` first; max 2 | `experts affirm <R-id> --evidence <path>` (held) · `experts record "<correct statement>" --evidence <ref> --kind reflection --contests <R-id>` (wrong) · nothing |
| next | gap | ≥1 file matches no expert scope | `experts record "<text>" --evidence <path> --kind reflection` · nothing |
| last | open | always, if < 3 questions | same as gap |

Output:

```
status: ok
question: rule-check R-e8f415 "Stripe webhooks can arrive before the API call returns; handlers must upsert." — did it hold in this task?
question: gap src/search/indexer.ts — anything non-obvious a future agent should know?
question: open — what would have made this task faster or safer?
say: answer only if something non-obvious; "nothing" is a valid answer
next: experts affirm R-e8f415 --evidence <path>
next: experts record "<text>" --evidence <ref> --kind reflection [--contests <R-id>]
```

### affirm

```
experts affirm <R-id> --evidence <path[:lines]>
```

Evidence path MUST be within the rule's expert scope, else E_EVIDENCE_SCOPE. Effect: v=today. Event rule.verified. Does not change c.

### record --contests

`experts record ... --contests <R-id>`: the rule is forced into the candidate list regardless of score (score shown as computed). If best score ≥ duplicate and best is the contested rule, the duplicate branch is NOT taken; a similar decision is opened instead. Result: always `needs_decision` with that rule as a candidate.
