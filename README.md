# conttablespaired2xK

A [jamovi](https://www.jamovi.org) module that clones jmv's **Paired Samples Contingency Tables**
(McNemar test) analysis, restructures its output to separate hypothesis tests from comparative
measures (mirroring [conttables2xK](https://github.com/victor-moreno/jamovi-conttables-2xK)), and
extends it to a **non-binary paired response** (RxR tables, not just 2x2) with:

- a **paired odds ratio** and **difference in proportions**, both with confidence intervals, for
  2x2 tables — plus an optional exact odds ratio and an exact McNemar test based on the binomial
- **marginal percentages** in the frequency table, the quantity that actually matters for a paired
  design (not the within-row/within-column percentages)
- **observed agreement**, **Cohen's kappa**, and an optional **weighted kappa (linear weights)**
  for tables with more than 2 categories, each with a confidence interval
- for RxR tables: **Bowker's test of symmetry** and the **Stuart-Maxwell test** of marginal
  homogeneity — the natural generalizations of McNemar's χ² and the difference-in-proportions test
  (both reduce to the same value as McNemar's χ² for a 2x2 table)
- two bundled example datasets (**Open -> Data Library**), one 2x2 and one 4-category

Appears in jamovi's menu as **Frequencies > Contingency Tables > Paired Samples (2xK)** (subtitle:
"McNemar, Bowker & Stuart-Maxwell"), alongside jmv's own "Paired Samples" entry.

## Reference convention

Reference category = the **first level**, for both rows and columns (they should share the same
categories, measured on two occasions). The **second** level is the "effect" category — the same
0/1 convention used in `conttables2xK`. Letting `b`/`c` be the discordant-cell counts moving
reference→effect / effect→reference: odds ratio = `b/c`, difference in proportions = `(b-c)/N`.

## Installation

Prebuilt `.jmo` files are attached to the [Releases](../../releases) page. Pick the file matching
your OS and jamovi's bundled R version (check **Help -> About** in jamovi), then in jamovi:
**Modules -> jamovi library -> Sideload** and select the downloaded `.jmo`.

## Repository layout

- `conttablespaired2xK/` — R package source (analysis definitions, R code, jamovi UI yaml,
  `data/` example datasets, `tests/testthat/`)
- `tools/` — build and install helper scripts (adapted from `conttables2xK`)

## Building

```
bash tools/install.sh desktop   # builds conttablespaired2xK/conttablespaired2xK_<version>.jmo and
                                 # installs it into jamovi.app (macOS) using whichever R `Rscript` resolves to
bash tools/install.sh docker    # same, into a running `jamovi` Docker container -- also runs the
                                 # full testthat suite; the primary way to verify changes here
bash tools/install.sh           # both, whichever are available
```

Then repackage for other jamovi/R versions and ship a release:

```
bash tools/prepare-jmo.sh 4.6.0 all     # metadata-only repackage into dist/
bash tools/release.sh 4.6.0             # + publish a GitHub release with those assets
```

## Dependencies

- `vcd` (Imports) — Cohen's kappa and weighted kappa
- `exact2x2` (Suggests) — only needed for the optional exact odds ratio

## Acknowledgment

This module was created with Claude, based on jmv's original `contTablesPaired` analysis
(Jonathon Love, Damian Dropmann, Ravi Selker) and following the structural pattern established in
this author's own `conttables2xK` module.
