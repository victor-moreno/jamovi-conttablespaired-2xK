# Progress log

## 2026-08-22 (fix broken [0] reference marker)

User reported: activating kappa shows a `[0]` — a broken/unresolved reference marker. Root cause:
`conttablespaired.r.yaml` had `refs: vcd` (kappa) and `refs: exact2x2` (exact odds ratio) from the
very first build, but the package never had a `jamovi/00refs.yaml` defining what those keys
actually cite — so BOTH were broken from day one, not just kappa (the user just happened to notice
it via kappa first).

Fixed by creating `jamovi/00refs.yaml` with a top-level `refs:` key (required — silently produces
nothing without it, per jamovi-skill's own trap list). Reused jmv's own `vcd`/`exact2x2` entries
verbatim (found via `jamovi-src/jmv/jamovi/00refs.yaml` — jmv cites both too), and added the three
citations the user asked for: McHugh (2012) for kappa, Bowker (1948) for the symmetry test, Stuart
(1955) for Stuart-Maxwell. Wired them onto the relevant r.yaml columns using `refs: [ vcd,
mchugh2012 ]` list syntax (confirmed this multi-ref syntax works by finding jmv's own
`refs: [ BF, btt ]` usage in `ttestis.r.yaml` etc.).

Verified the fix landed at three independent levels rather than trusting the compile log alone:
(1) the generated `.h.R` embeds `refs="bowker1948"` etc. directly in the `addColumn()` calls,
confirming the compiler read the r.yaml correctly; (2) the extracted `.jmo`'s `refs.yaml` (compiled
from `00refs.yaml`) contains the actual citation text for all 5 keys; (3) noticed the build log now
prints `wrote: 00jmv.R` — which jamovi-skill's own docs flag as *the* tell that reference
definitions actually reached R (this file didn't get written on any earlier build, before
`00refs.yaml` existed). Committed `R/00jmv.R` as a generated-but-tracked file, matching how `.h.R`
is already handled. 43/43 tests pass locally and in Docker (unaffected — this was a
citation/footnote-only change, no computation touched).

## 2026-08-22 (example datasets, default-value changes, GitHub prep)

User changed 4 option defaults themselves in a.yaml (symmetry/margHom/agreement/kappa: true ->
false, leaning the default view down to just the classic 2x2 McNemar output) and asked for: fixing
the now-stale "TRUE (default)" doc text (done, all 4), two fabricated example datasets (one 2x2
binary, one 4-category), and preparing a GitHub push via `gh`.

- Datasets: generated with `set.seed()` for reproducibility. First 4-category attempt (a strict
  "shift by exactly one category" Markov model) accidentally produced a table with a
  simultaneously-zero (i,j)/(j,i) discordant cell pair (None<->Severe) -- confirmed this is a real
  limitation of base R's own `stats::mcnemar.test()` (returns statistic=NaN, not a bug I
  introduced) by reproducing it directly against the raw matrix. Fixed by switching to a
  continuous-latent-severity + normal-noise generation model (allows occasional bigger jumps),
  which avoids the structural zero and gives a clean, significant Bowker's/Stuart-Maxwell result.
  Registered both via `datasets:` in `0000.yaml` (jmv's own format, confirmed by inspecting
  `jamovi-src/jmv/jamovi/0000.yaml`) -- verified this key survives `jmc`'s regeneration of
  `0000.yaml` on rebuild, and that `jmc --install` actually copies the CSVs into the `.jmo`
  (checked with `unzip -l`).
- Discovered and fixed a real `asDF()` gap while updating tests for the new defaults: when BOTH
  `agreement` and `kappa` are off (the new default), the "Agreement" table has zero visible
  columns, and calling `.asDF()` on it throws `invalid 'row.names' length` -- confirmed this is a
  jmvcore-level edge case (fully-invisible-table + explicit `asDF()` call) and NOT something the
  real GUI hits (verified `print()` on a fully-default analysis renders cleanly, Agreement section
  just doesn't appear at all, no error) -- so left it as a documented, regression-tested caveat
  rather than trying to patch jmvcore itself.
- Fixed all my own testthat calls that relied on the old TRUE defaults (several didn't explicitly
  pass `symmetry`/`margHom`/`agreement`), plus added a dedicated test locking in both the safe
  print() path and the asDF() caveat above.
- Improved `tools/install.sh docker`: it previously needed a manual second `tar` + `docker exec`
  step to get `tests/` into the container for a full suite run (mentioned nowhere in the script
  itself, I'd been doing it by hand each time). Now copies `data/` and `tests/` automatically
  (conditionally, if present) and runs `testthat::test_dir()` inside the container as part of the
  normal `bash tools/install.sh docker` call -- matches the user's standing "Docker is the primary
  verification path" instruction without the manual dance.
- **43/43 tests pass, both locally and in Docker** (up from 41 -- 2 new: the datasets round-trip
  implicitly via the existing oracle tests still passing, plus the new default-options test).

## 2026-08-22 (kappa CI investigation, table/label renames)

User reported kappa's 95% CI "doesn't appear" despite my prior verification showing it populated
in `asDF`. Investigated properly instead of re-asserting the same check:
- `asDF` and column `$visible` both confirmed correct/TRUE (not the bug).
- `print(r$agree)` (R console `asString`/`fold()`) showed something suspicious: the CI values
  visually appeared next to "Observed agreement" instead of "Cohen's kappa". Traced this to
  `jmvcore`'s `fold()` function (`jamovi-src/jmvcore/R/table-fold.R`) — confirmed by reading its
  source that this "unstack bracket-suffixed column groups into pseudo-rows" logic is used ONLY by
  the R-console print method, not by the actual browser/JS client, so the misalignment I saw is an
  R-print-only artifact, not proof of a real GUI bug. BUT it revealed a genuine structural issue:
  my `agree` table had ASYMMETRIC column groups (`t[obs]`/`v[obs]` with no CI columns, vs.
  `t[kap]`/`v[kap]`/`cil[kap]`/`ciu[kap]` with CI columns) — every other multi-measure table in
  this codebase (and in the reference `conttables2xK`) keeps groups symmetric. Since I couldn't
  directly inspect the real browser DOM from this environment, and the asymmetry is a real,
  identifiable deviation from the established (working) pattern, fixed it as the most defensible
  path: added a genuine 95% CI for "Observed agreement" too (`stats::prop.test`, matching how
  `conttables2xK` computes its own proportion CIs), making both rows symmetric. This is both a
  plausible fix for whatever the user is seeing AND a legitimate standalone improvement (a CI for
  agreement is a natural thing to want). After the fix, `print()`'s fold() view is now also clean
  (each measure correctly shows its own Value/Lower/Upper) — a good sign, though not 100%
  conclusive proof for the real browser without the user's own visual check.
- Separately fixed two literal requests: table title "McNemar Tests" -> "Paired Tests"; "χ²" row/
  option label -> "McNemar χ²" (and, for consistency, "χ² continuity correction" ->
  "McNemar χ² continuity correction", since it sits in the same table as Bowker's/Stuart-Maxwell's
  own χ²-based statistics and would look inconsistent unprefixed).
- Discovered along the way (jamovi-skill trap, confirmed the hard way): after editing a.yaml/
  r.yaml to ADD new columns, `R CMD INSTALL` alone is not enough for headless testing — the
  generated `.h.R` (which defines the R6 base class with the column accessors) is stale until
  `bash tools/install.sh desktop` (i.e. `jmc`) regenerates it. Hit
  `Table$getColumn(): col 'cil[obs]' not found` the first time, diagnosed and fixed by rebuilding
  properly before reinstalling.
- Updated es/ca i18n by hand for the 3 renamed/new strings (no i18nUpdate(), still avoiding its
  duplication bug). Updated + extended tests (added cil[obs]/ciu[obs] oracle assertions via
  `stats::prop.test`, computed independently). **41/41 pass, both locally and in Docker.**

## 2026-08-22 (3 small fixes: blank pcMarg cells, agreement as proportion, kappa CI)

User asked for three things:
1. Interior cells in the freqs table, when marginal % is requested, should show blank ('') instead
   of NaN. Fixed: had to restructure the values-building code since `c()` on a mix of numeric and
   character vectors coerces everything to character — built the numeric part (counts/pcRow/pcCol)
   first, then merged in a separately-built list of `''` for pcMarg's interior cells via list
   concatenation (`c(list, list)`, which preserves each element's type unlike atomic-vector `c()`).
   Confirmed `''` round-trips to `NA` (not the literal string) in a Number-typed column's `asDF` —
   exactly the "renders as blank, not as text" outcome wanted.
2. Observed agreement should show as a 0-1 proportion, not a %, to match kappa's scale. The
   underlying computed value was ALREADY a proportion (`sum(diag(mat))/N`) — only the r.yaml
   column had `format: pc` (a pure display multiplier) turning it into a percentage on screen.
   Removed `format: pc`, retitled the column 'Value' (matching kappa's own column). No R code or
   test changes needed for this one, since `asDF` always returned the raw proportion regardless of
   display format.
3. Add a 95% CI for kappa — already implemented since the very first build
   (`cil[kap]`/`ciu[kap]`, populated via `confint(vcd::Kappa(...), level=ciWidth)`). Verified with a
   fresh headless run it's genuinely there and populated (0.664, 0.735 on the worked example) rather
   than assuming from memory — told the user it was already done instead of silently no-op'ing.

Updated the pcMarg test (`is.nan()` -> `is.na()`) and both es/ca i18n files (dropped the now-stale
`agree.columns.title` reference comment on the shared "%" msgid, still used by the ciWidth suffix).
Verified both locally (37/37) and in Docker (37/37), per standing instruction.

## 2026-08-22 (bug fix — Bowker/Stuart-Maxwell showed NaN for 2x2)

User caught a real design bug: Bowker's test and Stuart-Maxwell were gated to `isRxR` (R > 2)
only, showing NaN + "RxR tables only" footnote for a plain 2x2 table. User's objection: "si son
generalizaciones, deberían poderse usar en el caso 2x2" — correct. Verified algebraically:
Stuart-Maxwell for k=2 reduces to `d = b-c`, `S = b+c`, `statistic = (b-c)²/(b+c)` — exactly the
uncorrected McNemar formula. Bowker's IS the same `stats::mcnemar.test()` call already used for
χ², just gated off for 2x2 for no good reason.

Fix: both now compute for any `square` table (not just `isRxR`); for 2x2 they show the same value
as the "χ²" row (expected, not a bug — that equality is the whole point of "generalization").
Removed the now-dead "Available for RxR tables only" footnote/msgid (from both es.po/ca.po, by
hand — not via `i18nUpdate()`, to avoid its known duplication bug). Updated a.yaml option
descriptions and README's "RxR generalization" section to state this correctly. Updated the 2x2
test in testthat to assert equality with 17.355932 instead of `is.nan()`.

Rebuilt and retested both ways per the user's standing instruction to use Docker as the primary
verification path: local `R CMD INSTALL` (37/37, was 35/37 + 2 new df assertions) and Docker
`tools/install.sh docker` + full `testthat::test_dir()` run inside the container (37/37, tests/
copied in separately since the docker install path only tars `DESCRIPTION NAMESPACE R jamovi`).

## 2026-08-22

- Read jmv's original `contTablesPaired` (McNemar) and conttables2xK's
  `contTables` in full to establish the clone base + structural pattern
  (Tests vs Comparative Measures split). See findings.md.
- Asked user 2 design questions (AskUserQuestion): include Bowker/Stuart-Maxwell
  RxR generalization now (chose: yes), and OR CI method (chose: Wald always +
  optional exact via exact2x2).
- Verified in R (not assumed) before designing: `mcnemar.test` on RxR already
  computes Bowker's test; `exact2x2::exact2x2(paired=TRUE)$p.value` ==
  `binom.test(b,b+c,0.5)$p.value` exactly; `vcd::Kappa`/`confint.Kappa` API;
  hand-rolled Stuart-Maxwell cross-checked against `DescTools::StuartMaxwellTest`
  (exact match). See findings.md for the numbers.
- Built the full module: `mcnemarOR` package, analysis `contTablesPairedOR`,
  4 result tables (freqs/test/odds/agree). Full option list per task_plan
  Phase 2.
- Installed `exact2x2` (Suggests, real dependency) and `DescTools`
  (verification-only oracle, NOT a dependency) into `~/R/.Rlib-arm`.
- Built via `bash tools/install.sh desktop` — compiled cleanly, produced
  `mcnemarOR_0.1.0.jmo`. jmvtools could not drive jamovi.app to sideload it
  automatically (SingletonLock "Operation not permitted" — jamovi.app was
  confirmed NOT running via `pgrep`, so this is a sandbox permission
  artifact on the Application Support directory, not a real singleton
  conflict). conttables2xK's own install.sh has the identical fallback
  message for this exact scenario, so it's an accepted pre-existing
  limitation of this environment, not something introduced by this module.
  **User action needed**: sideload `mcnemarOR/mcnemarOR_0.1.0.jmo` by hand
  once via jamovi -> Modules -> Sideload.
- For headless testing, installed the R package directly into
  `~/R/.Rlib-arm` via `R CMD INSTALL` (bypasses jamovi.app entirely).
- Wrote and ran ad-hoc oracle scripts (`.tmp/test_headless.R`,
  `test_rxr.R`, `test_pcmarg.R`) validating: 2x2 chi-sq/corrected/exact-binom/
  OR/exact-OR/DP/kappa/agreement against known values; 3x3 Bowker/
  Stuart-Maxwell against DescTools; non-square graceful degradation (no
  errors, NaN + footnotes); marginal % correctly blank on interior cells,
  populated on Total row/column.
- Formalized these into `mcnemarOR/tests/testthat/testcontTablesPairedOR.R`
  (4 test_that blocks). **Result: 35/35 assertions pass.**
- Fixed one bug found during ad-hoc testing: my own hand-computed oracle
  value for the continuity-corrected chi-sq was wrong (16.818386 instead of
  the correct 16.817797) — the module's output was correct; the test
  expectation was wrong. Corrected the test, re-ran, passed.
- Cleaned up 3 redundant re-declarations of `b <- result[1,2]; c <- result[2,1]`
  in `.run()` (consolidated to one, right after the shape checks) and one
  dead `names(rowTotal) <- ...` line, during review before finalizing.

## 2026-08-22 (follow-up turn — rename)

User asked to rename before installing, to foreground the RxR/non-binary
capability: outer repo -> `jamovi-conttablespaired-2xK`, package ->
`conttablespaired2xK`, menu -> "Paired Samples (2xK)" / "McNemar, Bowker &
Stuart-Maxwell", plus real es/ca i18n.

- Asked 2 clarifying questions first (AskUserQuestion): outer-folder rename
  conflicted with my own CLAUDE.md sandbox rule ("no parent-folder writes"),
  so I asked for explicit authorization rather than just doing it or
  refusing outright — user authorized it. Also asked English-vs-literal-
  Spanish for the menu text — user chose English + asked for es.po/ca.po too.
- `mv`'d the outer directory; git history intact (verified `git status`
  right after — only showed my own uncommitted task_plan.md edit, nothing
  from the move itself, as expected for a plain directory rename).
- `git mv`'d the package dir and every yaml/R/test file inside it.
- Re-examined conttables2xK's actual convention before renaming the analysis
  identifier: it does NOT rename the analysis itself (`contTables` stays
  `contTables`), only the package/repo/menu. Corrected course from my first
  pass (which had invented `contTablesPairedOR`) back to plain
  `contTablesPaired`, matching upstream jmv exactly — this is a better,
  more-precedent-consistent design than what I shipped in the first commit.
- Used `jmvtools::i18nCreate("es")`/`i18nCreate("ca")` (discovered via
  `ls("package:jmvtools")`) rather than hand-authoring `.po` files or
  copying conttables2xK's enormous (6000+ line, mostly-irrelevant) inherited
  catalog. Got a clean 61-string extraction scoped to just this module.
  Hand-translated both languages, reusing established jmv-ecosystem
  terminology where I could find precedent in conttables2xK's own catalog
  (e.g. "df"->"gl", "Lower"->"Más bajo" es / "Inferior" ca, "Row"->"Fila")
  — and DELIBERATELY did NOT copy Catalan "Count"/"Frequencies", whose
  existing translations in conttables2xK's ca.po look swapped
  ("Count"->"Freqüència", "Frequencies"->"Recompte") — used the
  semantically-correct pairing instead ("Recompte"/"Freqüències").
- Hit and fixed a real `jmvtools::i18nUpdate()` bug: running it a second
  time duplicated one long already-translated msgstr (appended instead of
  replaced) for both languages. Caught it with a proper multi-line-aware .po
  parser (my first naive line-based check gave a false "still empty"
  reading — the content wasn't empty, it was wrapped `msgstr ""` + quoted
  continuation, which is valid PO syntax my quick script didn't handle).
  Fixed by hand, did not re-run i18nUpdate afterward, documented the caveat
  in README so it doesn't get silently reintroduced.
- Rebuilt end-to-end after all renames; reinstalled into `~/R/.Rlib-arm` for
  headless testing; **35/35 testthat assertions still pass** under the new
  name. Spot-checked the compiled `inst/i18n/es.json` to confirm translated
  strings survived compilation intact (no duplication, correct content).

## Still open
- The real jamovi.app GUI rendering (footnote letters, column layout,
  options panel, and now Spanish/Catalan display when jamovi's UI language
  is switched) has NOT been visually verified — only the R-level computation
  and table `asDF` values. The user should sideload and take a look before
  relying on this for real analysis. This mirrors the same caveat noted for
  headless testing throughout jamovi-skill's own guidance.
- Not yet committed to git (this rename batch).
