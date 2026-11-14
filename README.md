# twinmatch

Policy-twin selection by Mahalanobis distance, for Stata 16.0+.

`twinmatch` answers a question that comes up constantly in small-N program
evaluation: one district, county, campus, hospital, or firm adopted a policy;
which untreated units look most like it? The command computes the
Mahalanobis distance from every candidate to the treated unit on a set of
covariates, ranks the candidates from nearest to farthest, and reports the k
closest "policy twins." Results are deterministic: no seed, no randomness, so
the same data always return the same twins.

Version 0.2 adds what a reviewer asks for next, while leaving the defaults
unchanged:

- **The pool.** `strata()` requires an exact match on a few variables (a
  sector, a size class, a metro flag); `caliper()` refuses candidates farther
  than a stated distance, so "no adequate twins" becomes an explicit result.
- **The outcome's path before the policy.** `pretrend()` on wide data, or
  `time()`, `outcome()`, and `window()` on a long panel, add the pre-policy
  path of the outcome to the distance, so twins are units that moved with
  the treated unit before the policy. `growth` matches on the shape rather
  than the level; `preweight()` sets how much the path counts.
- **Checks.** `balance` prints standardized differences for every covariate
  and path column; a support line compares the last twin's distance with the
  median candidate; `stability` re-picks with each covariate removed and
  reports the overlap with the shortlist.
- **The record.** `saving()` writes the shortlist with the treated id,
  metric, covariate list, strata, caliper, and date, as `.dta` or `.csv`,
  so the donor pool is on file before the outcome data arrive.

`twinmatch` selects and describes. It does not weight the twins, estimate
effects, or compute intervals; the help file lists the commands that do
those jobs once the twins are chosen.

## Install

```stata
net install twinmatch, from("https://raw.githubusercontent.com/ericabooth/twinmatch-stata-public/main/") replace force
help twinmatch
```

## Quick start

```stata
sysuse auto, clear

* three nearest twins for one unit, on three covariates
twinmatch mpg price weight, id(make) treated("Volvo 260")

* only cars of the same origin; up to five twins, none farther than 1.2
twinmatch mpg price weight, id(make) treated("Volvo 260") ///
    strata(foreign) ntwins(5) caliper(1.2)

* balance, stability, and a ledger file
twinmatch mpg price weight, id(make) treated("Volvo 260") ///
    balance stability saving(twins_volvo.csv, replace)

* a panel: firms whose investment moved with firm 1 over 1935-1944, given size
webuse grunfeld, clear
twinmatch mvalue kstock, id(company) treated(1) ntwins(3) ///
    time(year) outcome(invest) window(1935 1944) balance

* use the results programmatically (ids keep their internal spaces)
local nearest : word 1 of `r(twins)'
display `"nearest twin: `nearest'"'
```

## Syntax

```stata
twinmatch [varlist] [if] [in], id(varname) treated(unit)
    [ntwins(#) standardize generate(newvar)
     strata(varlist) caliper(#)
     pretrend(varlist) time(varname) outcome(varname) window(first last) growth preweight(#)
     balance stability saving(filename[, replace]) nodisplay]
```

- `id()`: unit identifier (string or numeric); must uniquely identify the
  treated unit.
- `treated()`: id value of the unit to be matched.
- `ntwins(#)`: how many nearest twins to report (default 3).
- `standardize`: Euclidean distance on z-scored covariates instead of the
  full Mahalanobis metric.
- `generate(newvar)`: store each in-sample unit's distance to the treated
  unit (0 for the treated unit itself).
- `strata(varlist)`: candidates must match the treated unit exactly on these.
- `caliper(#)`: drop candidates farther than this; `r(k)` says how many remain.
- `pretrend(varlist)`: wide data, one column per pre-policy period of the
  outcome. Each column is z-scored and the path enters the distance in
  quadrature with the covariates.
- `time()`, `outcome()`, `window(first last)`: the same for a long panel;
  covariates are taken at the last period of the window.
- `growth`: match on change since the first period; `preweight(#)`: weight on
  the path block (default 1).
- `balance`, `stability`: print the balance table and the leave-one-covariate-out
  check (both are always returned in `r()`).
- `saving(filename[, replace])`: write the shortlist and its provenance.
- `nodisplay`: compute silently.

## What the output shows

The ranked table lists the twins with their distances. The support line
compares the last twin's distance with the median candidate's: when the
last twin is farther than the typical candidate, the shortlist has reached
past the units that resemble the treated one. The balance table gives the
treated value, the twin mean, the sample mean, and the standardized
difference (twin mean minus treated, over the sample SD) for every
covariate; the largest absolute value is flagged above 0.25. The stability
table shows how much the shortlist changes when each covariate is removed.

## Stored results

`twinmatch` is rclass:

| Result | Contents |
| --- | --- |
| `r(N)` | observations in the estimation sample (units, in the panel form) |
| `r(N_pool)` | candidates after `strata()` |
| `r(k)` | number of twins reported |
| `r(kth_dist)`, `r(median_dist)` | distance to the last twin; median distance among candidates |
| `r(max_stddiff)` | largest absolute standardized difference |
| `r(caliper)` | the caliper, when given |
| `r(twins)` | ids of the k nearest twins, nearest first; each id compound-quoted so ids with spaces survive |
| `r(dists)` | space-separated distances aligned with `r(twins)` |
| `r(treated)`, `r(metric)`, `r(covariates)`, `r(pretrend)`, `r(strata)`, `r(outcome)`, `r(window)` | what was used |
| `r(balance)` | covariates and path columns by (treated, twins, sample, stddiff) |
| `r(stability)` | removed ingredient by (twins, shared, overlap) |

Extract individual twins with `local x : word # of `r(twins)'`.

## Related and complementary commands

`twinmatch` chooses and documents the comparison units. For the neighbouring
jobs:

- **Weighting the twins and estimating an effect from a panel:** `synth`
  (synthetic control), `allsynth` (bias correction, placebo inference),
  `scpi` (prediction intervals), `sdid` (synthetic difference-in-differences).
  Hand them `r(twins)` as the donor pool.
- **Difference-in-differences once the group is set:** official `didregress`
  and `xtdidregress`; `csdid` and `did_multiplegt` for staggered adoption.
- **Matching many treated units, with estimation:** official `teffects nnmatch`
  and `teffects psmatch`; `psmatch2`; `kmatch`. `twinmatch` is the
  one-treated-unit case with the shortlist, not the effect, as the product.
- **Other ways to define "comparable":** `cem` (coarsened exact matching),
  `ebalance` (entropy balancing), official `cluster kmeans` (typologies), and
  `peerpick` (same author: these and other methods behind one syntax, with a
  specification curve and placebo checks, for benchmarking questions where
  the unit is not "treated" at all).
- **Balance after matching:** official `tebalance`; `pstest` after `psmatch2`.

## Testing

`test_twinmatch.do` is a self-contained battery (synthetic data, `sysuse
auto`, and a constructed panel) that exercises every documented option,
verifies distances, balance, and the pre-trend metric against hand
computations, confirms that the panel and wide forms agree, and checks the
error codes. Run it in batch from any scratch directory and pass the package
folder as the argument (`stata-mp -b do test_twinmatch.do "<package folder>"`);
with no argument it uses the current folder, or the `twinmatch.ado` it finds
on the adopath.

## Changelog

- 0.2.0 (2026-11-14): `strata()`, `caliper()`, `pretrend()`, the panel form
  (`time()`, `outcome()`, `window()`, `growth`, `preweight()`), `balance`,
  the support line, `stability`, `saving()`, `nodisplay`; new stored results
  `r(N_pool)`, `r(kth_dist)`, `r(median_dist)`, `r(max_stddiff)`,
  `r(balance)`, `r(stability)`, and the variable lists. The varlist may be
  omitted when matching on the path alone. Defaults and the 0.1 results are
  unchanged.
- 0.1.1 (2026-11-09): `generate()` no longer leaves an all-missing
  variable behind when the distance step fails (for example, all
  covariates constant), so a rerun does not stop with "already defined".
  The test battery finds the package folder itself and puts it first on
  the adopath.
- 0.1.0 (2026-07-06): first release.

## License

MIT. Copyright (c) 2026 Eric A. Booth. See `LICENSE`.
