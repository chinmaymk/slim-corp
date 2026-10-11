# 03 — Formats

All text files: UTF-8, LF line endings (CRLF accepted on read, written as LF), trailing newline. Paths: repo-relative, `/` separator, no `./`, no `..`, case-sensitive.

## Time

- Timestamp: RFC 3339 UTC, second precision, `Z` suffix. `2026-10-11T14:02:10Z`.
- Date: `YYYY-MM-DD`, UTC.
- `EXPERTS_NOW=<timestamp>` overrides the clock (tests, reproducibility).

## IDs

```
id        := prefix "-" hex6
prefix    := "L" (lesson) | "R" (rule) | "D" (decision) | "T" (task) | "P" (loop) | "E" (event, hex8)
hex6      := [0-9a-f]{6}
```

- Generated from CSPRNG; `EXPERTS_SEED=<int>` makes generation deterministic (tests).
- On generation, MUST NOT collide with any ID present in files or log; regenerate until unique.
- Event IDs (`E-` + 8 hex) dedupe log lines; readers drop repeated `eid`.

## Expert name

```
name := [a-z][a-z0-9-]{1,39}     # no leading "_", no trailing "-", no "--"
```

## Evidence

```
evidence := ref ("," ref)*                  # 1..5 refs, spaces after "," allowed
ref      := pathref | "commit:" sha | "pr:" num | "issue:" num | "user"
pathref  := path [":" line ["-" line]]
sha      := [0-9a-f]{7,40}
num      := [1-9][0-9]*
line     := [1-9][0-9]*
```

Validation at record time:

| Ref | Valid when | Without git |
|---|---|---|
| path | regular file exists under root, not ignored by `.gitignore`, not under `.experts/` | same |
| path:a[-b] | as path, and 1 ≤ a ≤ b ≤ line count | same |
| commit:sha | `git cat-file -e <sha>^{commit}` succeeds | accepted, `W_UNVERIFIED_COMMIT` |
| pr / issue | always (opaque, no network) | same |
| user | always | same |

Evidence required per kind:

| kind | Meaning | MUST include one of |
|---|---|---|
| correction | user corrected the agent | user, path |
| failure | an approach failed for a non-obvious reason | path, commit |
| discovery | found an undocumented invariant/convention | path, commit |
| instruction | user said "remember this" or stated a rule | user |
| reflection | answer to `reflect` | path, user |

## Text fields

| Field | Constraint |
|---|---|
| lesson text, rule text | 1 line, 10–200 chars after trim, no leading `-`/`#`/`>`, no `<!--` or `-->` |
| summary | 1 line, ≤120 chars |
| trigger | `[a-z0-9][a-z0-9 -]{0,29}`, ≤3 words |
| note | 1 line, ≤200 chars |
| agent | `[a-z0-9][a-z0-9._-]{0,31}` |

All text fields pass content lint (12).

## EXPERT.md

```markdown
---
name: billing-ledger
summary: Ledger writes, refunds, invoice lifecycle, Stripe sync.
scope:
  - src/billing/**
  - migrations/*ledger*
  - "!src/billing/legacy/**"
triggers: [refund, invoice, idempotency, ledger]
budget_tokens: 1500
created: 2026-10-11
updated: 2026-10-11
---
Optional preamble, ≤500 chars.

## Invariants
- [R-4c1e9a] Ledger rows are append-only; corrections are new reversing rows. <!-- c=4 v=2026-10-11 src=src/billing/ledger.ts:12-40,commit:9f1c2ab -->

## Conventions
## Pitfalls
## Decisions
```

Frontmatter (YAML subset: scalars, flow/block lists of scalars):

| Key | Req | Constraint |
|---|---|---|
| name | yes | name grammar; equals directory name |
| summary | yes | summary constraint |
| scope | yes | 1–10 globs (08); ≥1 non-negated; non-negated globs MUST each match ≥1 file (check: `E_SCOPE_EMPTY`) |
| triggers | no | 0–12 triggers, unique |
| budget_tokens | no | 200–8000; default `budgets.expert_tokens` (`always` expert: `budgets.always_tokens`) |
| always | no | `true` = project-wide expert, loaded on every route. Scope MUST be `["**"]`. At most one per repo (E_MULTIPLE_ALWAYS). Default false. |
| created, updated | yes | date |

Unknown frontmatter keys: preserved, `W_UNKNOWN_KEY`.

Body:

- Sections: `## Invariants`, `## Conventions`, `## Pitfalls`, `## Decisions`. Written in this order; empty sections omitted on write. Any order accepted on read.
- Other `##` headings: preserved, `W_UNKNOWN_SECTION`, content counts toward budget, never routed as rules.
- Rule line:

```
rule  := "- [" rid "] " text " <!-- " meta " -->"
meta  := "c=" int " v=" (date | "-") " src=" (ref ("," ref)* | "-")      # ref per Evidence grammar, ≤5
```

- A bullet without `[R-…]` in a known section = hand-written rule. Read as `c=1 v=- src=-`; `check` reports `W_RULE_NO_ID`; `check --fix` assigns ID and meta.
- A rule line with malformed meta: parsed as hand-written with ID kept; `W_RULE_BAD_META`.
- Budget tokens = ceil(chars(body without meta comments) / 4).
- `updated` set to today on every binary write to the file.

## lessons.md

```markdown
### L-7f3a2c
when: 2026-10-11T14:02:10Z
text: Refund calls must pass idempotency_key derived from refund_id.
evidence: src/billing/refund.ts:42, user
kind: correction
confirmations: 2
status: open
agent: claude-code
```

- Block = `### <L-id>` line then `key: value` lines until blank line or next `###`.
- Required: when, text, evidence, kind, confirmations (int ≥1), status (`open` | `pending`).
- Optional: agent, `decision: D-…` (present iff status=pending), `contests: R-…`, `triaged: <date>`.
- Unknown keys preserved.
- Written order: as above. New blocks appended at end. Blank line between blocks.
- Duplicate key in one block (union merge artifact): read as max for `confirmations`, `pending` wins over `open` for status only if the referenced decision is open, else `open`; other keys first occurrence. `W_DUP_KEY`; `check --fix` rewrites.
- Duplicate block ID: blocks merged by the same rules; `W_DUP_BLOCK`.

## _inbox.md

Lenient. Accepts, in any mix:

1. lessons.md blocks (ID optional: `### ` or `### L-xxxxxx`), plus optional key `expert:`.
2. Bullet form: `- <text> (evidence: <evidence>[; kind: <kind>][; expert: <name>])`.

Unparseable lines: kept in file, `W_INBOX_UNPARSED`. Parsed entries removed on successful ingest (including ones that become decisions). Entries failing validation are kept and annotated in place with `  <!-- E_CODE: message -->` once.

## registry.md

```markdown
<!-- generated by experts; edit EXPERT.md frontmatter instead -->
# Experts

| expert | scope | triggers | summary | rules |
|---|---|---|---|---|
| billing-ledger | src/billing/**, migrations/*ledger*, !src/billing/legacy/** | refund, invoice, idempotency, ledger | Ledger writes, refunds, invoice lifecycle, Stripe sync. | 12 |
```

Sorted by name. `|` in cells escaped `\|`. Regenerated after any write that changes frontmatter or rule count. Lesson counts deliberately omitted (avoids churn on every record). Drift → `W_REGISTRY_DRIFT`.

## config.toml

```toml
schema_version = 1

[budgets]
expert_tokens = 1500        # 200..8000
always_tokens = 800         # 200..4000; budget of the always expert
route_tokens = 4000         # max total tokens returned by route; 500..20000
route_max = 3               # 1..10
max_rules = 40              # per expert; above → split candidate
lessons_per_expert = 30     # nudge threshold
inbox_max = 20              # nudge threshold

[similarity]
duplicate = 0.80            # 0..1, > related
related = 0.45              # 0..1

[lifecycle]
min_confirmations = 2       # promote-ready threshold
lesson_ttl_days = 90        # unconfirmed open lessons older → triage
stale_days = 180            # rules with v older → verify candidates
decision_ttl_days = 14
loop_ttl_hours = 72
loop_max_steps = 25

[spawn]
min_cluster = 3

[record]
max_evidence = 5

[storage]
lock_timeout_ms = 5000     # 500..60000
```

Unknown keys → `W_UNKNOWN_KEY`. Out-of-range → `E_CONFIG`. Missing keys → defaults above. Missing file → all defaults, `W_NO_CONFIG`.

## Log

Path: `.experts/log/<YYYY>.jsonl` by event `ts` year. One JSON object per line, keys sorted, no whitespace.

Common fields:

| Key | Type | Notes |
|---|---|---|
| v | int | event schema version, `1` |
| eid | string | `E-` + 8 hex |
| ts | string | timestamp |
| ev | string | event type |
| actor | string | `--agent` value or `cli` |
| loop | string? | `P-…` if inside a loop |

Event payloads:

| ev | Payload |
|---|---|
| lesson.recorded | id, expert, text, evidence[], kind, status |
| lesson.confirmed | target (L/R id), by_text, evidence[], score, counted |
| lesson.merged | id, into, text |
| lesson.replaced | id, by |
| lesson.discarded | id, text, reason |
| lesson.moved | id, from, to, reason |
| rule.promoted | id, expert, section, text, src[], lessons[] |
| rule.edited | id, before, after, reason |
| rule.verified | id |
| rule.moved | id, from, to |
| rule.retired | id, text, reason |
| expert.created | name, summary, scope[], triggers[] |
| expert.updated | name, fields{} (changed keys only, before/after) |
| expert.renamed | from, to |
| expert.retired | name, reason, into? |
| decision.opened | id, type, subject, candidates[{id, score}], options[] |
| decision.resolved | id, choice, target?, text?, note? |
| decision.expired | id, applied |
| decision.cancelled | id, reason |
| loop.started | id, kind, scope?, args{} |
| loop.step | id, task (T id), task_kind, basis, phase, result? |
| loop.finished | id, summary{} |
| loop.aborted | id, reason |
| route | files[], task?, experts[] (only with `--log`) |
| schema.migrated | from, to |
| ingest | parsed, failed |

Unknown `ev` or higher `v`: skipped on read, `W_UNKNOWN_EVENT`.
