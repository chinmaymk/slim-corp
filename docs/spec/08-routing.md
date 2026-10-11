# 08 — Routing & Scan

## Globs

- Relative to root, `/` separators, case-sensitive.
- `*` = any chars except `/`. `?` = one char except `/`. `**` = zero or more path segments (only as a whole segment). `[abc]`, `[a-z]` classes. `{a,b}` alternation.
- Prefix `!` = exclusion. A file is in scope iff it matches ≥1 non-negated glob and no negated glob.
- Directory glob without wildcard (`src/billing`) is treated as `src/billing/**`.
- Files considered: tracked files (`git ls-files`) if git available; else walk root, skipping `.git/`, `.experts/`, and `.gitignore` matches (root `.gitignore` only).

## route

Input: files F (may be empty), task text T (may be empty). Paths outside root: ignored, `W_PATH_IGNORED`. Nonexistent paths inside root (files about to be created): matched by glob only.

Score per expert E (excluding `_unassigned` and the `always` expert):

```
scope(E)    = 1.0 if any f ∈ F in scope(E) else 0
trig(E)     = 0.5 × |{trigger t ∈ E : t matches T}|, capped at 1.0
cochange(E) = 0.3 if no f ∈ F in scope(E) but some f ∈ F co-changes (scan cache, Jaccard ≥ 0.3) with a file in scope(E), else 0
score(E)    = scope + trig + cochange
```

Trigger match: trigger normalized (07 steps 1–5) and matched as a contiguous token subsequence of normalized T.

Selection:

0. The `always` expert (03), if present and readable, is included first. It does not count toward `--max`; it does count toward `route_tokens`.
1. Candidates: score ≥ 0.5.
2. Sort: score desc, then number of files in F matched desc, then name asc.
3. Take up to `--max` (default `route_max`).
4. Token cap: add experts in order while Σ tokens(E) ≤ `route_tokens`; an expert that would exceed is skipped (`W_ROUTE_TOKEN_CAP`), continue with next.

Output:

```
status: ok
expert: billing-ledger
expert: api-auth
load: .experts/billing-ledger/EXPERT.md
load: .experts/api-auth/EXPERT.md
why: billing-ledger scope=src/billing/refund.ts trig=refund score=1.5
why: api-auth scope=src/api/middleware.ts score=1.0
tokens: 2310
say: billing-ledger has 34 open lessons (cap 30); suggest "curate experts" to the user
```

No specific match → only the `always` expert (if any) is returned, plus `say: no specific expert matches; proceed normally`.

Nudges (say), at most 2, priority order:

1. Open decisions exist → `N open decisions; run "experts pending"`.
2. Active loop → `loop <kind> in progress; "experts <kind>" to resume`.
3. Routed expert lessons > `lessons_per_expert`.
4. Inbox entries > `inbox_max`.
5. Routed expert has stale rules ≥ 5 → suggest verify.

`--log`: appends event `route`. Default off (16).

## scan

Deterministic survey; writes `.experts/.cache/scan.json`; prints summary.

| Output | Method |
|---|---|
| manifests | Files named: package.json, go.mod, Cargo.toml, pyproject.toml, requirements*.txt, Gemfile, pom.xml, build.gradle*, composer.json, *.csproj, mix.exs, pubspec.yaml, Package.swift, CMakeLists.txt, Makefile, Dockerfile, docker-compose*.yml, *.tf. Path + detected framework names from dependency keys (fixed table in binary). |
| areas | Directories at depth ≤3 holding ≥5% of tracked files or a manifest. Path + file count + dominant extension. |
| cochange | From `git log --name-only --no-merges -n <max-commits> [--since]`. Skip commits touching >50 files. For file pairs co-occurring ≥3 times: Jaccard of commit sets. Clusters: union-find at Jaccard ≥ 0.3; keep clusters of ≥3 files; summarize each by longest common path prefix + top 5 files. |
| hotspots | Per file: commits in window × recency weight (`0.5^(age_days/90)`). Top 20. |
| docs | README*, docs/**, ADR dirs (`adr`, `adrs`, `decisions`), CONTRIBUTING*, ARCHITECTURE*. |

Without git: manifests, areas, docs only; `W_NO_GIT`.

`scan.json` is cache: never committed, regenerated when older than HEAD commit time or on `scan`. Route reads it if present; absent → cochange term = 0.
