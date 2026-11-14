*! version 0.2.0  2026-11-14  Eric A. Booth, Sr Researcher, Texas 2036
*! twinmatch: policy-twin selection by Mahalanobis distance
* 0.2.0  2026-11-14  strata() and caliper() shape the pool; pretrend() and
*                   time()/outcome()/window() match on the outcome path
*                   before the policy; balance table and support line;
*                   stability (leave one covariate out); saving() writes
*                   the shortlist as a ledger file.  Defaults unchanged.
* 0.1.1  2026-11-09  generate() fills a temporary variable and renames it
*                   only after the distances are computed, so an error
*                   leaves no half-made variable behind
* version 16.0 suffices: uses only long-standing Mata, frames, and syntax.

program define twinmatch, rclass
    version 16.0
    syntax [varlist(default=none numeric)] [if] [in], ///
        ID(varname) Treated(string) ///
        [ Ntwins(integer 3) GENerate(name) STANDardize ///
          STRata(varlist) CALiper(real -1) ///
          PREtrend(varlist numeric) GROWth PREWeight(real 1) ///
          TIme(varname numeric) OUTcome(varname numeric) WINdow(numlist min=2 max=2 sort) ///
          BALance STABility SAVing(string asis) noDISPlay ]

    local covs `varlist'
    if "`covs'" == "" & "`pretrend'" == "" & "`time'" == "" {
        display as error "give at least one covariate, or pretrend(), or time() with outcome() and window()"
        exit 198
    }
    if `preweight' <= 0 {
        display as error "preweight() must be positive"
        exit 198
    }
    if `caliper' == 0 | (`caliper' < 0 & `caliper' != -1) {
        display as error "caliper() must be positive"
        exit 198
    }

    * ---- panel form: build the wide pre-period file in a frame, then recurse --
    if "`time'" != "" | "`outcome'" != "" | "`window'" != "" {
        if "`time'" == "" | "`outcome'" == "" | "`window'" == "" {
            display as error "time(), outcome(), and window(first last) go together"
            exit 198
        }
        if "`pretrend'" != "" {
            display as error "pretrend() is for wide data; with time() give outcome() and window() instead"
            exit 198
        }
        local pass ""
        if "`generate'" != "" local pass `pass' generate(`generate')
        if "`strata'" != ""   local pass `pass' strata(`strata')
        if `"`saving'"' != "" local pass `"`pass' saving(`saving')"'
        _tm_panel `covs' `if' `in', id(`id') treated(`treated') ntwins(`ntwins') ///
            `standardize' caliper(`caliper') `growth' preweight(`preweight') ///
            time(`time') outcome(`outcome') window(`window') `balance' `stability' `display' `pass'
        return add
        exit
    }

    * ---- sample -------------------------------------------------------------
    marksample touse, novarlist
    markout `touse' `covs' `pretrend'
    markout `touse' `id' `strata', strok

    * ---- id variable as string, for safe matching and reporting -------------
    tempvar id_str
    capture confirm string variable `id'
    if _rc == 0 {
        quietly gen `id_str' = strtrim(`id')
    }
    else {
        quietly gen `id_str' = strtrim(string(`id', "%16.0g"))
    }
    quietly replace `touse' = 0 if `id_str' == ""

    * ---- validate the treated unit ------------------------------------------
    local treatval = strtrim(`"`treated'"')
    if `"`treatval'"' == "" {
        display as error "treated() cannot be empty"
        exit 198
    }
    quietly count if `id_str' == `"`treatval'"' & `touse'
    if r(N) == 0 {
        display as error `"treated unit "`treatval'" not found in `id' (within the estimation sample)"'
        exit 111
    }
    if r(N) > 1 {
        display as error `"treated unit "`treatval'" matches `r(N)' observations in `id'; ids must be unique"'
        exit 459
    }

    * ---- candidates: the sample, minus the treated unit, within the strata ----
    tempvar cand
    quietly gen byte `cand' = `touse'
    quietly replace `cand' = 0 if `id_str' == `"`treatval'"'
    foreach s of local strata {
        capture confirm string variable `s'
        if _rc == 0 {
            quietly levelsof `s' if `id_str' == `"`treatval'"' & `touse', local(sv) clean
            quietly replace `cand' = 0 if `s' != `"`sv'"'
        }
        else {
            quietly summarize `s' if `id_str' == `"`treatval'"' & `touse', meanonly
            quietly replace `cand' = 0 if `s' != r(min)
        }
    }

    * ---- validate ntwins against the pool ----------------------------------
    quietly count if `touse'
    local nobs = r(N)
    quietly count if `cand'
    local npool = r(N)
    if `npool' < 1 {
        display as error "no comparison units: the sample holds only the treated unit" _c
        if "`strata'" != "" display as error ", or no other unit shares its strata() values"
        else display as error ""
        exit 2001
    }
    if `ntwins' < 1 {
        display as error "ntwins() must be a positive integer"
        exit 198
    }
    if `ntwins' > `npool' {
        if "`strata'" != "" display as error "ntwins(`ntwins') exceeds the `npool' comparison unit(s) that share the treated unit's strata() values"
        else display as error "ntwins(`ntwins') exceeds the `npool' available comparison units"
        exit 198
    }

    * ---- optional distance variable ------------------------------------------
    tempvar gendist twinrank
    local genwork ""
    if "`generate'" != "" {
        confirm new variable `generate'
        quietly gen double `gendist' = .
        local genwork "`gendist'"
    }
    quietly gen int `twinrank' = .

    * ---- compute -------------------------------------------------------------
    local usestd = ("`standardize'" != "")
    local showtab = ("`display'" == "")
    mata: tm_findtwins("`covs'", "`pretrend'", "`id_str'", `"`treatval'"', ///
        `ntwins', "`touse'", "`cand'", "`genwork'", "`twinrank'", `usestd', ///
        ("`growth'" != ""), `preweight', `caliper', `showtab')
    local k = `tm_k'
    if `k' == 0 {
        display as error "no comparison unit lies within caliper(`caliper'); the nearest is at distance `tm_nearest'"
        exit 2000
    }
    if `k' < `ntwins' & `showtab' {
        display as text "note: caliper(`caliper') leaves `k' of the `ntwins' twins requested"
    }

    if "`generate'" != "" {
        rename `gendist' `generate'
        if `usestd' {
            label variable `generate' "Euclidean distance (z-scored covariates) to `treatval'"
        }
        else {
            label variable `generate' "Mahalanobis distance to `treatval'"
        }
        if "`pretrend'" != "" label variable `generate' "Distance (covariates and pre-trend) to `treatval'"
        if `showtab' display as text `"distance to "`treatval'" stored in {bf:`generate'}"'
    }

    * ---- support: how far is the k-th twin, against the pool -------------------
    local kth = `tm_kth'
    local med = `tm_median'
    if `showtab' {
        display as text "support: twin `k' is at distance " as result %6.3f `kth' ///
            as text "; the median candidate is at " as result %6.3f `med' _c
        if `kth' > `med' display as text " (the shortlist reaches past the typical candidate)"
        else display
    }

    * ---- balance on the covariates ---------------------------------------------
    tempname B
    local nb = 0
    local bnames ""
    foreach v in `covs' `pretrend' {
        local ++nb
        quietly summarize `v' if `id_str' == `"`treatval'"' & `touse', meanonly
        local tv = r(mean)
        quietly summarize `v' if `twinrank' >= 1 & `twinrank' < ., meanonly
        local tw = r(mean)
        quietly summarize `v' if `touse'
        local pm = r(mean)
        local sd = r(sd)
        matrix `B' = nullmat(`B') \ (`tv', `tw', `pm', cond(`sd' > 0 & `sd' < ., (`tw' - `tv') / `sd', .))
        local bnames `bnames' `v'
    }
    matrix rownames `B' = `bnames'
    matrix colnames `B' = treated twins sample stddiff
    tempname maxsmd
    mata: st_numscalar("`maxsmd'", max(abs(editmissing(st_matrix("`B'")[., 4], 0))))
    if "`balance'" != "" & `showtab' {
        display as text ""
        display as text "Balance: standardized difference = (twin mean - treated) / sample SD"
        display as text "{hline 64}"
        display as text %-20s "covariate" %11s "treated" %11s "twins" %11s "sample" %10s "std diff"
        display as text "{hline 64}"
        forvalues i = 1/`nb' {
            local v : word `i' of `bnames'
            display as text %-20s abbrev("`v'", 20) as result %11.3g `B'[`i', 1] %11.3g `B'[`i', 2] %11.3g `B'[`i', 3] %10.2f `B'[`i', 4]
        }
        display as text "{hline 64}"
        display as text "largest |std diff| = " as result %5.2f `maxsmd' _c
        if `maxsmd' > 0.25 display as text "  (above 0.25: the twins do not match on every covariate)"
        else display
    }

    * ---- stability: drop one covariate at a time and re-pick -------------------
    tempname S
    local ns = 0
    local snames ""
    local ncov : word count `covs'
    if "`stability'" != "" {
        local base `"`tm_twinlist'"'
        local tries ""
        if `ncov' >= 2 {
            foreach v of local covs {
                local tries `"`tries' "-`v'""'
            }
        }
        if "`pretrend'" != "" & `ncov' >= 1 {
            local tries `"`tries' "covariates only" "pre-trend only""'
        }
        foreach t of local tries {
            if substr("`t'", 1, 1) == "-" {
                local drop = substr("`t'", 2, .)
                local c2 : list covs - drop
                local p2 `pretrend'
            }
            else if "`t'" == "covariates only" {
                local c2 `covs'
                local p2 ""
            }
            else {
                local c2 ""
                local p2 `pretrend'
            }
            local p2opt ""
            if "`p2'" != "" local p2opt pretrend(`p2') `growth' preweight(`preweight')
            local sopt ""
            if "`strata'" != "" local sopt strata(`strata')
            capture quietly twinmatch `c2' if `touse', id(`id_str') treated(`treatval') ntwins(`ntwins') ///
                `standardize' `sopt' caliper(`caliper') `p2opt' nodisplay
            if _rc continue
            local ++ns
            local cur `"`r(twins)'"'
            local inter : list base & cur
            local union : list base | cur
            matrix `S' = nullmat(`S') \ (r(k), `: word count `inter'', `: word count `inter'' / max(`: word count `union'', 1))
            local snames `"`snames' "`t'""'
        }
        if `ns' > 0 {
            matrix colnames `S' = twins shared overlap
            if `showtab' {
                display as text ""
                display as text "Stability: re-pick with one ingredient removed (overlap = Jaccard index with the base shortlist)"
                display as text "{hline 56}"
                display as text %-24s "removed" %8s "twins" %8s "shared" %10s "overlap"
                display as text "{hline 56}"
                forvalues i = 1/`ns' {
                    local t : word `i' of `snames'
                    display as text %-24s "`t'" as result %8.0f `S'[`i', 1] %8.0f `S'[`i', 2] %10.2f `S'[`i', 3]
                }
                display as text "{hline 56}"
            }
        }
        else if `showtab' display as text "stability: needs at least two covariates, or covariates plus pretrend()"
    }

    * ---- ledger file: the shortlist with what produced it -----------------------
    if `"`saving'"' != "" {
        _tm_save `covs' `pretrend', saving(`saving') id(`id') idstr(`id_str') rank(`twinrank') ///
            treated(`treatval') metric(`=cond(`usestd', "standardized", "mahalanobis")') ///
            strata(`strata') caliper(`caliper') touse(`touse') showtab(`showtab')
    }

    * ---- stored results --------------------------------------------------------
    return scalar N        = `nobs'
    return scalar N_pool   = `npool'
    return scalar k        = `k'
    return scalar kth_dist = `kth'
    return scalar median_dist = `med'
    return scalar max_stddiff = `maxsmd'
    if `caliper' > 0 return scalar caliper = `caliper'
    return local  metric  = cond(`usestd', "standardized", "mahalanobis")
    return local  treated `"`treatval'"'
    return local  covariates "`covs'"
    return local  pretrend "`pretrend'"
    return local  strata  "`strata'"
    return local  dists   "`tm_distlist'"
    return local  twins   `"`tm_twinlist'"'
    return matrix balance = `B'
    if `ns' > 0 return matrix stability = `S'
end


* ---- panel form: wide pre-period file in a frame, then the main command ------
program define _tm_panel, rclass
    version 16.0
    syntax [varlist(default=none numeric)] [if] [in], id(varname) treated(string) ///
        ntwins(integer) time(varname) outcome(varname) window(numlist) ///
        [generate(name) standardize strata(varlist) caliper(real -1) growth ///
         preweight(real 1) balance stability saving(string asis) nodisplay]
    local covs `varlist'
    tokenize `window'
    local w0 `1'
    local w1 `2'
    marksample touse, novarlist
    markout `touse' `time' `outcome'
    quietly replace `touse' = 0 if !inrange(`time', `w0', `w1')
    tempvar dup
    quietly bysort `touse' `id' `time': gen byte `dup' = (_N > 1) if `touse'
    quietly count if `dup' == 1
    if r(N) > 0 {
        display as error "`id' and `time' do not uniquely identify observations in the window"
        exit 459
    }
    if "`generate'" != "" confirm new variable `generate'

    tempname fr
    tempvar ord
    quietly gen long `ord' = _n
    frame put `id' `time' `outcome' `covs' `strata' if `touse', into(`fr')
    frame `fr' {
        * covariates and strata at the last period of the window
        sort `id' `time'
        foreach v in `covs' `strata' {
            quietly by `id': replace `v' = `v'[_N]
        }
        quietly reshape wide `outcome', i(`id' `covs' `strata') j(`time')
        local ycols ""
        forvalues t = `w0'/`w1' {
            capture confirm variable `outcome'`t'
            if _rc {
                display as error "no observations at `time' == `t'; every period in window() must be present"
                exit 2000
            }
            local ycols `ycols' `outcome'`t'
        }
        local pass ""
        if "`generate'" != "" local pass `pass' generate(`generate')
        if "`strata'" != ""   local pass `pass' strata(`strata')
        if `"`saving'"' != "" local pass `"`pass' saving(`saving')"'
        twinmatch `covs', id(`id') treated(`treated') ntwins(`ntwins') `standardize' ///
            caliper(`caliper') pretrend(`ycols') `growth' preweight(`preweight') ///
            `balance' `stability' `nodisplay' `pass'
        return add
        if "`generate'" != "" {
            quietly keep `id' `generate'
        }
    }
    if "`generate'" != "" {
        tempvar lnk
        quietly frlink m:1 `id', frame(`fr') generate(`lnk')
        quietly frget `generate' = `generate', from(`lnk')
        label variable `generate' "Distance to `treated' (window `w0'-`w1')"
    }
    frame drop `fr'
    sort `ord'
    return local window "`w0' `w1'"
    return local outcome "`outcome'"
end


* ---- ledger file -----------------------------------------------------------------
program define _tm_save
    version 16.0
    syntax [varlist(default=none)], saving(string asis) id(varname) idstr(varname) rank(varname) ///
        treated(string) metric(string) touse(varname) showtab(integer) [strata(string) caliper(real -1)]
    gettoken fname sopts : saving, parse(",")
    local fname = strtrim(`"`fname'"')
    local replace = (strpos(lower(`"`sopts'"'), "replace") > 0)
    local ext = lower(substr(`"`fname'"', -4, .))
    if "`ext'" != ".csv" & "`ext'" != ".dta" local fname `"`fname'.dta"'
    preserve
    quietly keep if (`rank' < . & `touse') | `idstr' == `"`treated'"'
    quietly keep `id' `rank' `varlist' `strata'
    quietly replace `rank' = 0 if `rank' == .
    rename `rank' twin_rank
    label variable twin_rank "0 = treated unit; 1 = nearest twin"
    quietly gen str80 tm_treated = `"`treated'"'
    quietly gen str20 tm_metric = "`metric'"
    quietly gen str244 tm_covariates = "`varlist'"
    quietly gen str80 tm_strata = "`strata'"
    quietly gen double tm_caliper = cond(`caliper' > 0, `caliper', .)
    quietly gen str10 tm_date = "`c(current_date)'"
    sort twin_rank
    if "`ext'" == ".csv" {
        if `replace' export delimited using `"`fname'"', replace
        else export delimited using `"`fname'"'
    }
    else {
        label data "twinmatch shortlist for `treated' (`c(current_date)')"
        note: twinmatch shortlist for `treated' on `c(current_date)': metric `metric'; covariates `varlist'; strata `strata'
        if `replace' quietly save `"`fname'"', replace
        else quietly save `"`fname'"'
    }
    restore
    if `showtab' display as text `"shortlist written to {bf:`fname'}"'
end


version 16.0
mata:
void tm_findtwins(string scalar covlist, string scalar prelist, string scalar idvar,
                  string scalar treatval, real scalar k,
                  string scalar touse, string scalar cand, string scalar genvar,
                  string scalar rankvar, real scalar usestd, real scalar growth,
                  real scalar preweight, real scalar caliper, real scalar showtab)
{
    real matrix    X, P, results, covX, W
    real rowvector x_t, mu, sd, p_t
    real colvector dists, dpre, isc, ranks, idxv
    real scalar    i, j, n, p, q, treat_idx, idx, ndrop, kk, cutoff
    string matrix  ID
    string rowvector vnames
    string scalar  twinlist, distlist, dropped

    ID = st_sdata(., idvar, touse)
    isc = st_data(., cand, touse)
    n  = rows(ID)
    idxv = selectindex(st_data(., touse) :== 1)

    // locate the treated unit (uniqueness verified by the caller)
    treat_idx = 0
    for (i=1; i<=n; i++) {
        if (ID[i,1] == treatval) {
            treat_idx = i
            break
        }
    }
    if (treat_idx == 0) {
        errprintf("treated unit '%s' not found\n", treatval)
        exit(111)
    }

    // ---- covariate block ---------------------------------------------------
    dists = J(n, 1, 0)
    p = 0
    if (covlist != "") {
        X = st_data(., covlist, touse)
        p = cols(X)
        vnames = tokens(covlist)
        if (usestd) {
            mu = mean(X)
            sd = sqrt(diagonal(variance(X)))'
            dropped = ""
            ndrop   = 0
            for (j=1; j<=p; j++) {
                if (sd[j] <= 0 | missing(sd[j])) {
                    sd[j]   = 1
                    X[.,j]  = J(n, 1, mu[j])
                    dropped = dropped + " " + vnames[j]
                    ndrop++
                }
            }
            if (ndrop > 0 & showtab) {
                printf("{txt}note: constant covariate(s) carry no distance information ")
                printf("and were dropped:{res}%s\n", dropped)
            }
            if (ndrop == p & prelist == "") {
                errprintf("all covariates are constant; distances are undefined\n")
                exit(198)
            }
            X = (X :- mu) :/ sd
            W = I(p)
        }
        else {
            covX = variance(X)
            W    = invsym(covX)
            dropped = ""
            ndrop   = 0
            for (j=1; j<=p; j++) {
                if (W[j,j] == 0) {
                    dropped = dropped + " " + vnames[j]
                    ndrop++
                }
            }
            if (ndrop == p & prelist == "") {
                errprintf("covariance matrix has rank 0; distances are undefined\n")
                exit(506)
            }
            if (ndrop > 0 & showtab) {
                printf("{txt}note: covariance matrix is singular; {cmd:invsym()} dropped ")
                printf("collinear covariate(s):{res}%s\n", dropped)
                printf("{txt}      distances use the remaining %s linearly independent covariate(s)\n",
                       strofreal(p - ndrop))
            }
        }
        x_t = X[treat_idx, .]
        for (i=1; i<=n; i++) {
            dists[i] = (X[i,.] - x_t) * W * (X[i,.] - x_t)'
        }
    }

    // ---- pre-trend block: z-score each period, Euclidean, added in quadrature
    if (prelist != "") {
        P = st_data(., prelist, touse)
        q = cols(P)
        if (growth) P = P :- P[., 1]
        mu = mean(P)
        sd = sqrt(diagonal(variance(P)))'
        for (j=1; j<=q; j++) if (sd[j] <= 0 | missing(sd[j])) sd[j] = 1
        P = (P :- mu) :/ sd
        p_t = P[treat_idx, .]
        dpre = rowsum((P :- p_t) :^ 2)
        dists = dists + preweight * dpre
    }
    dists = sqrt(dists)

    // optionally store every unit's distance back into the dataset
    if (genvar != "") st_store(., genvar, touse, dists)

    // rank candidates: sort by distance, break ties by original order
    results = dists, (1::n)
    results = select(results, (results[.,2] :!= treat_idx) :& (isc :== 1))
    results = sort(results, (1,2))

    // caliper: keep only the twins within it
    kk = k
    if (caliper > 0) {
        cutoff = 0
        for (i=1; i<=rows(results); i++) if (results[i,1] <= caliper) cutoff = i
        if (cutoff < kk) kk = cutoff
    }
    st_local("tm_k", strofreal(kk))
    st_local("tm_nearest", strofreal(results[1,1], "%9.4f"))
    st_local("tm_kth", strofreal(kk > 0 ? results[kk,1] : ., "%21.0g"))
    st_local("tm_median", strofreal(rows(results) > 0 ? mm_median_tm(results[.,1]) : ., "%21.0g"))
    if (kk == 0) {
        st_local("tm_twinlist", "")
        st_local("tm_distlist", "")
        return
    }

    // twin ranks back to the dataset (treated unit = 0)
    ranks = J(n, 1, .)
    ranks[treat_idx] = 0
    for (i=1; i<=kk; i++) ranks[results[i,2]] = i
    st_store(idxv, rankvar, ranks)

    if (showtab) {
        printf("\n{txt}Policy twins for {res}%s{txt} (metric: %s%s, %s comparison units)\n",
               treatval, (usestd ? "Euclidean on z-scores" : "Mahalanobis"),
               (prelist != "" ? " + pre-trend path" : ""),
               strofreal(rows(results)))
        printf("{txt}{hline 48}\n")
        printf("{txt}%-6s %-28s %12s\n", "Rank", "Unit", "Distance")
        printf("{txt}{hline 48}\n")
    }
    twinlist = ""
    distlist = ""
    for (i=1; i<=kk; i++) {
        idx = results[i,2]
        if (showtab) printf("{txt}%-6.0f {res}%-28s %12.4f\n", i, ID[idx,1], results[i,1])
        twinlist = twinlist + (i > 1 ? " " : "") +
                   "`" + char(34) + ID[idx,1] + char(34) + "'"
        distlist = distlist + (i > 1 ? " " : "") +
                   strofreal(results[i,1], "%12.0g")
    }
    if (showtab) printf("{txt}{hline 48}\n")

    st_local("tm_twinlist", twinlist)
    st_local("tm_distlist", distlist)
}

real scalar mm_median_tm(real colvector v)
{
    real colvector s
    real scalar n
    s = sort(v, 1)
    n = rows(s)
    if (n == 0) return(.)
    if (mod(n, 2) == 1) return(s[(n + 1) / 2])
    return((s[n / 2] + s[n / 2 + 1]) / 2)
}
end
