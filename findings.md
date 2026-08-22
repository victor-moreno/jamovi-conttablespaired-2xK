# Findings

## Repo layout (symlinks already in jamovi-mcnemar-OR/)
- `jamovi-conttables-2xK` -> `/Users/h501uvma/Downloads/claude/jamovi/jamovi-conttables-2xK`
- `jamovi-src` -> `../jamovi-src` (contains `jmv` and `jmvcore` git submodules)

## Original jmv paired module (source of truth to clone)
Path: `jamovi-src/jmv/`
- `R/conttablespaired.b.R` — backend. Key points:
  - `.cleanData()`: selects rows/cols/counts, `naOmit`, coerces rows/cols to factor
  - `.run()`: builds `result <- stats::xtabs(countCol ~ rowVar + colVar)` or `base::table(rowVar, colVar)`
  - Tests computed: `stats::mcnemar.test(result, correct=FALSE)`, `correct=TRUE`,
    and `exact2x2::exact2x2(result, paired=TRUE)` (reported oddly as "Log odds
    ratio exact" test row: `value[exa] <- log(exact$estimate)`, `p[exa] <- exact$p.value`)
  - Error message translation: "'x' must be square with at least two rows and
    columns" -> "McNemar requires a 2x2 table"; "all entries of 'x' must be
    nonnegative and finite" -> "Counts must be non-negative and finite"
  - `.init()`: builds freqs table columns — ONE physical row per row-category
    (+ Total row), NOT stacked sub-rows. Sub-statistics (count/pcRow/pcCol) are
    laid out as adjacent leading "type[X]" text-label columns (visible only
    when >1 stat selected, to disambiguate) plus per-column-category numeric
    sub-columns under a superTitle = colVarName. `.grid(incRows=TRUE)` only
    expands the row variable's levels + '.total' — confirmed there is no
    subtype dimension in the row grid.
  - `test$addRow(rowKey=1, values=list())` — single row test table.
- `jamovi/conttablespaired.a.yaml` — options: rows, cols, counts, chiSq
  (default TRUE), chiSqCorr (default FALSE), exact "Log odds ratio exact"
  (default FALSE, requires exact2x2), pcRow, pcCol (both default FALSE).
  Example dataset embedded in R usage doc: 1st survey x 2nd survey,
  counts 794/150/86/570 -> chi2=17.4 (uncorrected), 16.8 (corrected).
- `jamovi/conttablespaired.r.yaml` — `freqs` table (clearWith: rows,cols,counts),
  `test` table single row with name/value/df/p triplets per test (mcn/cor/exa/n).
- `jamovi/conttablespaired.u.yaml` — VariableSupplier (rows/cols/counts targets),
  LayoutBox with chiSq/chiSqCorr/exact checkboxes, separate LayoutBox (cell
  row:1,col:1) with Label "Percentages" containing pcRow/pcCol checkboxes.

## conttables2xK module (structural pattern to mirror)
Path: `jamovi-conttables-2xK/conttables2xK/`
- DESCRIPTION: Imports jmvcore, R6, ggplot2, vcd, vcdExtra. Authors include
  Victor Moreno (user) as aut/cre/cph, plus original jmv authors preserved
  (Ravi Selker, Jonathon Love, Damian Dropmann) as aut/cph — courtesy
  attribution convention to follow for the new package too.
- `R/conttables.b.R` (full file read, 1344 lines) — key transferable patterns:
  - Table split: `chiSq` (Tests: χ², χ²corr, z-prop, likelihood ratio,
    Fisher exact, N) vs `odds` (Comparative Measures: DP, log-OR, OR, RR each
    with `cil[x]`/`ciu[x]` CI columns) — exactly the split the user wants
    replicated for McNemar (Tests vs Comparative Measures).
  - CI superTitle set dynamically in `.init()`:
    `odds$getColumn('cil[dp]')$setSuperTitle(ciText)` where
    `ciText <- jmvcore::format(.('{ciWidth}% Confidence Intervals'), ciWidth=self$options$ciWidth)`
    — reuse this pattern so the CI headers show the actual % chosen.
  - `.diffProp(mat, Ha)`: mat must be oriented 2x2 (rows=compared groups,
    cols=outcome). Uses `stats::prop.test(mat, conf.level=ciWidth,
    correct=FALSE, alternative=Ha)` for both p-value and CI — NOT hand-rolled
    Wald. For McNemar (paired) this exact approach doesn't apply (prop.test
    assumes independent samples) — must hand-roll the paired-proportions CI
    instead (see task_plan Phase 3).
  - `.relativeRisk(mat)`: hand-rolled Wald log-CI, z from
    `qnorm((100-ciWidth)/200, lower.tail=FALSE)` — same z-derivation pattern
    to reuse for the paired OR's Wald CI.
  - Reference convention comment block (lines ~607-638) is very thorough and
    a good model for documenting the paired-OR reference convention in the
    new module's own code comments / README.
  - Footnote pattern: combine multiple related notices into ONE footnote call
    per cell-group rather than several separate ones, to avoid footnote-letter
    interleaving when some columns are hidden (see lines 681-694 comment).
  - `unavailMsg` footnote pattern for when comparative measures don't apply
    (2xK condition not met) — model for the "2x2 only" footnote in the new
    module's RxR case.
- `jamovi/conttables.a.yaml` — full option list read; `ci` (Bool, default
  TRUE) + `ciWidth` (Number, min 50, max 99.9, default 95) is the exact
  pattern to reuse verbatim for the new module.
- `jamovi/conttables.r.yaml` — `odds` table visible expression:
  `visible: (diffProp || logOdds || odds || relRisk)` — reuse this
  "visible if any measure requested" pattern for the new `odds` table.
- `tools/` dir has install.sh, prepare-jmo.sh, release.sh — reuse/adapt for
  the new package's build tooling (not yet inspected in detail — inspect at
  Phase 5).

## Verified in R (2026-08-22, arm64, ~/R/.Rlib-arm) — resolves Phase 3/4 open questions

- `exact2x2::exact2x2(mat, paired=TRUE)$p.value` for the 794/150/86/570 example
  = 3.715936e-05, and plain `stats::binom.test(b, b+c, 0.5)$p.value` (b=150,
  c=86) = 3.715936e-05 — IDENTICAL. So the "exact test (binomial)" row can use
  plain base-R `binom.test` (zero new dependency, always available) and stay
  numerically consistent with the optional exact2x2-based OR CI row, without
  needing to force-share one object. Decision: use `binom.test` for
  `exactBinom`, keep `exact2x2::exact2x2(paired=TRUE, conf.level=ciWidth)`
  only for the opt-in `oddsExact` row (`$estimate`, `$conf.int`).
- exact2x2 was NOT installed in `~/R/.Rlib-arm` — installed now via
  `install.packages("exact2x2", ...)` for testing (deps: exactci, ssanv).
  Declared as `Suggests` in DESCRIPTION; code must `requireNamespace()` guard
  it like the original jmv module did.
- `stats::mcnemar.test(mat, correct=FALSE)` on a 3x3 table gives chi-sq=0.38803,
  df=3, p=0.9427 — this IS Bowker's test of symmetry (base R generalizes
  it automatically for RxR). `correct=TRUE` on the SAME 3x3 table gives an
  IDENTICAL result (no warning, correction silently only applies when
  nrow==2). Decision: reuse ONE `mcnemar.test(mat, correct=FALSE)` call,
  route its output to the "χ²" row when 2x2 or the "Bowker's test of
  symmetry" row when RxR (R>2) — no separate Bowker implementation needed.
  `chiSqCorr` stays gated to 2x2 only (separate `correct=TRUE` call).
- Verified against the a.yaml doc example (794/150/86/570): uncorrected
  chi-sq=17.356 (≈17.4), corrected=16.818 (≈16.8) — matches the doc.
- `vcd::Kappa(mat)` returns `$Unweighted` = c(value=, ASE=) (also `$Weighted`,
  identical for a plain factor table with no ordinal weights). CI via
  `confint(kappaObj, level=ciWidth)["Unweighted", c("lwr","upr")]` — verified
  signature `confint.Kappa(object, parm, level=0.95, ...)`. This works
  unchanged for RxR (tested on 3x3): kappa=0.5274, ASE=0.07562, CI
  [0.379, 0.676] at 95%.
- Observed agreement = `sum(diag(mat))/sum(mat)` — plain base R, no package
  needed. Verified 0.8525 for the 2x2 example.
- Hand-rolled Stuart-Maxwell formula (drop last category, d = (rowMarg -
  colMarg)[1:(k-1)], S[i,i] = r_i+c_i-2*mat[i,i], S[i,j] = -(mat[i,j]+mat[j,i])
  for i≠j, statistic = t(d) %*% solve(S) %*% d, df=k-1) — cross-checked
  against `DescTools::StuartMaxwellTest` on a 3x3 test matrix and matches
  EXACTLY (chi-sq=0.31718, df=2, p=0.8533 both ways). DescTools was installed
  only as a verification oracle, NOT added as a package dependency — the
  module uses the hand-rolled base-R version.
- Wald log-CI for paired OR sanity-checked against exact2x2's exact CI on the
  794/150/86/570 example: Wald [1.338, 2.274] vs exact [1.329, 2.301] — close,
  as expected (OR point estimate identical: 1.744186 = 150/86 both ways).
