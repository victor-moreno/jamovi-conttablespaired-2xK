# Progress log

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

## Still open
- README.md not yet written.
- Not yet committed to git.
- The real jamovi.app GUI rendering (footnote letters, column layout,
  options panel) has NOT been visually verified — only the R-level
  computation and table `asDF` values. The user should sideload and take a
  look before relying on this for real analysis. This mirrors the same
  caveat noted for headless testing throughout jamovi-skill's own guidance.
