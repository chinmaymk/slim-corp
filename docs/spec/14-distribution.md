# 14 — Distribution & Versioning

## Build

- Language: Go. Single static binary, `CGO_ENABLED=0`.
- Targets: linux/{amd64,arm64}, darwin/{amd64,arm64}, windows/{amd64,arm64}.
- Size target: ≤10 MB (v1, no embeddings); ≤40 MB with static embeddings (separate build `experts-embed`).
- Dependencies: stdlib + YAML-subset parser + TOML parser + Snowball stemmer + doublestar glob. No net packages (CI asserts via `go list -deps` denylist: `net/http`, `net` except `net/url` parse-only if needed).
- Reproducible builds (`-trimpath`, fixed `-ldflags`, `SOURCE_DATE_EPOCH`).

## Release

- Artifacts: binaries, `SHA256SUMS`, signature (cosign keyless or minisign).
- Install paths (user's choice, none required):
  1. Download release asset to PATH.
  2. `go install <module>/cmd/experts@<version>`.
  3. Vendored: `.experts/bin/experts` (gitignored by default; teams may commit it deliberately).
- Discovery order used by protocol: `experts` on PATH, then `.experts/bin/experts[.exe]`.

## Versions

| Thing | Scheme | Bumps when |
|---|---|---|
| Binary | semver | major: CLI/output incompatible; minor: new commands/fields, normalization changes; patch: fixes |
| `schema_version` (config) | int | file format incompatible change |
| Event `v` | int | event payload incompatible change |
| Protocol | `v<N>` in PROTOCOL.md | protocol text changes |
| AGENTS.md block | `v<N>` in marker | block text changes |

Output compatibility: within a major version, existing keys/statuses/exit codes never change meaning; new keys may appear. Agents MUST ignore unknown keys.

## Schema compatibility

Binary declares `[min, max]` schema.

| Repo schema | Read commands | Write commands |
|---|---|---|
| < min | allowed, `warn` | E_SCHEMA_OLDER → `experts migrate` |
| min..max | allowed | allowed |
| > max | E_SCHEMA_NEWER | E_SCHEMA_NEWER |

## migrate

```
experts migrate [--dry-run]
```

- Applies ordered migrations `n → n+1` up to binary max, in one txn.
- Each migration: pure function over files; emits event `schema.migrated {from, to}`.
- `--dry-run`: prints files that would change; no writes.
- Also refreshes PROTOCOL.md and AGENTS.md block if versions are older.
- Never runs implicitly.
