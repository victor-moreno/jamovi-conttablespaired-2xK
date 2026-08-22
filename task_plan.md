# jamovi-mcnemar-OR — task plan

## Goal
Clone jmv's Paired Samples Contingency Tables (McNemar) analysis into a new module,
following the conttables2xK pattern (separate Tests / Comparative Measures tables),
adding: odds ratio (paired, b/c) + diff. in proportions with CI95%, marginal
percentages option, exact binomial McNemar test, agreement (%) + Cohen's kappa,
and — per user decision — Bowker's test of symmetry + Stuart-Maxwell test of
marginal homogeneity as the RxR generalization (shown only when applicable).

User decisions locked in (2026-08-22):
- Include Bowker/Stuart-Maxwell now (not deferred).
- Odds ratio: Wald log-CI always shown + optional "exact OR" (conditional MLE,
  exact2x2 package) checkbox with exact CI, consistent with the exact binomial
  test's p-value (same exact2x2::exact2x2(paired=TRUE) call feeds both).

## Sources of truth
- Base to clone: `jamovi-src/jmv/R/conttablespaired.b.R` + `jamovi/conttablespaired.{a,r,u}.yaml`
  (read in full already — see findings.md)
- Structural pattern to mirror (Tests vs Comparative Measures split, CI columns,
  footnote conventions): `jamovi-conttables-2xK/conttables2xK/R/conttables.b.R`
  + `jamovi/conttables.{a,r,u}.yaml` (read in full already — see findings.md)
- Build/install tooling to reuse: `jamovi-conttables-2xK/tools/*.sh`

## Package/analysis naming
- Package: `mcnemarOR`
- Analysis name: `contTablesPairedOR`
- Menu: Frequencies > Contingency Tables > "Paired Samples (OR)", subtitle "McNemar test"

## Phases

### Phase 0 — Setup (complete)
- [x] `git init` in jamovi-mcnemar-OR
- [x] Copied conttables2xK's tools/ + package skeleton, renamed to mcnemarOR
- [x] Created `mcnemarOR/` R package dir with contTablesPairedOR.* yaml/R files

### Phase 1 — Design tables (complete)
Tables:
1. `freqs` — Contingency Tables: same as original + new `pcMarg` sub-column
   (marginal % — populated only on the Total column per row, and on the Total
   row per column; NaN/blank on interior cells)
2. `test` — McNemar Tests: χ², χ² continuity-corrected (unchanged), NEW: Exact
   test (binomial) via `stats::binom.test(b, b+c, 0.5)` (only meaningful 2x2).
   For RxR: Bowker's test of symmetry + Stuart-Maxwell test of marginal
   homogeneity rows/table, only populated when nrow(mat)==ncol(mat) > 2.
3. `odds` — Comparative Measures (NEW table, mirrors conttables2xK "odds"):
   Odds ratio (Wald log CI) + optional Exact OR (conditional MLE, exact2x2,
   exact CI) + Difference in proportions (Wald CI). 2x2 only; footnote
   "Available for 2x2 tables only" otherwise. Reference = first level for
   both rows and cols (effect = second level), per user instruction.
4. `agree` — Agreement (NEW table): Observed agreement % (trace/N) + Cohen's
   kappa (via `vcd::Kappa`, unweighted) with CI. Works for any RxR.

Auto footnote/notice: when b+c < 25 (small discordant-pair count), a Notice
recommending the exact test (mirrors Fisher-exact-style UX in conttables2xK).

### Phase 2 — Options (.a.yaml) (complete)
- rows, cols, counts (unchanged)
- chiSq (default TRUE), chiSqCorr (default FALSE)
- exactBinom "Exact test (binomial)" (default FALSE)
- symmetry "Bowker's test of symmetry" (default TRUE, RxR only)
- margHom "Stuart-Maxwell test of marginal homogeneity" (default TRUE, RxR only)
- oddsRatio "Odds ratio" (default TRUE), oddsExact "Exact odds ratio (conditional MLE)" (default FALSE)
- diffProp "Difference in proportions" (default TRUE)
- ci (default TRUE), ciWidth (default 95)
- pcRow, pcCol (unchanged, default FALSE), pcMarg "Marginal" (default FALSE)
- agreement "Observed agreement" (default TRUE), kappa "Cohen's kappa" (default TRUE)

### Phase 3 — Backend (.b.R) (complete)
- `.pairedOR(b,c,z)`: Wald log CI on b/c, Haldane-Anscombe correction when
  b or c is 0
- `.diffPropPaired(mat,z)`: (b-c)/n with Wald CI (Fleiss formula)
- Exact test (binomial): plain `stats::binom.test(b,b+c,0.5)` — confirmed
  numerically IDENTICAL to `exact2x2::exact2x2(paired=TRUE)$p.value`
  (3.715936e-05 both ways on the survey example), so no shared-object
  plumbing needed to keep them consistent; exact2x2 used ONLY for the
  opt-in `oddsExact` row (estimate + exact conf.int)
- Bowker's test of symmetry: NOT hand-rolled — confirmed
  `stats::mcnemar.test(mat, correct=FALSE)` already computes it for RxR
  (R>2); routed to the "χ²" row when 2x2, "Bowker's" row when RxR
- `.stuartMaxwell(mat)`: hand-rolled, cross-checked exactly against
  `DescTools::StuartMaxwellTest` on a 3x3 matrix (statistic, df, p all match
  to displayed precision)
- Kappa/agreement: `vcd::Kappa(mat)` + `confint(kappaObj, level=ciWidth)`,
  `sum(diag(mat))/sum(mat)` — both work unchanged for RxR

### Phase 4 — Test (complete)
- Installed `exact2x2` (Suggests) and, as a verification-only oracle,
  `DescTools` (NOT a package dependency) into `~/R/.Rlib-arm`
- `R CMD INSTALL --library=~/R/.Rlib-arm .` for headless testing (jmvtools's
  own `install()` hit a SingletonLock sandbox error — see progress.md)
- Formal testthat suite added: `mcnemarOR/tests/testthat/testcontTablesPairedOR.R`
  — 4 test_that blocks (2x2 full oracle check, marginal %, RxR
  Bowker/Stuart-Maxwell/kappa, non-square graceful degradation).
  **35/35 assertions pass** (`testthat::test_dir(...)`)

### Phase 5 — Build & install (complete, with a caveat)
- Adapted conttables2xK's tools/install.sh, prepare-jmo.sh, release.sh for mcnemarOR
- `bash tools/install.sh desktop` compiles cleanly and produces
  `mcnemarOR/mcnemarOR_0.1.0.jmo`, but jmvtools could not drive jamovi.app to
  sideload it (SingletonLock permission error in this sandbox — jamovi.app
  was NOT running, so this is a sandbox/permissions artifact, not a real
  conflict). The .jmo is built and ready; the user needs to sideload it by
  hand once: jamovi -> Modules -> Sideload -> select
  `mcnemarOR/mcnemarOR_0.1.0.jmo` (same fallback conttables2xK's own
  install.sh already documents for this exact failure mode).

### Phase 6 — Docs & commit (complete)
- [x] README.md written
- [x] git commit (3d21d0d)

## Decisions log
- 2026-08-22: User chose to include Bowker/Stuart-Maxwell now, and Wald+optional-exact
  for OR CI (see AskUserQuestion above).

## Errors log
(none yet)

### Phase 7 — Rename to conttablespaired2xK + i18n (complete)
User asked (2026-08-22, follow-up turn) to rename before installing:
- Outer repo dir: jamovi-mcnemar-OR -> jamovi-conttablespaired-2xK (explicit
  exception granted to the sandbox "no parent-folder writes" rule, for this
  one `mv`, since the CLAUDE.md rule would otherwise block renaming my own
  starting folder)
- R package: mcnemarOR -> conttablespaired2xK
- Analysis identifier reverted to `contTablesPaired` (matching jmv upstream
  exactly, NOT `contTablesPairedOR`/`contTablesPaired2xK`) — discovered by
  re-checking conttables2xK's own convention: it keeps jmv's original
  `contTables` identifier unchanged and rebrands only at the
  package/repo/menu level (`ns: conttables2xK`, menuTitle "(2xK)"). Applied
  the same pattern here: file basenames, R6 class names, and the exported R
  function are all `contTablesPaired`/`conttablespaired.*`, matching
  upstream jmv 1:1; only DESCRIPTION/0000.yaml/menuTitle/menuSubtitle carry
  the "2xK" rebrand. Documented in README under "Naming: package vs.
  analysis identifier".
- Menu: menuTitle "Paired Samples (2xK)", menuSubtitle "McNemar, Bowker &
  Stuart-Maxwell" — English (user's explicit choice), but with real i18n
  infrastructure: `jamovi/i18n/es.po` + `ca.po` generated via
  `jmvtools::i18nCreate()` (NOT copied wholesale from jmv's huge upstream
  catalog like conttables2xK's own `.po` files are — ours only contains this
  module's own 61 strings) and hand-translated in full (both files, 61/61
  entries, verified via a proper multi-line-aware .po parser, zero empty).
- Rebuilt (`bash tools/install.sh desktop`) and reinstalled for headless
  testing under the new name — **35/35 testthat assertions still pass**.
  jmc compiled es.po/ca.po into inst/i18n/{es,ca}.json without error; spot
  checked translated strings landed correctly in the compiled JSON.
- Found and fixed an `i18nUpdate()` quirk: it duplicated one long msgstr
  (appended instead of replaced) across two update runs. Fixed by hand,
  documented as a caveat in README so it isn't silently reintroduced next
  time someone runs `i18nUpdate()`.

## Next Step
All phases complete, including the rename. Only remaining item: the user
sideloads the built .jmo (`conttablespaired2xK/conttablespaired2xK_0.1.0.jmo`,
rebuild via `bash tools/install.sh desktop` if needed) by hand once via
jamovi -> Modules -> Sideload (SingletonLock sandbox issue prevented
jmvtools from doing this automatically), and eyeballs the real UI rendering
(footnote letters, options panel layout, Spanish/Catalan display when jamovi
is set to those languages) since that hasn't been visually verified, only
R-level computation.
