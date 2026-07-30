# twinmatch

Policy-twin selection by Mahalanobis distance, for Stata 16.0+.

`twinmatch` answers a question that comes up constantly in small-N program
evaluation: one district, county, campus, or hospital adopted a policy —
which untreated units look most like it? The command computes the
Mahalanobis distance from every unit to the treated unit on a set of numeric
covariates, ranks the comparison units from nearest to farthest, and reports
the k closest "policy twins." Results are deterministic — no seed, no
randomness — so the same data always return the same twins.

Beyond the ranked table, `twinmatch` can store every unit's distance in a
new variable (`generate()`), returns the twin ids and distances in `r()` for
programmatic use, and offers a `standardize` option that swaps the full
Mahalanobis metric for Euclidean distance on z-scored covariates — often
easier to defend when covariate scales differ wildly and the correlation
structure is noisy in a small sample. Singular covariance matrices are
handled gracefully: collinear covariates are dropped from the metric with a
named warning, and the reported twins match what you would get by omitting
the redundant columns yourself.

The command is a conceptual kin of donor selection in synthetic control
designs (Cattaneo et al. 2024; Abadie 2021). It selects comparison units;
it does not weight them, test balance, or estimate treatment effects. Treat
the twin list as the starting point for a comparative case study or a donor
pool, not as an estimator.

## Install

From GitHub (once the repository is public):

```stata
net install twinmatch, from("https://raw.githubusercontent.com/ericabooth/twinmatch-stata-public/main/") replace force
help twinmatch
```

## Quick start

```stata
sysuse auto, clear

* three nearest twins for one unit, on three covariates
twinmatch mpg price weight, id(make) treated("Volvo 260")

* store every unit's distance; z-scored metric; five twins
twinmatch mpg price weight, id(make) treated("Volvo 260") ///
    ntwins(5) standardize generate(dist260)

* use the results programmatically (ids keep their internal spaces)
local nearest : word 1 of `r(twins)'
display `"nearest twin: `nearest'"'
```

## Syntax

```stata
twinmatch varlist [if] [in], id(varname) treated(unit)
    [ntwins(#) generate(newvar) standardize]
```

- `id()` — unit identifier (string or numeric); must uniquely identify the
  treated unit.
- `treated()` — id value of the unit to be matched.
- `ntwins(#)` — how many nearest twins to report (default 3).
- `generate(newvar)` — store each in-sample unit's distance to the treated
  unit (0 for the treated unit itself).
- `standardize` — Euclidean distance on z-scored covariates instead of the
  full Mahalanobis metric.

## Stored results

`twinmatch` is rclass:

| Result | Contents |
| --- | --- |
| `r(N)` | observations in the estimation sample |
| `r(k)` | number of twins reported |
| `r(twins)` | ids of the k nearest twins, nearest first; each id compound-quoted so ids with spaces survive |
| `r(dists)` | space-separated distances aligned with `r(twins)` |
| `r(treated)` | id of the treated unit |
| `r(metric)` | `mahalanobis` or `standardized` |

Extract individual twins with `local x : word # of `r(twins)'`.

## Testing

`test_twinmatch.do` is a self-contained battery (synthetic data plus
`sysuse auto`) that exercises every documented option, verifies distances
against hand computations, and checks the error codes. Set the `pkgroot`
global at the top of the file, then run it in batch from any scratch
directory.

## License

MIT. Copyright (c) 2026 Eric A. Booth. See `LICENSE`.
