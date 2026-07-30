*! version 0.1.0  2026-07-06  Eric A. Booth, Sr Researcher, Texas 2036
*! twinmatch: policy-twin selection by Mahalanobis distance
* version 16.0 suffices: uses only long-standing Mata and syntax features.

program define twinmatch, rclass
    version 16.0
    syntax varlist(min=1 numeric) [if] [in], ///
        ID(varname) Treated(string) ///
        [ Ntwins(integer 3) GENerate(name) STANDardize ]

    * ---- sample -------------------------------------------------------------
    marksample touse
    markout `touse' `id', strok

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

    * ---- validate ntwins -----------------------------------------------------
    quietly count if `touse'
    local nobs = r(N)
    if `nobs' < 2 {
        display as error "too few observations: need the treated unit plus at least one comparison unit"
        exit 2001
    }
    if `ntwins' < 1 {
        display as error "ntwins() must be a positive integer"
        exit 198
    }
    if `ntwins' > `nobs' - 1 {
        display as error "ntwins(`ntwins') exceeds the `=`nobs'-1' available comparison units"
        exit 198
    }

    * ---- optional distance variable ------------------------------------------
    if "`generate'" != "" {
        confirm new variable `generate'
        quietly gen double `generate' = .
    }

    * ---- compute -------------------------------------------------------------
    local usestd = ("`standardize'" != "")
    mata: tm_findtwins("`varlist'", "`id_str'", `"`treatval'"', ///
        `ntwins', "`touse'", "`generate'", `usestd')

    if "`generate'" != "" {
        if `usestd' {
            label variable `generate' "Euclidean distance (z-scored covariates) to `treatval'"
        }
        else {
            label variable `generate' "Mahalanobis distance to `treatval'"
        }
        display as text `"distance to "`treatval'" stored in {bf:`generate'}"'
    }

    * ---- stored results --------------------------------------------------------
    return scalar N       = `nobs'
    return scalar k       = `ntwins'
    return local  metric  = cond(`usestd', "standardized", "mahalanobis")
    return local  treated `"`treatval'"'
    return local  dists   "`tm_distlist'"
    return local  twins   `"`tm_twinlist'"'
end

version 16.0
mata:
void tm_findtwins(string scalar varlist, string scalar idvar,
                  string scalar treatval, real scalar k,
                  string scalar touse, string scalar genvar,
                  real scalar usestd)
{
    real matrix    X, results
    real rowvector x_t, mu, sd
    real colvector dists
    real scalar    i, j, n, p, treat_idx, idx, ndrop
    real matrix    covX, W
    string matrix  ID
    string rowvector vnames
    string scalar  twinlist, distlist, dropped

    X  = st_data(., varlist, touse)
    ID = st_sdata(., idvar, touse)
    n  = rows(X)
    p  = cols(X)
    vnames = tokens(varlist)

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

    if (usestd) {
        // z-score each covariate; distance is Euclidean on the z-scores
        // (equivalently, Mahalanobis with a diagonal covariance matrix)
        mu = mean(X)
        sd = sqrt(diagonal(variance(X)))'
        dropped = ""
        ndrop   = 0
        for (j=1; j<=p; j++) {
            if (sd[j] <= 0 | missing(sd[j])) {
                sd[j]   = 1                    // neutralize; column contributes 0
                X[.,j]  = J(n, 1, mu[j])
                dropped = dropped + " " + vnames[j]
                ndrop++
            }
        }
        if (ndrop > 0) {
            printf("{txt}note: constant covariate(s) carry no distance information ")
            printf("and were dropped:{res}%s\n", dropped)
        }
        if (ndrop == p) {
            errprintf("all covariates are constant; distances are undefined\n")
            exit(198)
        }
        X = (X :- mu) :/ sd
        W = I(p)
    }
    else {
        covX = variance(X)
        W    = invsym(covX)
        // invsym() zeroes the row/column of any collinear (dependent) column,
        // which drops it from the distance.  Report what was dropped.
        dropped = ""
        ndrop   = 0
        for (j=1; j<=p; j++) {
            if (W[j,j] == 0) {
                dropped = dropped + " " + vnames[j]
                ndrop++
            }
        }
        if (ndrop == p) {
            errprintf("covariance matrix has rank 0; distances are undefined\n")
            exit(506)
        }
        if (ndrop > 0) {
            printf("{txt}note: covariance matrix is singular; {cmd:invsym()} dropped ")
            printf("collinear covariate(s):{res}%s\n", dropped)
            printf("{txt}      distances use the remaining %s linearly independent covariate(s)\n",
                   strofreal(p - ndrop))
        }
    }

    // distances from every unit to the treated unit
    x_t   = X[treat_idx, .]
    dists = J(n, 1, .)
    for (i=1; i<=n; i++) {
        dists[i] = sqrt((X[i,.] - x_t) * W * (X[i,.] - x_t)')
    }

    // optionally store every unit's distance back into the dataset
    if (genvar != "") st_store(., genvar, touse, dists)

    // rank comparison units: sort by distance, break ties by original order
    // (deterministic: no randomness anywhere)
    results = dists, (1::n)
    results = select(results, results[.,2] :!= treat_idx)
    results = sort(results, (1,2))

    printf("\n{txt}Policy twins for {res}%s{txt} (metric: %s, %s comparison units)\n",
           treatval, (usestd ? "Euclidean on z-scores" : "Mahalanobis"),
           strofreal(n - 1))
    printf("{txt}{hline 48}\n")
    printf("{txt}%-6s %-28s %12s\n", "Rank", "Unit", "Distance")
    printf("{txt}{hline 48}\n")

    twinlist = ""
    distlist = ""
    for (i=1; i<=k; i++) {
        idx = results[i,2]
        printf("{txt}%-6.0f {res}%-28s %12.4f\n", i, ID[idx,1], results[i,1])
        twinlist = twinlist + (i > 1 ? " " : "") +
                   "`" + char(34) + ID[idx,1] + char(34) + "'"
        distlist = distlist + (i > 1 ? " " : "") +
                   strofreal(results[i,1], "%12.0g")
    }
    printf("{txt}{hline 48}\n")

    st_local("tm_twinlist", twinlist)
    st_local("tm_distlist", distlist)
}
end
