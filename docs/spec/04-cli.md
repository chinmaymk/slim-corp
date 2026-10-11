# 04 — CLI

## Invocation

```
experts <command> [args] [flags]
```

Global flags:

| Flag | Effect |
|---|---|
| `--root <dir>` | Override root discovery (02). |
| `--json` | JSON output (below). |
| `--agent <name>` | Sets `actor` on events. Default env `EXPERTS_AGENT`, else `cli`. |
| `--quiet` | Suppress `warn:` lines (text mode only). |

Env: `EXPERTS_NOW`, `EXPERTS_SEED`, `EXPERTS_AGENT`.

Argument conventions:

- List flags (`--files`, `--evidence`, `--from`): comma-separated and/or repeated. Value `-` reads newline-separated items from stdin (use for names containing commas).
- Text values (positional text, `--text`, `--note`): value `-` reads one line from stdin. At most one argument per call may read stdin.
- Paths: `\` converted to `/`; leading `./` stripped; absolute paths inside root converted to relative; others rejected.
- `today` = UTC date of now.

## Output

Text mode grammar:

```
output := line+
line   := key ": " value "\n"
key    := [a-z_]+
value  := single line; "\" → "\\", newline → "\n"
```

- First line is always `status: <status>`.
- Repeated keys form a list, in order.
- Reserved keys, valid on every command:

| Key | Meaning |
|---|---|
| status | `ok` \| `confirmed` \| `needs_decision` \| `task` \| `done` \| `error` |
| code | error code (13), only when status=error |
| message | human-readable error detail |
| next | exact command the agent should run next (literal; placeholders in `<>`) |
| say | text the agent SHOULD relay to the user verbatim or summarized |
| warn | `W_CODE: detail` |

All output goes to stdout. stderr is used only for crashes (E_INTERNAL stack info).

JSON mode: single object. Keys as text mode. Keys that may repeat are always arrays (`next`, `say`, `warn`, plus per-command list keys). Scalars otherwise. No trailing output.

Exit codes:

| Exit | When |
|---|---|
| 0 | status ok, confirmed, done |
| 10 | needs_decision |
| 11 | task |
| 1 | E_INTERNAL |
| 2 | usage errors (E_USAGE) |
| 3 | validation/rejection errors |
| 4 | E_LOCK_TIMEOUT |
| 5 | E_NOT_INITIALIZED |
| 6 | E_SCHEMA_NEWER, E_SCHEMA_OLDER |
| 7 | state conflicts (E_LOOP_ACTIVE, E_TASK_STALE, E_NOT_PENDING) |

Full mapping in 13.

## Pre-command steps (every command except `version`, `help`)

1. Resolve root. None and command ≠ `init` → `E_NOT_INITIALIZED`.
2. Load config; check `schema_version` (14).
3. Writing commands: acquire lock; run recovery if `.txn.json` exists (11).
4. Lazy maintenance (writing commands only, inside the lock): expire decisions past TTL; cancel decisions whose subject/candidates are gone.
5. Read-only commands: if `.txn.json` exists, acquire the lock, run recovery, release, then read. Recovery is the only write a read-only command may perform.
6. Read-only commands report decisions past TTL as `expired (applied on next write)`; they do not apply expiry.

Degradation: read-only commands never fail on one bad expert. An expert whose files fail to parse (E_PARSE, E_MERGE_CONFLICT, E_FILE_TOO_LARGE) is skipped with `warn: W_EXPERT_SKIPPED: <name> <code>`. Writing commands that need that expert fail with its code; others proceed.

## Command index

| Command | Writes | Summary |
|---|---|---|
| init | yes | Create structure; `--scan` starts init loop |
| scan | cache only | Survey repo |
| route | no (`--log`: log) | Pick experts for files/task |
| record | yes | Add a lesson |
| resolve | yes | Answer a decision or task |
| pending | no | List open decisions and active loop |
| show | no | Print an expert, rule, lesson, decision |
| search | no | Similarity search over rules and lessons |
| promote | yes | Promote a lesson directly (user-instructed) |
| affirm | yes | Mark a rule verified (06 reflect) |
| forget | yes | Discard lesson / retire rule / retire expert (user-instructed) |
| rename | yes | Rename expert |
| ingest | yes | Process `_inbox.md` |
| check | `--fix` only | Integrity report |
| index | yes | Regenerate registry |
| stats | no | Counts per expert |
| curate, spawn, verify | yes | Start/resume loops (06) |
| reflect | no | End-of-task questions (06) |
| loop | yes | `loop status` / `loop abort` |
| migrate | yes | Upgrade schema (14) |
| version, help | no | — |

## Commands

### init

```
experts init [--scan] [--no-pointers] [--agents <list>]
```

- Creates missing: `.experts/`, `config.toml`, `PROTOCOL.md`, `registry.md`, `_inbox.md`, `_unassigned/`, `log/`.
- Adds `.gitignore`/`.gitattributes` lines if absent (02).
- Writes AGENTS.md block and pointer files (10) unless `--no-pointers`. `--agents` limits pointers (comma list of `claude,gemini,cursor,windsurf,cline,skills`); default all.
- Existing files: never overwritten except AGENTS.md block between markers and `PROTOCOL.md` when its version line is older.
- Already initialized and no `--scan`: `status: ok` with `say: already initialized`.
- `--scan`: if an init loop is active → resume it. Else starts init loop (06); refused with `E_INIT_HAS_EXPERTS` if any expert exists (use `spawn`).
- Events: none for structure; init loop emits its own.

### scan

```
experts scan [--max-commits <n=2000>] [--since <date>]
```

Writes `.cache/scan.json`; prints summary (08). No events.

### route

```
experts route [--files <p1,p2,...>] [--task "<text>"] [--max <n>] [--log]
```

At least one of `--files`, `--task` → else `E_USAGE`. Output keys: `expert` (list), `load` (list of paths), `why` (list), `tokens`, plus `say` nudges. Algorithm: 08.

### record

```
experts record "<text>" --evidence <evidence> [--kind <kind=discovery>] [--expert <name>] [--contests <R-id>]
```

Pipeline and outputs: 05. `--contests`: 06 (reflect).

### resolve

```
experts resolve <D-id|T-id> <option> [--text "<text>"] [--section <name>] [--note "<note>"] [--file <path|->]
```

Decisions: 05. Tasks: 06.

### pending

```
experts pending
```

Keys: `decision` (list, `D-id type subject age_days`), `loop` (`P-id kind step n/max current T-id`), `next` (resolve/resume commands).

### show

```
experts show <expert|R-id|L-id|D-id>
```

Expert: frontmatter summary + body (meta comments stripped) + open lesson count. Rule/lesson: full fields + history from log. Decision: full payload + options + `next`.

### search

```
experts search "<query>" [--expert <name>] [--limit <n=5>]
```

Similarity (07) of query against all rules and open lessons. Keys: `hit` list `id score expert text`.

### promote

```
experts promote <L-id> [--text "<rule text>"] [--section <Invariants|Conventions|Pitfalls|Decisions>]
```

User-instructed promotion. `--section` required unless lesson kind maps: failure→Pitfalls, instruction→Conventions; else `E_USAGE`. Lesson must be `open` (pending → E_LESSON_PENDING: resolve its decision first) and belong to a real expert (not `_unassigned`) → else `E_UNASSIGNED`. Creates rule: text = `--text` or lesson text, `c=lesson.c v=today src=lesson evidence`. Removes lesson. Event `rule.promoted`.

### forget

```
experts forget <L-id|R-id|expert> --note "<why>"
```

L → removed, `lesson.discarded`. R → removed, `rule.retired`. Expert → only if it has 0 rules; else `E_EXPERT_NOT_EMPTY` (use curate merge or forget rules first); lessons move to `_unassigned`; dir deleted; `expert.retired`.

### rename

```
experts rename <old> <new>
```

Validates name (E_NAME_INVALID), target absent (E_NAME_TAKEN). Refused with E_LOOP_ACTIVE if the active loop's scope names `<old>`. Moves dir, updates `name`, regenerates registry. Event `expert.renamed`. Decisions reference lesson/rule IDs, not names: unaffected.

### ingest

```
experts ingest
```

For each parsed inbox entry, runs record pipeline (05). Never returns `needs_decision` for one entry and stops; processes all, then returns `status: needs_decision` listing all opened decisions (`decision` list) or `ok`. Event `ingest`.

### check

```
experts check [--fix] [--expert <name>]
```

Reports every finding as `finding: <CODE> <location> <detail>`. Status `ok` if no E_ findings, else `error` with `code: E_CHECK_FAILED` (exit 3). `--fix` applies only mechanical fixes:

| Finding | Fix |
|---|---|
| W_REGISTRY_DRIFT | regenerate |
| W_RULE_NO_ID, W_RULE_BAD_META | assign ID/meta |
| W_DUP_KEY, W_DUP_BLOCK | collapse per 03 |
| W_FORMAT | normalize order/spacing |
| W_STALE_PENDING | lesson status pending with closed/missing decision → open |

Never changes text meaning, never deletes rules or lessons. Full finding list: 13.

### index

Regenerate `registry.md`. Always `ok`.

### stats

Per expert line: `expert: <name> rules=<n> lessons=<n> ready=<n> stale=<n> tokens=<n>/<budget> updated=<date>`. Plus `inbox: <n>`, `unassigned: <n>`, `decisions: <n>`.

### Loop commands

```
experts curate [--expert <name>] [--max-steps <n>]
experts spawn  [--name <name>] [--from <L-ids>]
experts verify [--expert <name>] [--rule <R-id>] [--max-steps <n>]
experts loop status
experts loop abort [--note "<why>"]
```

Same kind and args as active loop → resume (returns current task). Different kind or args while active → `E_LOOP_ACTIVE` unless stale. Details: 06.

### reflect, affirm

```
experts reflect --files <paths> [--task "<text>"]
experts affirm <R-id> --evidence <path[:lines]>
```

06 (reflect section).

### migrate

```
experts migrate [--dry-run]
```

14.

### version

Prints `version: <semver>`, `schema: <min>-<max>`, `commit: <sha>`.
