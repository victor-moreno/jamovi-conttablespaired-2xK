# conttablespaired2xK

A [jamovi](https://www.jamovi.org) module that clones jmv's **Paired Samples Contingency Tables**
(McNemar test) analysis, restructures its output to separate hypothesis tests from comparative
measures (mirroring [conttables2xK](../jamovi-conttables-2xK)), and extends it — including to a
**non-binary paired response** (RxR tables, not just 2x2) — with:

- a **paired odds ratio** (b/c, Wald log confidence interval) and an optional **exact odds ratio**
  (conditional MLE with an exact confidence interval, via `exact2x2`);
- a **difference in (paired) proportions**, with a Wald confidence interval;
- an **exact McNemar test based on the binomial distribution**;
- **marginal percentages** in the frequency table (the percentages that actually matter for a
  paired design — row/column totals as a share of N — as opposed to the within-row/within-column
  percentages, which compare the wrong margin for matched data);
- **observed agreement** and **Cohen's kappa**, with a confidence interval;
- for **RxR tables** (more than two paired categories): **Bowker's test of symmetry** and the
  **Stuart-Maxwell test of marginal homogeneity**, the natural generalizations of McNemar's χ² and
  the difference-in-proportions test respectively.

Appears in jamovi's menu as **Frequencies > Contingency Tables > Paired Samples (2xK)** (subtitle:
"McNemar, Bowker & Stuart-Maxwell"), alongside jmv's own "Paired Samples" entry.

## The paired odds ratio and difference in proportions: reference convention

Reference category = the **first level**, for both the rows and the columns variable (they should
share the same two categories, measured on two occasions or under two conditions). The **second**
level is the "effect" category — the same 0/1 convention used in `conttables2xK` and in logistic
regression.

Let `b` = the count with row = reference, column = effect (moved *toward* the effect category),
and `c` = the count with row = effect, column = reference (moved *away* from it). Then:

- **Odds ratio** = `b / c` — the odds, among discordant pairs, that a pair moves toward the effect
  category rather than away from it. Confidence interval: Wald, on the log scale
  (`exp(log(b/c) ± z·√(1/b + 1/c))`); a Haldane-Anscombe correction (+0.5 to `b` and `c`) is applied
  when either is zero.
- **Exact odds ratio** (opt-in checkbox, requires the `exact2x2` package): the conditional MLE
  estimate and its exact confidence interval from `exact2x2::exact2x2(..., paired=TRUE)`.
- **Difference in proportions** = `(b - c) / N` — the difference between the two marginal "effect"
  proportions (column margin minus row margin). Confidence interval: the standard Wald formula for
  correlated proportions, `SE = √((b+c) - (b-c)²/N) / N`.
- **Exact test (binomial)**: `stats::binom.test(b, b+c, 0.5)`. Verified numerically identical to
  `exact2x2::exact2x2(paired=TRUE)`'s p-value on the worked example below (both give
  `p = 3.716e-05`), so the exact test and the exact odds ratio stay consistent with each other
  without sharing code.

All of the above are **2x2 tables only**; for RxR tables they show as unavailable with a footnote,
and Bowker's/Stuart-Maxwell's tests take over as the hypothesis tests (see below).

## RxR generalization

Bowker's test of symmetry and the Stuart-Maxwell test only appear (are non-blank) when the rows
and columns variables share the same number of categories and that number is greater than two.

- **Bowker's test of symmetry** generalizes McNemar's χ² to RxR: it is in fact the *same*
  statistic — base R's `stats::mcnemar.test()` already computes Bowker's formula for R > 2, so this
  module reuses that single call and just routes its result to the "χ²" row for 2x2 tables or the
  "Bowker's test of symmetry" row for RxR tables, rather than re-implementing it.
- **Stuart-Maxwell test of marginal homogeneity** generalizes the difference-in-proportions test:
  an omnibus χ² test (df = R − 1) for whether the row and column marginal distributions differ,
  computed here directly (drop the last category, `statistic = d' S⁻¹ d`) since no dependency
  already ships it. Cross-checked against `DescTools::StuartMaxwellTest` during development
  (not a package dependency — verification only).
- Agreement (observed % and Cohen's kappa, via `vcd::Kappa`) works unchanged for any RxR table —
  no generalization needed.

## Marginal percentages

The default row/column percentages in a contingency table (`% within row`, `% within column`)
compare the wrong thing for a paired design: they describe association *within* one occasion, not
change *between* the two occasions. The quantity that matters for a paired 2x2 (or RxR) table is
the **marginal** distribution of each variable — exactly what the difference-in-proportions and
Stuart-Maxwell tests compare. The **Marginal** percentages option adds this to the frequency table:
the Total *column* shows each row category's share of N (the row variable's marginal proportion),
and the Total *row* shows each column category's share of N (the column variable's marginal
proportion) — interior cells are left blank, since a marginal percentage isn't defined for an
individual cell.

## Installation (sideload)

Build the module (see below), then in jamovi: **Modules -> jamovi library -> Sideload** and select
the built `.jmo` file (`conttablespaired2xK/conttablespaired2xK_<version>.jmo`).

## Repository layout

- `conttablespaired2xK/` — R package source (analysis definitions, R code, jamovi UI yaml)
- `tools/` — build and install helper scripts (adapted from `conttables2xK`)
- `task_plan.md`, `findings.md`, `progress.md` — development working notes

## Building

```
bash tools/install.sh desktop   # builds conttablespaired2xK/conttablespaired2xK_<version>.jmo and
                                 # installs it into jamovi.app (macOS) using ~/R/.Rlib-arm or .Rlib-x64
bash tools/install.sh docker    # same, into a running `jamovi` Docker container (needs jmc)
bash tools/install.sh           # both, whichever are available
```

If jmvtools can't drive jamovi.app directly (a `SingletonLock` permission error, seen in sandboxed
environments even when jamovi.app isn't running), the `.jmo` is still built — sideload it by hand
as described above.

## Dependencies

- `vcd` (Imports) — Cohen's kappa (`vcd::Kappa`)
- `exact2x2` (Suggests) — only needed if the "Exact odds ratio (conditional MLE)" checkbox is used

## Naming: package vs. analysis identifier

Following the same convention as `conttables2xK`: the **package/repo** is rebranded
(`conttablespaired2xK`, menu "Paired Samples (2xK)") to advertise the RxR extension, but the
**analysis identifier itself stays `contTablesPaired`**, unchanged from jmv's original — matching
file basenames (`jamovi/conttablespaired.*.yaml`, `R/conttablespaired.b.R`), R6 class names
(`contTablesPairedClass`/`Base`), and exported R function (`contTablesPaired()`). This keeps the
module usable as a drop-in override / potential upstream PR candidate for jmv's own analysis,
rather than introducing a differently-named sibling.

## Translations

`jamovi/i18n/es.po` and `jamovi/i18n/ca.po` hold Spanish and Catalan translations of this module's
own strings (menu title/subtitle, table/column titles, footnotes, option labels) — generated with
`jmvtools::i18nCreate()`/`i18nUpdate()` and hand-translated. They do **not** duplicate the full
upstream jmv catalog (unlike `conttables2xK`'s multi-thousand-line `.po` files, inherited from
jmv/Weblate): only strings this module actually defines are listed, so the catalog stays small and
auditable. Regenerate after changing any user-facing string: `Rscript -e
'jmvtools::i18nUpdate("es"); jmvtools::i18nUpdate("ca")'` from inside `conttablespaired2xK/`, then
fill in any new/changed `msgstr` entries.

**Caveat observed while building this**: `i18nUpdate()` re-merged one long, already-translated
`msgstr` (the "table must be square" footnote) by *appending* the new extraction to the existing
translation instead of replacing it, silently duplicating the Spanish/Catalan text. Diff the `.po`
files after running `i18nUpdate()` and check for any `msgstr` that looks doubled before committing.

## Acknowledgment

This module was created with Claude, based on jmv's original `contTablesPaired` analysis
(Jonathon Love, Damian Dropmann, Ravi Selker) and following the structural pattern established in
this author's own `conttables2xK` module.
