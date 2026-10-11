# 13 — Errors, Warnings, Findings

Errors: `status: error`, `code:`, `message:`, exit per table. Warnings: `warn: <CODE>: <detail>`, never change exit code. Findings: `check` output lines `finding: <CODE> <location> <detail>`; location = `path[:line]` or ID.

## Errors

| Code | Exit | When | Agent fix |
|---|---|---|---|
| E_INTERNAL | 1 | Bug, unexpected I/O failure | Report to user |
| E_USAGE | 2 | Bad/missing args or flags | Fix invocation |
| E_NOT_INITIALIZED | 5 | No `.experts/` found | Ask user before `experts init` |
| E_SCHEMA_NEWER | 6 | `schema_version` > binary max | Upgrade binary |
| E_SCHEMA_OLDER | 6 | `schema_version` < binary min (writes only) | Ask user, run `experts migrate` |
| E_CONFIG | 3 | Invalid config value | Fix `config.toml` |
| E_LOCK_TIMEOUT | 4 | Lock not acquired | Retry once |
| E_PARSE | 3 | Unparseable required file (not lenient) | Fix file or `check` |
| E_MERGE_CONFLICT | 3 | Conflict markers in a parsed file | Resolve conflict |
| E_TEXT_INVALID | 3 | Text fails constraints (03) | Rewrite text |
| E_SECRET | 3 | Content lint secret match | Remove secret; never obfuscate |
| E_EVIDENCE_INVALID | 3 | Ref malformed, missing, outside root, line out of range | Fix ref |
| E_EVIDENCE_KIND | 3 | Kind lacks required evidence type | Add required ref or change kind |
| E_EVIDENCE_SCOPE | 3 | `affirm` evidence outside rule's expert scope | Use an in-scope path |
| E_UNKNOWN_EXPERT | 3 | Named expert absent | Check `registry.md` |
| E_UNKNOWN_ID | 3 | ID not found anywhere | Check `pending`/`search` |
| E_BAD_OPTION | 3 | Option/verb not allowed | Use listed options |
| E_PAYLOAD | 3 | `--file` JSON invalid vs schema | Fix JSON |
| E_OVER_BUDGET | 3 | Compress result over budget | Shorten |
| E_SCOPE_EMPTY | 3 | Glob matches no file | Fix glob |
| E_NAME_INVALID | 3 | Expert name fails grammar | Fix name |
| E_NAME_TAKEN | 3 | Expert name exists | Choose another |
| E_UNASSIGNED | 3 | Promote from `_unassigned` | Spawn or move first |
| E_FILE_TOO_LARGE | 3 | Size bound exceeded (11) | Curate |
| E_TOO_MANY_EXPERTS | 3 | >100 experts | Merge |
| E_CHECK_FAILED | 3 | `check` found ≥1 E_ finding | See findings |
| E_NOT_PENDING | 7 | Decision/task closed or not current | `experts pending` |
| E_TASK_STALE | 7 | Task basis changed | Run `next` (re-issue) |
| E_LOOP_ACTIVE | 7 | Another loop active | Resume or ask user to abort |
| E_INIT_HAS_EXPERTS | 7 | `init --scan` with existing experts | Use `spawn` |
| E_LESSON_PENDING | 7 | Lesson has an open decision | Resolve decision first |
| E_EXPERT_NOT_EMPTY | 7 | `forget <expert>` with rules | Forget rules or merge |

## Warnings

| Code | Source |
|---|---|
| W_NO_CONFIG | config missing, defaults used |
| W_UNKNOWN_KEY | unknown config/frontmatter/lesson key |
| W_UNKNOWN_SECTION | unknown `##` in EXPERT.md |
| W_UNKNOWN_EVENT | unknown log event/version skipped |
| W_UNVERIFIED_COMMIT | commit ref accepted without git |
| W_NO_GIT | git unavailable |
| W_PATH_IGNORED | route path outside root |
| W_ROUTE_TOKEN_CAP | expert skipped by route token cap |
| W_LOCK_STOLEN | stale lock removed |
| W_LOOP_ABORTED_STALE | stale loop auto-aborted |
| W_CLUSTER_TRUNCATED | clustering input capped |
| W_ENGINE_FALLBACK | embedding engine unavailable |
| W_PROTOCOL_EDITED | local PROTOCOL.md edits overwritten (backup saved) |
| W_NO_NEW_EVIDENCE | duplicate record added no new evidence; not counted |
| W_EXPERT_SKIPPED | read-only command skipped an unreadable expert |
| W_URL, W_SHELL, W_INJECTION, W_ABSOLUTE, W_EMAIL | content lint (12) |

## check findings

| Code | Sev | Condition | `--fix` |
|---|---|---|---|
| E_PARSE | E | file unparseable | — |
| E_MERGE_CONFLICT | E | conflict markers | — |
| E_SECRET | E | secret in any expert file | — |
| E_DUP_ID | E | same ID twice across repo | re-ID newer |
| E_ORPHAN_DIR | E | dir under `.experts/` not reserved, no valid EXPERT.md | if only `lessons.md` inside: move lessons to `_unassigned`, remove dir; else — |
| E_NAME_MISMATCH | E | frontmatter name ≠ dir | — |
| E_MULTIPLE_ALWAYS | E | >1 expert with `always: true`, or `always` expert scope ≠ `["**"]` | — |
| E_FRONTMATTER | E | missing/invalid required key | — |
| E_SCOPE_EMPTY | E | non-negated glob matches nothing | — |
| E_FILE_TOO_LARGE | E | size bound exceeded | — |
| W_RULE_NO_ID | W | bullet without ID | assign |
| W_RULE_BAD_META | W | malformed meta | rebuild meta (c=1, v=-, src kept if parseable) |
| W_DUP_KEY, W_DUP_BLOCK | W | union artifacts (same file or cross-file) | collapse (11) |
| W_LESSON_PROMOTED | W | lesson block for an ID the log shows promoted/merged/discarded | remove; add c to rule if promoted/merged |
| W_STALE_PENDING | W | pending lesson, decision closed/missing | → open |
| W_REGISTRY_DRIFT | W | registry ≠ frontmatter/counts | regenerate |
| W_FORMAT | W | non-canonical order/spacing | normalize |
| W_EVIDENCE_MISSING | W | rule src / lesson evidence path no longer exists | — (verify loop handles) |
| W_OVER_BUDGET | W | expert tokens > budget | — (curate) |
| W_STALE_RULE | W | rule needs verify (06) | — (verify) |
| W_LESSONS_CAP | W | lessons > `lessons_per_expert` | — (curate) |
| W_INBOX_CAP | W | inbox > `inbox_max` | — (ingest) |
| W_INBOX_UNPARSED | W | unparseable inbox lines | — |
| W_SCOPE_OVERLAP | W | file in >2 experts' scopes | — |
| W_NESTED_ROOT | W | nested `.experts/` | — |
| W_LINT | W | rule/lesson with W_ lint codes | — |
| W_UNKNOWN_KEY, W_UNKNOWN_SECTION | W | as above | — |
