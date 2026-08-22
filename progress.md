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
