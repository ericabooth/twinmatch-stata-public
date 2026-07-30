* ==============================================================================
* test_twinmatch.do -- test battery for the twinmatch package
* Run from any scratch directory:  stata-mp -b do test_twinmatch.do
* Judge by the log: no run-time error codes and no failed assertions.
* ==============================================================================

* --- paths: set once here; nothing below is hard-coded -----------------------
global pkgroot "/Users/ebooth/Documents/GitHub/Book Manuscript:Applied Evaluation-Stata/twinmatch-stata-public"

version 16.0
clear all
set more off
set seed 20260706
adopath + "$pkgroot"
which twinmatch

* ==============================================================================
* Test 1: sysuse auto -- known nearest neighbors for "Volvo 260" (Mahalanobis)
* ==============================================================================
display as text "{hline 70}"
display as text "TEST 1: auto, Mahalanobis metric, known neighbors"
sysuse auto, clear
twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(3) gen(d260)

* save the full results now (later summarize/correlate calls overwrite r())
local twins_first `"`r(twins)'"'
local dists_first  "`r(dists)'"

* stored results
assert  r(N) == 74
assert  r(k) == 3
assert "`r(metric)'"  == "mahalanobis"
assert `"`r(treated)'"' == "Volvo 260"

* the known top-3 twins (deterministic; no randomness anywhere in twinmatch)
local t1 : word 1 of `r(twins)'
local t2 : word 2 of `r(twins)'
local t3 : word 3 of `r(twins)'
assert `"`t1'"' == "Peugeot 604"
assert `"`t2'"' == "Linc. Versailles"
assert `"`t3'"' == "Audi 5000"

* matching distances line up with the twins
local d1 : word 1 of `r(dists)'
local d3 : word 3 of `r(dists)'
assert reldif(`d1', .5684520591) < 1e-7
assert reldif(`d3', 1.012689029) < 1e-7

* gen(): treated unit sits at distance 0; every distance is non-negative
assert d260 == 0                if make == "Volvo 260"
assert !missing(d260) & d260 >= 0

* predict-then-check: recompute the Audi 5000 distance from first principles
quietly correlate mpg price weight, covariance
matrix V  = r(C)
matrix Vi = invsym(V)
foreach v in mpg price weight {
    summarize `v' if make == "Volvo 260", meanonly
    scalar t_`v' = r(mean)
    summarize `v' if make == "Audi 5000", meanonly
    scalar a_`v' = r(mean)
}
matrix dd = (a_mpg - t_mpg, a_price - t_price, a_weight - t_weight)
matrix qq = dd * Vi * dd'
scalar d_audi_byhand = sqrt(qq[1,1])
summarize d260 if make == "Audi 5000", meanonly
assert reldif(r(mean), d_audi_byhand) < 1e-10
assert reldif(`d3',    d_audi_byhand) < 1e-7

* seed-free determinism: a second run returns the identical answer
twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(3)
assert `"`r(twins)'"' == `"`twins_first'"'
assert  "`r(dists)'"  ==  "`dists_first'"

* ==============================================================================
* Test 2: standardize option -- Euclidean distance on z-scored covariates
* ==============================================================================
display as text "{hline 70}"
display as text "TEST 2: auto, standardize option"
twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(3) ///
    standardize gen(dz260)
assert "`r(metric)'" == "standardized"

* save results before later summarize calls overwrite r()
local ztwins `"`r(twins)'"'
local zdists  "`r(dists)'"

* known top-3 under the standardized metric (ordering differs from Test 1)
local z1 : word 1 of `ztwins'
local z2 : word 2 of `ztwins'
local z3 : word 3 of `ztwins'
assert `"`z1'"' == "Peugeot 604"
assert `"`z2'"' == "Audi 5000"
assert `"`z3'"' == "Buick Riviera"

* predict-then-check: recompute the Audi 5000 z-score distance by hand
scalar zsum = 0
foreach v in mpg price weight {
    quietly summarize `v'
    scalar zsum = zsum + ((a_`v' - t_`v') / r(sd))^2
}
summarize dz260 if make == "Audi 5000", meanonly
assert reldif(r(mean), sqrt(zsum)) < 1e-10
local zd2 : word 2 of `zdists'
assert reldif(`zd2', sqrt(zsum)) < 1e-7

* ==============================================================================
* Test 3: constructed data -- the true twin is known by construction
* ==============================================================================
display as text "{hline 70}"
display as text "TEST 3: constructed data with a planted exact twin"
clear
set obs 30
gen str8 uid = "u" + string(_n)
gen double x1 = rnormal(0, 1)
gen double x2 = rnormal(5, 2)
gen double x3 = rnormal(-3, 10)
* plant an exact copy of the treated unit (u1) at u2
foreach v of varlist x1 x2 x3 {
    quietly replace `v' = `v'[1] in 2
}
twinmatch x1 x2 x3, id(uid) treated("u1") ntwins(2) gen(dist_u1)
local c1 : word 1 of `r(twins)'
local cd1 : word 1 of `r(dists)'
assert `"`c1'"' == "u2"        // the planted copy is the nearest twin ...
assert  `cd1' == 0             // ... at exactly distance zero
assert  dist_u1 == 0 in 1/2
assert  dist_u1 >  0 in 3/30

* if/in restrictions flow through marksample
twinmatch x1 x2 x3 in 1/20, id(uid) treated("u1") ntwins(2)
assert r(N) == 20

* missing covariates drop the observation from the pool
quietly replace x2 = . in 30
twinmatch x1 x2 x3, id(uid) treated("u1") ntwins(2)
assert r(N) == 29

* numeric id variables are accepted and matched as strings
gen long nid = _n
twinmatch x1 x3, id(nid) treated("1") ntwins(2)
assert `"`r(treated)'"' == "1"

* ==============================================================================
* Test 4: singular covariance -- collinear column dropped with a warning
* ==============================================================================
display as text "{hline 70}"
display as text "TEST 4: singular covariance handled gracefully"
sysuse auto, clear
gen double wcopy = 2*weight + 3          // exactly collinear with weight
twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(3)
local twins_clean `"`r(twins)'"'
twinmatch mpg price weight wcopy, id(make) treated("Volvo 260") ntwins(3)
* Mahalanobis distance is unchanged after dropping the redundant column
assert `"`r(twins)'"' == `"`twins_clean'"'

* a constant covariate under standardize is dropped, not fatal
gen byte konst = 7
twinmatch mpg price, id(make) treated("Volvo 260") ntwins(3) standardize
local twins_std2 `"`r(twins)'"'
twinmatch mpg price konst, id(make) treated("Volvo 260") ntwins(3) standardize
assert `"`r(twins)'"' == `"`twins_std2'"'

* ==============================================================================
* Test 5: deliberate error cases -- correct exit codes
* ==============================================================================
display as text "{hline 70}"
display as text "TEST 5: error handling"
sysuse auto, clear

* 5a. treated unit not found -> 111
capture noisily twinmatch mpg price, id(make) treated("No Such Car")
assert _rc == 111

* 5b. ntwins() larger than the comparison pool -> 198
capture noisily twinmatch mpg price, id(make) treated("Volvo 260") ntwins(74)
assert _rc == 198

* 5c. ntwins() must be positive -> 198
capture noisily twinmatch mpg price, id(make) treated("Volvo 260") ntwins(0)
assert _rc == 198

* 5d. empty treated() -> 198
capture noisily twinmatch mpg price, id(make) treated("")
assert _rc == 198

* 5e. generate() must name a new variable -> 110
capture noisily twinmatch mpg price, id(make) treated("Volvo 260") gen(price)
assert _rc == 110

* 5f. duplicate ids for the treated unit -> 459
preserve
quietly replace make = "Volvo 260" in 1
capture noisily twinmatch mpg price, id(make) treated("Volvo 260")
assert _rc == 459
restore

* 5g. all covariates constant -> 506 (rank-0 covariance)
gen byte c1 = 1
gen byte c2 = 2
capture noisily twinmatch c1 c2, id(make) treated("Volvo 260")
assert _rc == 506

* ==============================================================================
display as text "{hline 70}"
display as result "twinmatch test battery: ALL TESTS PASSED"
display as text "{hline 70}"
