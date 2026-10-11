# 07 — Similarity

Offline, deterministic, no model (v1). Used by: record (duplicate/related), search, clustering (curate promote, spawn), merge candidate detection, compress context.

## Normalization

Applied to every text (lesson text, rule text, query):

1. Unicode NFKC; lowercase.
2. Extract code identifiers before splitting: backticked spans, and tokens matching `[A-Za-z_][A-Za-z0-9_]*` that contain `_`, a lower→upper transition, or a `.` between identifier chars (`refund.create`). Keep each identifier whole as an **ident token**.
3. Split remaining text on non-alphanumerics; split camelCase and snake_case parts into **word tokens**.
4. Drop stopwords (fixed English list, shipped in binary, versioned with binary).
5. Stem word tokens: Snowball English (Porter2). Ident tokens not stemmed.
6. Drop tokens of length 1. Numbers kept.

Determinism: stopword list and stemmer are fixed per binary version. Changing them is a minor version bump (14) and does not migrate data.

## Corpus

`C` = all active rules + all lessons (open, pending) + inbox entries being ingested + the query. Built per call. `N = |C|`.

`idf(t) = ln(1 + (N + 1) / (df(t) + 1))`

## Score

For texts `a`, `b`:

```
w(t)   = idf(t) × (2 if ident token else 1)
cos    = Σ_{t∈A∩B} w(t)² / ( sqrt(Σ_{t∈A} w(t)²) × sqrt(Σ_{t∈B} w(t)²) )   # A, B = token sets
jac    = |S(a) ∩ S(b)| / |S(a) ∪ S(b)|                                      # S = word-token bigrams, in order
score  = 0.7 × cos + 0.3 × jac
```

- Empty token set → score 0.
- Identical normalized token sequences → score 1.0 (short-circuit).
- Rounded to 2 decimals for output and threshold comparison.

## Thresholds

From config `[similarity]`: `duplicate` (default 0.80), `related` (default 0.45). MUST hold `0 < related < duplicate ≤ 1` → else E_CONFIG.

## Clustering

Single-link, threshold `related`, over a given lesson set:

1. Sort lessons by ID.
2. Union-find: for each pair (i<j) with score ≥ related, union.
3. Cluster order: as specified by consumer (06); ties by smallest member ID.
4. Centroid text (for context lookups) = concatenation of member texts.

Complexity: O(n²) pairs; n is bounded by caps (≤ few hundred). If n > 2000, `W_CLUSTER_TRUNCATED` and only the newest 2000 are clustered.

## Expert-pair rule similarity (merge detection)

`mean over rules r in A of max over rules s in B of score(r, s)`, symmetric average of A→B and B→A. Experts with 0 rules → 0.

## Calibration (M3)

`experts calibrate` prints the score distribution of all lesson/rule pairs and of known merges/replacements from the log, to tune thresholds. Read-only.

## v2: static embeddings (M3, optional)

- Embedded static token-embedding table (≤30 MB), mean-pooled, cosine.
- `score_v2 = max(score_v1, emb_cos)` for duplicate/related; clustering uses `emb_cos`.
- Enabled by `[similarity] engine = "static-embed"`; absent table → fall back to v1 with `W_ENGINE_FALLBACK`.
- Thresholds are per engine: `[similarity.static-embed] duplicate/related`.
