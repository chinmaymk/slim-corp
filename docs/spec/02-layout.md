# 02 — Layout

## Root

`root` = nearest ancestor of cwd containing `.experts/`. If none: git top-level (for `init` only). `--root <dir>` overrides. Nested `.experts/` below root: ignored, `check` warns `W_NESTED_ROOT`.

## Tree

```
<root>/
  AGENTS.md                        # contains experts block (10-integration)
  CLAUDE.md, GEMINI.md, ...        # pointer files (10-integration)
  .gitattributes                   # merge drivers (below)
  .gitignore                       # ignore entries (below)
  .experts/
    config.toml
    PROTOCOL.md                    # agent procedures; owned by binary, regenerated on upgrade
    registry.md                    # derived index
    _inbox.md                      # no-binary lesson drop
    _unassigned/
      lessons.md
    <expert>/
      EXPERT.md
      lessons.md                   # may be absent = no lessons
    log/
      <YYYY>.jsonl                 # events, one file per UTC year
    .cache/                        # derived, ignored
      scan.json
      index.bin
    .lock                          # transient, ignored
    .txn.json                      # transient, ignored
    bin/                           # optional vendored binary, ignored
```

Directory names under `.experts/` beginning with `_` or `.` are reserved. Other directories MUST be valid expert names (03) and contain `EXPERT.md`; otherwise `check` reports `E_ORPHAN_DIR`.

## Committed vs ignored

| Path | Git |
|---|---|
| `config.toml`, `PROTOCOL.md`, `registry.md`, `_inbox.md`, `_unassigned/`, `<expert>/`, `log/` | committed |
| `.cache/`, `.lock`, `.txn.json`, `bin/` | ignored |

## `.gitignore` entries (added by init)

```
.experts/.cache/
.experts/.lock
.experts/.txn.json
.experts/bin/
```

## `.gitattributes` entries (added by init)

```
.experts/log/*.jsonl        merge=union
.experts/*/lessons.md       merge=union
.experts/_inbox.md          merge=union
.experts/registry.md        linguist-generated=true
```

Union merge can duplicate keys inside one lesson block when both branches mutate it; `check --fix` repairs (11).
