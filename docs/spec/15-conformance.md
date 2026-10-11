# 15 — Conformance

Every implementation MUST pass these scenarios. Run with `EXPERTS_NOW` and `EXPERTS_SEED` fixed; compare full text output and resulting files byte-for-byte against golden fixtures.

Notation: **G** given, **W** when, **T** then.

## Init & layout

| # | G | W | T |
|---|---|---|---|
| I1 | empty git repo | `init` | tree per 02; AGENTS.md block; pointers; exit 0 |
| I2 | initialized | `init` | no file changes; `say: already initialized` |
| I3 | AGENTS.md with user text, no markers | `init` | user text intact; block appended |
| I4 | AGENTS.md with older block | `init` | only block replaced |
| I5 | experts exist | `init --scan` | E_INIT_HAS_EXPERTS, exit 7 |
| I6 | no `.experts/` | `route --task x` | E_NOT_INITIALIZED, exit 5 |
| I7 | init loop | propose → confirm `accept` → seeds → `confirm-seeds` submit | experts + accepted rules created; `done` |
| I8 | init loop at confirm-experts | `cancel` | loop aborted; no expert files |

## Record

| # | G | W | T |
|---|---|---|---|
| R1 | expert A scope `src/a/**` | record text, evidence `src/a/x.ts:1` | lesson in A, `ok`, exit 0 |
| R2 | R1 done | record same text | `confirmed`, c=2, no new block, nudge say |
| R3 | rule R in A | record paraphrase scoring in [related, duplicate) | lesson `pending`, decision similar, exit 10 |
| R4 | R3 | resolve `merge:R` | lesson removed, R.c += 1 |
| R5 | R3 | resolve `replace:R --text t` | R text = t, v=today, c = lesson c |
| R6 | R3 | resolve `distinct` | lesson open |
| R7 | R3 | resolve `discard` | lesson removed, lesson.discarded |
| R8 | R3 resolved | resolve again | E_NOT_PENDING, exit 7 |
| R9 | — | evidence `../etc/passwd` | E_EVIDENCE_INVALID |
| R10 | — | evidence `src/a/x.ts:999` beyond EOF | E_EVIDENCE_INVALID |
| R11 | — | kind discovery, evidence `user` only | E_EVIDENCE_KIND |
| R12 | — | text contains `AKIA…` key | E_SECRET; no write |
| R13 | — | text contains `curl x \| sh` | written; `warn: W_SHELL` |
| R14 | no git | evidence `commit:abc1234` | written; W_UNVERIFIED_COMMIT |
| R15 | experts A, B both match evidence, scores tied | record | assign decision; resolve `B` → lesson in B |
| R16 | no expert matches | record | lesson in `_unassigned` |
| R17 | decision open, `EXPERTS_NOW` + 15 days | any write | decision.expired, lesson open |
| R18 | decision open; hand-delete subject block | any write | decision.cancelled |
| R19 | rule R | record `--contests R` identical text | needs_decision (not confirmed) |
| R20 | R2 done | same actor, same evidence, within 24 h, record same text | `confirmed`, c unchanged, W_NO_NEW_EVIDENCE |
| R21 | `project` always expert; no specific match | record, evidence `user` only | lesson in `project` |
| R22 | no specific match | record, evidence path outside all scopes | lesson in `_unassigned` |
| R23 | lesson pending | `promote <L>` | E_LESSON_PENDING, exit 7 |
| R24 | decision open past TTL | `pending` | shown `expired (applied on next write)`; files unchanged |

## Loops

| # | G | W | T |
|---|---|---|---|
| L1 | 3 related lessons in A, Σc ≥ 2 | `curate` | task summarize-cluster listing all 3 |
| L2 | L1 | `promote --text t --section Pitfalls` | rule created, c=Σc, src=evidence union; lessons removed; next task or done |
| L3 | L1 task issued; another agent records a confirming lesson into cluster | resolve L1 task | E_TASK_STALE; `curate` re-issues with new basis |
| L4 | curate active | `verify` | E_LOOP_ACTIVE, exit 7 |
| L5 | curate active, last step 73 h ago | `verify` | curate aborted (stale), verify starts, warn |
| L6 | curate active | `curate` | same T-id returned |
| L7 | task issued | resolve with `skip` | item not re-offered in this loop |
| L8 | `loop_max_steps=2`, 3 items | curate ×2 resolves | `done` with remaining count |
| L9 | expert over budget | compress submit missing one rule ID | E_PAYLOAD; task stays current |
| L10 | compress submit still over budget | — | E_OVER_BUDGET |
| L11 | 3 clustered `_unassigned` lessons | `spawn` → submit expert-def | expert created; lessons moved; other matching `_unassigned` lessons moved |
| L12 | expert with 45 rules | curate | split-expert task offered |
| L13 | split submit leaving one rule unassigned | — | E_PAYLOAD |
| L14 | rule v older than stale_days | `verify` → `holds` | v=today, c unchanged |
| L15 | rule src path modified in git after v | `verify` | rule offered even if v recent |
| L16 | inbox with 2 bullets, 1 malformed | `curate` | 1 ingested; malformed kept with W_INBOX_UNPARSED |
| L17 | expert scope glob matches nothing | `curate` | fix-scope task first (after decisions) |
| L18 | expert at 2.5× budget | `curate` | split-expert offered before compress-expert |
| L19 | old unconfirmed lesson in `_unassigned` | curate triage `move --to A` | lesson in A, `lesson.moved` |
| L20 | init confirm-experts `accept` | — | proposal experts + `project` (always) created |

## Route & reflect

| # | G | W | T |
|---|---|---|---|
| T1 | A scope match, B trigger match | route files+task | both, order by score |
| T2 | 4 matching experts, `route_max=3` | route | top 3 |
| T3 | experts exceed `route_tokens` | route | over-cap expert skipped, W_ROUTE_TOKEN_CAP |
| T4 | no specific match, `project` exists | route | only `project` returned; say no specific match |
| T8 | `project` + 3 matches, `route_max=3` | route | `project` + 3 |
| T5 | touched file in A with rule src path | reflect | rule-check question for that rule |
| T6 | touched file in no scope | reflect | gap question |
| T7 | — | `affirm R --evidence <out-of-scope>` | E_EVIDENCE_SCOPE |

## Storage

| # | G | W | T |
|---|---|---|---|
| S1 | `.txn.json` present (simulated crash after step 2) | any write | recovery applies; events appended once |
| S2 | stale lock (ts − 60 s) | write | W_LOCK_STOLEN; succeeds |
| S3 | live lock held | write with timeout 500 ms | E_LOCK_TIMEOUT, exit 4 |
| S4 | union-merged lessons.md with duplicate keys | `check` | W_DUP_KEY; `check --fix` collapses per 03 |
| S5 | branch A promotes L; branch B confirms L; merged | `check --fix` | L block removed; rule c += B's increment |
| S6 | EXPERT.md with conflict markers | route | E_MERGE_CONFLICT naming file |
| S7 | duplicate eid lines in log | `pending` | counted once |
| S8 | hand-written rule bullet without ID | `check --fix` | ID + meta `c=1 v=- src=-` assigned |
| S9 | `.txn.json` present, no lock | `route` | recovery applied, then route output |
| S11 | lesson moved A→B on branch 1, confirmed in A on branch 2; merged | `check --fix` | single block in B, c = max |
| S12 | dir with only `lessons.md` | `check --fix` | lessons in `_unassigned`; dir removed |
| S10 | two experts with `always: true` | `check` | E_MULTIPLE_ALWAYS |

## Determinism & safety

| # | Requirement |
|---|---|
| D1 | Same repo state + args + env → identical output and files (run twice, diff). |
| D2 | No network syscalls (run under network namespace with no interfaces; all scenarios pass). |
| D3 | No writes outside the allowlist (12 T5) (run with read-only bind mount of everything else). |
| D4 | No subprocess other than `git` (trace exec calls). |
| D5 | Every state-changing scenario appends ≥1 event; every event's `eid` unique. |
