* ==============================================================================
* test_twinmatch.do -- test battery for the twinmatch package
* Run from any scratch directory:
*   stata-mp -b do test_twinmatch.do "<package folder>"
* Judge by the log: no run-time error codes and no failed assertions.
* ==============================================================================

* --- paths: set once here; nothing below is hard-coded -----------------------
* pkgroot: argument 1 if given, else an existing $pkgroot, else the
* current folder when it holds twinmatch.ado (a repo clone), else the folder
* of the twinmatch.ado that findfile locates on the adopath.
if `"`1'"' != "" global pkgroot `"`1'"'
if `"$pkgroot"' == "" {
    capture confirm file `"`c(pwd)'/twinmatch.ado"'
    if !_rc global pkgroot `"`c(pwd)'"'
    else {
        findfile twinmatch.ado
        local _fn `"`r(fn)'"'
        global pkgroot = substr(`"`_fn'"', 1, strlen(`"`_fn'"') - strlen("/twinmatch.ado"))
    }
}

version 16.0
clear all
set more off
set seed 20260706
adopath ++ "$pkgroot"
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

* 5h. (0.1.1) a failed run with generate() leaves no variable behind
capture noisily twinmatch c1 c2, id(make) treated("Volvo 260") generate(dd)
assert _rc != 0
capture confirm variable dd
assert _rc != 0
capture noisily twinmatch c1 c2, id(make) treated("Volvo 260") standardize generate(dd)
assert _rc != 0
capture confirm variable dd
assert _rc != 0
* and a successful run still creates it
twinmatch mpg price weight, id(make) treated("Volvo 260") generate(dd)
confirm double variable dd
assert dd == 0 if make == "Volvo 260"

* ==============================================================================
* Test 6 (0.2.0): strata() -- candidates must share the treated unit's values
* ==============================================================================
display as text "{hline 70}"
display as text "TEST 6: strata"
sysuse auto, clear
twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(3) strata(foreign)
assert r(N) == 74
assert r(N_pool) == 21            // 22 foreign cars minus the Volvo
local s1 : word 1 of `r(twins)'
local s2 : word 2 of `r(twins)'
local s3 : word 3 of `r(twins)'
* the same answer as restricting the pool by hand, but the metric still uses
* the whole sample's covariance, so compare with gen() distances
twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(3) gen(dall)
gsort -foreign dall
local h1 = make[2]
local h2 = make[3]
local h3 = make[4]
assert `"`s1'"' == `"`h1'"' & `"`s2'"' == `"`h2'"' & `"`s3'"' == `"`h3'"'
* a string stratum, and a stratum the treated unit shares with nobody
gen str10 grp = cond(foreign, "import", "domestic")
quietly replace grp = "alone" if make == "Volvo 260"
capture noisily twinmatch mpg price, id(make) treated("Volvo 260") strata(grp)
assert _rc == 2001
quietly replace grp = "import" if make == "Volvo 260"
twinmatch mpg price, id(make) treated("Volvo 260") strata(grp) ntwins(2)
assert r(N_pool) == 21
assert "`r(strata)'" == "grp"
* ntwins beyond the stratum is an error that names the stratum
capture noisily twinmatch mpg price, id(make) treated("Volvo 260") strata(foreign) ntwins(30)
assert _rc == 198

* ==============================================================================
* Test 7 (0.2.0): caliper() -- fewer twins when the pool is far away
* ==============================================================================
display as text "{hline 70}"
display as text "TEST 7: caliper"
sysuse auto, clear
twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(5) caliper(0.95)
assert r(k) == 2                   // Peugeot 0.57 and Lincoln 0.90 are inside; Audi 1.01 is not
assert r(caliper) == 0.95
local c2 : word 2 of `r(twins)'
assert `"`c2'"' == "Linc. Versailles"
* a caliper nobody meets is an error, not an empty list
capture noisily twinmatch mpg price weight, id(make) treated("Volvo 260") caliper(0.1)
assert _rc == 2000
capture noisily twinmatch mpg price weight, id(make) treated("Volvo 260") caliper(0)
assert _rc == 198
* support line values: the k-th distance and the pool median
twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(3) gen(dsup)
local d3 : word 3 of `r(dists)'
assert reldif(r(kth_dist), `d3') < 1e-7
twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(3) nodisplay
local med = r(median_dist)
quietly summarize dsup if make != "Volvo 260", detail
assert reldif(`med', r(p50)) < 1e-9

* ==============================================================================
* Test 8 (0.2.0): balance table against hand computation
* ==============================================================================
display as text "{hline 70}"
display as text "TEST 8: balance"
sysuse auto, clear
twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(3) balance
matrix B = r(balance)
local maxsmd = r(max_stddiff)
assert rowsof(B) == 3 & colsof(B) == 4
* by hand for price: treated value, mean of the three twins, sample mean and SD
summarize price if make == "Volvo 260", meanonly
local tp = r(mean)
summarize price if inlist(make, "Peugeot 604", "Linc. Versailles", "Audi 5000"), meanonly
local wp = r(mean)
summarize price
assert reldif(B[2,1], `tp') < 1e-9
assert reldif(B[2,2], `wp') < 1e-9
assert reldif(B[2,3], r(mean)) < 1e-9
assert reldif(B[2,4], (`wp' - `tp') / r(sd)) < 1e-9
mata: st_numscalar("mx", max(abs(st_matrix("B")[.,4])))
assert reldif(`maxsmd', mx) < 1e-12

* ==============================================================================
* Test 9 (0.2.0): pretrend() on wide data, and time() on the same data long
* ==============================================================================
display as text "{hline 70}"
display as text "TEST 9: pre-trend matching, wide and long"
clear
set seed 20261114
set obs 40
gen str6 uid = "s" + string(_n)
gen double size = rnormal(100, 20)
gen double poor = rnormal(30, 8)
gen byte   rural = _n > 20
* outcome paths 2015-2019: unit s1 (treated) and s7 share the same path shape
forvalues t = 2015/2019 {
    gen double y`t' = 50 + 0.1*size - 0.3*poor + 2*(`t' - 2015) + rnormal(0, 3)
}
forvalues t = 2015/2019 {
    quietly replace y`t' = y`t'[1] + 0.2 in 7      // s7 tracks s1 almost exactly
}
twinmatch size poor, id(uid) treated("s1") ntwins(3) pretrend(y2015 y2016 y2017 y2018 y2019) gen(dw)
local pw1 : word 1 of `r(twins)'
local wide_twins `"`r(twins)'"'
local wide_dists  "`r(dists)'"
assert "`r(pretrend)'" == "y2015 y2016 y2017 y2018 y2019"
* by hand: Mahalanobis on the covariates, plus z-scored path distance in quadrature
quietly correlate size poor, covariance
matrix V = r(C)
matrix Vi = invsym(V)
gen double dcov2 = .
gen double dpre2 = 0
forvalues t = 2015/2019 {
    quietly summarize y`t'
    quietly replace dpre2 = dpre2 + ((y`t' - y`t'[1]) / r(sd))^2
}
mata: X = st_data(., "size poor"); Vi = st_matrix("Vi"); D = X :- X[1,.]; st_store(., "dcov2", rowsum((D*Vi) :* D))
gen double dhand = sqrt(dcov2 + dpre2)
assert reldif(dw, dhand) < 1e-9
* pre-trend only (no covariates) and growth since the first period
twinmatch, id(uid) treated("s1") ntwins(3) pretrend(y2015 y2016 y2017 y2018 y2019) gen(dp)
gen double dp_hand = sqrt(dpre2)
assert reldif(dp, dp_hand) < 1e-9
local g1 : word 1 of `r(twins)'
assert "`g1'" == "s7"
twinmatch, id(uid) treated("s1") ntwins(3) pretrend(y2015 y2016 y2017 y2018 y2019) growth
local gg1 : word 1 of `r(twins)'
assert "`gg1'" == "s7"
* preweight scales the path block
twinmatch size poor, id(uid) treated("s1") ntwins(3) pretrend(y2015 y2016 y2017 y2018 y2019) preweight(4) gen(dw4)
gen double dw4_hand = sqrt(dcov2 + 4*dpre2)
assert reldif(dw4, dw4_hand) < 1e-9
* the same data long, through time()/outcome()/window(): identical twins and distances
preserve
keep uid size poor rural y2015-y2019
reshape long y, i(uid) j(year)
twinmatch size poor, id(uid) treated("s1") ntwins(3) time(year) outcome(y) window(2015 2019) gen(dl)
assert `"`r(twins)'"' == `"`wide_twins'"'
assert  "`r(dists)'"  ==  "`wide_dists'"
assert "`r(window)'" == "2015 2019"
assert "`r(outcome)'" == "y"
* the distance is constant within unit and matches the wide run
bysort uid (year): assert dl == dl[1]
sort uid year
* a shorter window changes the answer but still runs; strata in panel form
twinmatch size poor, id(uid) treated("s1") ntwins(3) time(year) outcome(y) window(2017 2019) strata(rural)
assert r(N_pool) == 19
* a missing period in the window for the treated unit is an error
drop if uid == "s1" & year == 2016
capture noisily twinmatch size poor, id(uid) treated("s1") ntwins(3) time(year) outcome(y) window(2015 2019)
assert _rc != 0
restore
* panel options must come together
capture noisily twinmatch size poor, id(uid) treated("s1") time(size)
assert _rc == 198
capture noisily twinmatch size poor, id(uid) treated("s1") time(size) outcome(poor) window(1 2) pretrend(y2015)
assert _rc == 198

* ==============================================================================
* Test 10 (0.2.0): stability -- drop one covariate at a time
* ==============================================================================
display as text "{hline 70}"
display as text "TEST 10: stability"
sysuse auto, clear
twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(3) stability
matrix S = r(stability)
assert rowsof(S) == 3 & colsof(S) == 3
local base `"`r(twins)'"'
* row 1 drops mpg: recompute by hand and compare the overlap
twinmatch price weight, id(make) treated("Volvo 260") ntwins(3)
local cur `"`r(twins)'"'
local inter : list base & cur
local union : list base | cur
assert S[1,2] == `: word count `inter''
assert reldif(S[1,3], `: word count `inter'' / `: word count `union'') < 1e-12
* with one covariate there is nothing to drop; no matrix, no error
twinmatch mpg, id(make) treated("Volvo 260") ntwins(3) stability
capture confirm matrix r(stability)
assert _rc != 0

* ==============================================================================
* Test 11 (0.2.0): saving() writes the shortlist as .dta or .csv
* ==============================================================================
display as text "{hline 70}"
display as text "TEST 11: saving"
sysuse auto, clear
tempfile led
twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(3) saving(`led'.dta)
preserve
use `led'.dta, clear
assert _N == 4
assert twin_rank[1] == 0 & make[1] == "Volvo 260"
assert twin_rank[2] == 1 & make[2] == "Peugeot 604"
assert tm_metric == "mahalanobis"
assert tm_covariates == "mpg price weight"
confirm variable mpg price weight tm_date
restore
tempfile csvled
twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(2) saving(`csvled'.csv, replace) nodisplay
preserve
import delimited `csvled'.csv, clear varnames(1)
assert _N == 3
restore
* an existing file without replace is an error, with replace it is not
capture noisily twinmatch mpg price weight, id(make) treated("Volvo 260") saving(`led'.dta)
assert _rc == 602
twinmatch mpg price weight, id(make) treated("Volvo 260") saving(`led'.dta, replace) nodisplay

* ==============================================================================
* Test 12 (0.2.0): nodisplay runs silently and the default output is unchanged
* ==============================================================================
display as text "{hline 70}"
display as text "TEST 12: nodisplay and the 0.1 defaults"
sysuse auto, clear
twinmatch mpg price weight, id(make) treated("Volvo 260") nodisplay
assert r(k) == 3
local n1 : word 1 of `r(twins)'
assert `"`n1'"' == "Peugeot 604"
* the book's printed example: Peugeot 604 (0.57), Linc. Versailles (0.90), Audi 5000 (1.01)
twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(3) gen(d260)
local d2 : word 2 of `r(dists)'
assert abs(`d2' - .90) < .005
local d1 : word 1 of `r(dists)'
local d3 : word 3 of `r(dists)'
assert abs(`d1' - .57) < .005 & abs(`d3' - 1.01) < .005

* ==============================================================================
display as text "{hline 70}"
display as result "twinmatch test battery: ALL TESTS PASSED"
display as text "{hline 70}"
