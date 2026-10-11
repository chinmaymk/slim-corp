# 11 — Storage, Concurrency, Recovery

## Lock

- File: `.experts/.lock`. Acquire by exclusive create (`O_CREAT|O_EXCL`). Content: `{"pid":…, "host":"…", "ts":"…", "cmd":"…"}`.
- Retry every 100 ms up to `lock_timeout_ms` (config `[storage] lock_timeout_ms = 5000`, 500..60000) → E_LOCK_TIMEOUT.
- Stale: lock `ts` older than 30 s, or same host and pid not alive → remove, `W_LOCK_STOLEN`, retry. (No operation holds the lock > 30 s; scan does not take it.)
- Released on exit, including error paths. Crash leaves lock → stolen by staleness.
- Taken by every writing command. Not taken by: route (without `--log`), pending, show, search, check (without `--fix`), stats, scan, reflect, version.
- Route with `--log` takes the lock only to append the event.

## Transactions

Every writing command builds one transaction:

```json
{"id":"…","files":[{"path":".experts/billing-ledger/EXPERT.md","content":"…"},{"path":".experts/x/lessons.md","content":null}],"events":[{…}]}
```

`content: null` = delete. Directory creation/removal implied by paths.

Commit protocol (under lock):

1. Write `.txn.json` (temp + fsync + rename).
2. For each file: write `<path>.tmp-<txn>` + fsync + rename over target (or delete). Remove emptied expert dirs.
3. Append events to log files; skip any `eid` already present in the last 1000 lines of the target log file.
4. fsync log; delete `.txn.json`.

Recovery: on lock acquisition, if `.txn.json` exists → re-run steps 2–4 (idempotent: full contents, eid dedupe). Then proceed. Read-only commands seeing `.txn.json` take the lock and recover first (04).

Order guarantee: files before log. A crash after files, before log → recovery appends events. A crash before step 1 completes → nothing happened.

## Read model

- Each command reads all of `.experts/` once (small) and the log files needed for derived state: all years for ID uniqueness (only IDs) and the open decision/loop set.
- Log parse cost bounded: implementations SHOULD cache `(file, size, mtime) → derived state` in `.cache/`.

## Parallel agents, same worktree

- Writes serialize on the lock.
- Loop tasks protected by `basis` (06): a task whose items changed under it returns E_TASK_STALE.
- Decisions: resolving a closed decision → E_NOT_PENDING; the second agent re-reads with `pending`.
- Two agents recording the same observation: the second sees the first's lesson → `confirmed`.

## Branches and merges

| File | Merge | Conflict handling |
|---|---|---|
| `log/*.jsonl` | union | Lines from both sides kept. Duplicate eids dropped on read. Event order within a file is not relied on; derived state sorts by `ts`, then `eid`. |
| `*/lessons.md`, `_inbox.md` | union | Duplicate keys/blocks → read rules (03); `check --fix` normalizes. Same lesson promoted on one branch and confirmed on other: block reappears → `check` reports `W_LESSON_PROMOTED` (log has rule.promoted for that ID); `check --fix` removes it and adds its confirmations to the rule. |
| `EXPERT.md` | default text merge | Git conflict markers → binary refuses to parse that file: E_MERGE_CONFLICT naming it; user/agent resolves. |
| `registry.md` | default | On conflict: `experts index` regenerates. |
| `config.toml`, `PROTOCOL.md` | default | Manual. |

Cross-branch decision state: a decision opened on branch A and resolved on B merges cleanly (events union). Lesson status `pending` with a closed decision → `W_STALE_PENDING`, fixed by `check --fix` (→ open, or effect already applied).

Same lesson in two experts (moved on one branch, confirmed in place on the other): `W_DUP_BLOCK` (cross-file). `check --fix` keeps the block at the location named by the latest `lesson.moved` event, with `confirmations` = max of both.

Expert retired on one branch, lessons recorded into it on the other: git reports modify/delete conflict; once resolved, a dir with `lessons.md` but no `EXPERT.md` → `E_ORPHAN_DIR`; `check --fix` moves its lessons to `_unassigned` and removes the dir.

Cross-branch ID collision (same random ID on both sides, ~1/16M per pair): `check` reports `E_DUP_ID`; `check --fix` re-IDs the newer item and logs `lesson.moved`/`rule.edited` with `reason: reid`.

## Hand edits

- Any file may be hand-edited. Binary re-parses every call; no cached content state.
- Hand-deleted rule/lesson referenced by an open decision → decision.cancelled on next writing command.
- Hand-added expert dir with valid EXPERT.md → picked up; `W_REGISTRY_DRIFT` until `index`.

## Size bounds

| Item | Bound | On exceed |
|---|---|---|
| EXPERT.md | 64 KiB | E_FILE_TOO_LARGE (read refused for that expert; check reports) |
| lessons.md | 256 KiB | record into it refused E_FILE_TOO_LARGE; say: curate |
| log year file | none | yearly rotation bounds diffs |
| experts | 100 | spawn/split refused E_TOO_MANY_EXPERTS |
