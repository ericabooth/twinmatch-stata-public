{smcl}
{* *! version 0.2.0  2026-11-14}{...}
{vieweralsosee "[R] teffects nnmatch" "help teffects nnmatch"}{...}
{vieweralsosee "[MV] cluster kmeans" "help cluster kmeans"}{...}
{vieweralsosee "[D] frames" "help frames"}{...}
{viewerjumpto "Syntax" "twinmatch##syntax"}{...}
{viewerjumpto "Description" "twinmatch##description"}{...}
{viewerjumpto "Three choices" "twinmatch##choices"}{...}
{viewerjumpto "Options" "twinmatch##options"}{...}
{viewerjumpto "What the output shows" "twinmatch##output"}{...}
{viewerjumpto "Remarks" "twinmatch##remarks"}{...}
{viewerjumpto "Examples" "twinmatch##examples"}{...}
{viewerjumpto "Stored results" "twinmatch##results"}{...}
{viewerjumpto "Related and complementary commands" "twinmatch##related"}{...}
{viewerjumpto "References" "twinmatch##references"}{...}
{viewerjumpto "Author" "twinmatch##author"}{...}

{title:Title}

{p2colset 5 18 20 2}{...}
{p2col :{cmd:twinmatch} {hline 2}}Policy-twin selection by Mahalanobis distance{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:twinmatch} [{varlist}] {ifin}{cmd:,} {cmd:id(}{varname}{cmd:)}
{cmd:treated(}{it:unit}{cmd:)} [{it:options}]

{p 4 6 2}{it:varlist} holds the numeric matching covariates.  It may be
omitted when the match is on the outcome's pre-policy path alone
({cmd:pretrend()} or {cmd:time()}).  Observations with a missing
covariate, strata value, or id are excluded.{p_end}

{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{syntab :Required}
{synopt :{cmd:id(}{varname}{cmd:)}}unit identifier; string or numeric, must be unique{p_end}
{synopt :{cmd:treated(}{it:unit}{cmd:)}}id value of the treated unit (the unit to be matched){p_end}

{syntab :How many, which metric}
{synopt :{cmd:ntwins(}{it:#}{cmd:)}}number of nearest twins to report; default is {cmd:ntwins(3)}{p_end}
{synopt :{cmd:standardize}}Euclidean distance on z-scored covariates instead of the full Mahalanobis metric{p_end}
{synopt :{cmd:generate(}{it:newvar}{cmd:)}}store every unit's distance to the treated unit{p_end}

{syntab :The pool}
{synopt :{cmd:strata(}{it:varlist}{cmd:)}}candidates must match the treated unit exactly on these variables{p_end}
{synopt :{cmd:caliper(}{it:#}{cmd:)}}drop candidates farther than this; fewer than {cmd:ntwins()} may be returned{p_end}

{syntab :The outcome's path before the policy}
{synopt :{cmd:pretrend(}{it:varlist}{cmd:)}}wide data: one column per pre-policy period of the outcome{p_end}
{synopt :{cmd:time(}{varname}{cmd:)} {cmd:outcome(}{varname}{cmd:)} {cmd:window(}{it:first last}{cmd:)}}long panel: the outcome's path over these periods{p_end}
{synopt :{cmd:growth}}match on change since the first period of the path rather than on levels{p_end}
{synopt :{cmd:preweight(}{it:#}{cmd:)}}weight on the path block relative to the covariates; default {cmd:preweight(1)}{p_end}

{syntab :Checks and records}
{synopt :{cmd:balance}}print the balance table (treated value, twin mean, sample mean, standardized difference){p_end}
{synopt :{cmd:stability}}re-pick with each covariate removed and report the overlap with the shortlist{p_end}
{synopt :{cmd:saving(}{it:filename}[{cmd:, replace}]{cmd:)}}write the shortlist, with what produced it, as a {cmd:.dta} or {cmd:.csv} ledger file{p_end}
{synopt :{cmd:nodisplay}}compute without printing{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:twinmatch} finds the comparison units that most resemble one treated
unit on a set of covariates {hline 2} its "policy twins."  It computes the
Mahalanobis distance from every candidate to the treated unit, ranks the
candidates from nearest to farthest, and reports the {cmd:ntwins()}
closest.  Ties are broken by data order, so results are exactly reproducible
without a seed.

{pstd}
The command is a small-{it:N} comparison-group helper for program evaluation:
when one district, county, campus, hospital, or firm adopts a policy, it
selects the handful of untreated units against which before/after
trajectories can be compared.  Version 0.2 adds the pieces a reviewer asks
for next: a stratum and a caliper to say who may be a twin at all, matching
on the outcome's path before the policy, a balance table, a stability check,
and a ledger file that records the shortlist and the choices behind it.

{pstd}
It selects and describes.  It does not weight the twins, estimate effects,
or compute uncertainty; see {help twinmatch##related:Related and complementary commands}
for the tools that do those jobs once the twins are chosen.


{marker choices}{...}
{title:Three choices}

{pstd}
Three decisions separate "compare this unit" from a comparison a reader can
check, and the options keep them apart so each can be stated and defended.

{phang}{bf:The pool.}  Who is a candidate at all.  {ifin} restricts the
sample; {cmd:strata()} requires an exact match on a few variables (a sector,
a size class, a metro flag); {cmd:caliper()} refuses candidates farther than
a stated distance.  A stratum is a strong statement: no unit outside it can
be a twin, however similar.{p_end}

{phang}{bf:The covariates.}  What "similar" is measured on: the {it:varlist},
and, when the design is a before/after comparison, the outcome's own path
before the policy ({cmd:pretrend()} or {cmd:time()}).  Covariates should
describe conditions the unit cannot easily change and that plausibly drive
the outcome.  Including the outcome's pre-policy path is the small-{it:N}
analogue of checking parallel trends: twins that moved with the treated unit
before the policy are the ones whose later divergence means something.{p_end}

{phang}{bf:The metric.}  Mahalanobis distance by default, which rescales each
covariate by its spread and discounts correlated covariates so no one
variable dominates; or {cmd:standardize}, which weights every covariate
equally on the standard-deviation scale.{p_end}


{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}{cmd:id(}{varname}{cmd:)} names the unit identifier.  A numeric id
is converted to its string form for matching and reporting, so
{cmd:treated("5")} matches the numeric id 5.  The treated value must
identify exactly one observation in the estimation sample (one unit in the
panel form).{p_end}

{phang}{cmd:treated(}{it:unit}{cmd:)} gives the id value of the treated unit.
Values are matched after trimming leading and trailing spaces.{p_end}

{dlgtab:How many, which metric}

{phang}{cmd:ntwins(}{it:#}{cmd:)} sets how many nearest candidates to report
and store; it must be at least 1 and no larger than the number of candidates
in the pool (after {cmd:strata()}).{p_end}

{phang}{cmd:standardize} replaces the full Mahalanobis metric with Euclidean
distance on z-scored covariates (equivalently, Mahalanobis with a diagonal
covariance matrix).  Because full Mahalanobis distance also adjusts for the
correlations among covariates, a pair of highly correlated covariates is
partially discounted; {cmd:standardize} weights every covariate equally on
the standard-deviation scale, which is often easier to defend when covariate
scales differ wildly and the correlation structure is noisy in small
samples.{p_end}

{phang}{cmd:generate(}{it:newvar}{cmd:)} creates a {cmd:double} variable
holding each in-sample unit's distance to the treated unit (0 for the
treated unit itself), including units outside the strata or caliper, which
is useful for plotting the full distance distribution or for choosing a
caliper.  In the panel form the distance is repeated on every row of the
unit.  The variable is created only when the command succeeds.{p_end}

{dlgtab:The pool}

{phang}{cmd:strata(}{it:varlist}{cmd:)} restricts candidates to units with
the treated unit's exact values on these variables, string or numeric.  The
metric is still estimated on the whole estimation sample, so the distances
do not change; only who is eligible changes.  {cmd:r(N_pool)} reports how
many candidates remain.  When nobody shares the treated unit's values the
command stops with an error rather than returning a twin from outside the
stratum.{p_end}

{phang}{cmd:caliper(}{it:#}{cmd:)} drops candidates farther than {it:#} from
the treated unit, on the distance scale in use.  Fewer than {cmd:ntwins()}
twins may then be returned, and {cmd:r(k)} says how many; when no candidate
is within the caliper the command stops with an error and names the nearest
distance.  Under the Mahalanobis metric a caliper of 2 or 3 is loose; under
{cmd:standardize} it scales with the number of covariates.  Run once with
{cmd:generate()} to see the distribution before choosing one.{p_end}

{dlgtab:The outcome's path before the policy}

{phang}{cmd:pretrend(}{it:varlist}{cmd:)} names, in wide data, one column per
pre-policy period of the outcome (for example {cmd:y2015 y2016 y2017}).  Each
column is z-scored across units, the squared differences from the treated
unit are summed, and the result is added to the squared covariate distance
before the square root, so the path and the covariates enter the one
distance together.  The path block always uses the z-score form, whatever
the covariate metric, because adjacent periods are so correlated that a
Mahalanobis metric on them would be unstable.{p_end}

{phang}{cmd:time(}{varname}{cmd:)}, {cmd:outcome(}{varname}{cmd:)}, and
{cmd:window(}{it:first last}{cmd:)} do the same for a long panel: one row
per unit and period.  The command builds the wide pre-policy file in a
temporary frame, takes each covariate and stratum at the last period of the
window, and matches on the outcome's path over the window.  Every period in
the window must be present for the treated unit; candidates with a gap are
dropped.  The three options go together.{p_end}

{phang}{cmd:growth} matches on change since the first period of the path
rather than on levels, so units that started at different levels but moved
together are twins.{p_end}

{phang}{cmd:preweight(}{it:#}{cmd:)} multiplies the path block before it is
added to the covariate block.  Values above 1 let the pre-trend dominate;
values below 1 let the covariates dominate.  Default 1.{p_end}

{dlgtab:Checks and records}

{phang}{cmd:balance} prints, for each covariate and each path column, the
treated unit's value, the mean of the twins, the sample mean, and the
standardized difference (twin mean minus treated value, over the sample
standard deviation).  The table is always returned in {cmd:r(balance)}; the
option only prints it.{p_end}

{phang}{cmd:stability} re-picks the twins with one covariate removed at a
time (and, when a path is given, with the covariates alone and the path
alone) and reports how many twins each version shares with the shortlist and
the Jaccard overlap (shared over the union; 1 means the same list).  A
covariate whose removal changes the list by half is the covariate doing the
work.  The table is returned in {cmd:r(stability)}.{p_end}

{phang}{cmd:saving(}{it:filename}[{cmd:, replace}]{cmd:)} writes the
shortlist as a ledger file: one row for the treated unit ({cmd:twin_rank}
0) and one per twin, with the covariates and path columns, and with the
treated id, metric, covariate list, strata, caliper, and date in columns
{cmd:tm_*}.  A {cmd:.csv} extension writes CSV; anything else writes a
{cmd:.dta} with a data label and a note.  This is the record to file with
the project before the outcome data arrive.{p_end}

{phang}{cmd:nodisplay} suppresses all output; results are still returned and
{cmd:generate()} still works.{p_end}


{marker output}{...}
{title:What the output shows}

{pstd}
The ranked table lists the twins, nearest first, with their distances.  The
{bf:support} line below it gives the distance to the last twin and the
median distance among all candidates: when the last twin is farther away
than the typical candidate, the shortlist has reached past the units that
resemble the treated one, and a smaller {cmd:ntwins()} or a caliper is in
order.  With {cmd:balance}, a standardized difference near zero on every row
says the twins resemble the treated unit on the things you chose to match;
a large one says the pool holds no close match on that variable, and the
sign says which way the twins are off.  The command flags the largest
absolute value when it exceeds 0.25.


{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:Singular covariance matrices.}  When the covariates are collinear (for
example, one is a linear combination of others), the covariance matrix
cannot be inverted.  {cmd:twinmatch} uses {helpb mf_invsym:invsym()}, which
drops the dependent columns from the metric; the command prints a note
naming the dropped covariates and continues.  Because Mahalanobis distance
is unchanged by removing redundant columns, the reported twins are the same
as if the collinear covariates had been omitted.  Under {cmd:standardize},
a constant covariate (zero variance) is likewise dropped with a note.

{pstd}
{bf:Extreme treated units.}  A treated unit at the edge of the pool (the
largest county, the only border district) has no close twins, and the
nearest {it:k} will be returned regardless.  The support line and the
balance table are there to catch this; "no adequate twins" is a legitimate
finding, and {cmd:caliper()} turns it into an explicit result.

{pstd}
{bf:What twinmatch does not do.}  It does not weight the selected twins,
estimate effects, or compute intervals.  Treat the twin list as the starting
point for a comparative case study, or as the donor pool handed to a
synthetic-control or difference-in-differences command.


{marker examples}{...}
{title:Examples}

{pstd}{bf:Three policy twins for one unit, on three covariates}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. twinmatch mpg price weight, id(make) treated("Volvo 260")}{p_end}

{pstd}{bf:Five twins, storing every unit's distance for inspection}{p_end}
{phang2}{cmd:. twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(5) generate(dist260)}{p_end}
{phang2}{cmd:. sort dist260}{p_end}
{phang2}{cmd:. list make dist260 in 1/10}{p_end}

{pstd}{bf:Z-scored (diagonal) metric when scales differ wildly}{p_end}
{phang2}{cmd:. twinmatch mpg price weight, id(make) treated("Volvo 260") standardize}{p_end}

{pstd}{bf:Only candidates of the same origin may be twins}{p_end}
{phang2}{cmd:. twinmatch mpg price weight, id(make) treated("Volvo 260") strata(foreign)}{p_end}

{pstd}{bf:A caliper: take up to five twins, but none farther than 1 (two qualify)}{p_end}
{phang2}{cmd:. twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(5) caliper(1)}{p_end}
{phang2}{cmd:. display r(k) " twin(s) within the caliper"}{p_end}

{pstd}{bf:Show the balance and test which covariate drives the list}{p_end}
{phang2}{cmd:. twinmatch mpg price weight, id(make) treated("Volvo 260") balance stability}{p_end}
{phang2}{cmd:. matrix list r(balance)}{p_end}
{phang2}{cmd:. matrix list r(stability)}{p_end}

{pstd}{bf:Write the shortlist to the project ledger}{p_end}
{phang2}{cmd:. twinmatch mpg price weight, id(make) treated("Volvo 260") saving(ledger/twins_volvo.csv, replace)}{p_end}

{pstd}{bf:A panel: firms whose investment moved with firm 1 over 1935-1944, given size}{p_end}
{phang2}{cmd:. webuse grunfeld, clear}{p_end}
{phang2}{cmd:. twinmatch mvalue kstock, id(company) treated(1) ntwins(3) time(year) outcome(invest) window(1935 1944) balance}{p_end}

{pstd}{bf:The same on the path alone, matching the shape rather than the level}{p_end}
{phang2}{cmd:. twinmatch, id(company) treated(1) ntwins(3) time(year) outcome(invest) window(1935 1944) growth}{p_end}

{pstd}{bf:Wide data with one column per year}{p_end}
{phang2}{cmd:. webuse grunfeld, clear}{p_end}
{phang2}{cmd:. keep if year <= 1944}{p_end}
{phang2}{cmd:. keep company year invest mvalue kstock}{p_end}
{phang2}{cmd:. reshape wide invest mvalue kstock, i(company) j(year)}{p_end}
{phang2}{cmd:. twinmatch mvalue1944 kstock1944, id(company) treated(1) pretrend(invest1935-invest1944) ntwins(3)}{p_end}

{pstd}{bf:Let the pre-trend dominate the covariates}{p_end}
{phang2}{cmd:. twinmatch mvalue1944 kstock1944, id(company) treated(1) pretrend(invest1935-invest1944) preweight(4)}{p_end}

{pstd}{bf:Retrieve the twins programmatically}{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. twinmatch mpg price weight, id(make) treated("Volvo 260") nodisplay}{p_end}
{phang2}{cmd:. display `"`r(twins)'"'}{p_end}
{phang2}{cmd:. local first : word 1 of `r(twins)'}{p_end}
{phang2}{cmd:. display `"nearest twin: `first'"'}{p_end}

{pstd}{bf:Keep only the treated unit and its twins for the next step}{p_end}
{phang2}{cmd:. twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(5) generate(d)}{p_end}
{phang2}{cmd:. gsort d}{p_end}
{phang2}{cmd:. keep in 1/6}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:twinmatch} stores in {cmd:r()}:{p_end}
{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt :{cmd:r(N)}}observations in the estimation sample (units, in the panel form){p_end}
{synopt :{cmd:r(N_pool)}}candidates after {cmd:strata()}{p_end}
{synopt :{cmd:r(k)}}twins reported (fewer than {cmd:ntwins()} under a caliper){p_end}
{synopt :{cmd:r(kth_dist)}}distance to the last twin{p_end}
{synopt :{cmd:r(median_dist)}}median distance among all candidates{p_end}
{synopt :{cmd:r(max_stddiff)}}largest absolute standardized difference in the balance table{p_end}
{synopt :{cmd:r(caliper)}}the caliper, when one was given{p_end}

{p2col 5 18 22 2: Macros}{p_end}
{synopt :{cmd:r(twins)}}ids of the twins, nearest first; each id wrapped in compound quotes so ids with spaces survive (extract with {cmd:local x : word # of `r(twins)'}){p_end}
{synopt :{cmd:r(dists)}}distances aligned with {cmd:r(twins)}{p_end}
{synopt :{cmd:r(treated)}}id of the treated unit{p_end}
{synopt :{cmd:r(metric)}}{cmd:mahalanobis} or {cmd:standardized}{p_end}
{synopt :{cmd:r(covariates)}}, {cmd:r(pretrend)}, {cmd:r(strata)}: the variables used{p_end}
{synopt :{cmd:r(outcome)}}, {cmd:r(window)}: the panel outcome and window, in the panel form{p_end}

{p2col 5 18 22 2: Matrices}{p_end}
{synopt :{cmd:r(balance)}}rows = covariates and path columns; columns treated, twins, sample, stddiff{p_end}
{synopt :{cmd:r(stability)}}rows = each removed ingredient; columns twins, shared, overlap (with {cmd:stability}){p_end}
{p2colreset}{...}


{marker related}{...}
{title:Related and complementary commands}

{pstd}
{cmd:twinmatch} chooses and documents the comparison units.  The commands
below do the neighbouring jobs; most are on SSC ({cmd:ssc install} {it:name})
and some are official Stata.{p_end}

{phang}{bf:Weighting the twins and estimating an effect from a panel.}
{cmd:synth} (Abadie, Diamond, and Hainmueller) fits synthetic-control weights
to the donor pool; {cmd:allsynth} adds bias correction and placebo
inference; {cmd:scpi} (Cattaneo, Feng, Palomba, and Titiunik) adds
prediction intervals with finite-sample coverage; {cmd:sdid} (Arkhangelsky
and co-authors) is synthetic difference-in-differences.  Hand them the units
in {cmd:r(twins)} as the donor pool.{p_end}

{phang}{bf:Difference-in-differences once the comparison group is set.}
Official {cmd:didregress} and {cmd:xtdidregress}; {cmd:csdid}
(Callaway and Sant'Anna) and {cmd:did_multiplegt} (de Chaisemartin and
D'Haultfoeuille) for staggered adoption.{p_end}

{phang}{bf:Matching many treated units, with estimation.}  Official
{cmd:teffects nnmatch} and {cmd:teffects psmatch}; {cmd:psmatch2};
{cmd:kmatch} (multivariate-distance and propensity-score matching with
balance diagnostics).  {cmd:twinmatch} is the one-treated-unit case of
{cmd:teffects nnmatch} with the shortlist, not the effect, as the
product.{p_end}

{phang}{bf:Other ways to define "comparable".}  {cmd:cem} (coarsened exact
matching: bins on each covariate rather than a distance); {cmd:ebalance}
(entropy balancing: weights so the pool's means equal the treated unit's
values); official {cmd:cluster kmeans} (typologies: every member of the
treated unit's cluster).  {cmd:peerpick} (same author) offers these and
others behind one syntax, with a specification curve and placebo checks, for
benchmarking questions where the unit is not "treated" at all.{p_end}

{phang}{bf:Balance after matching.}  Official {cmd:tebalance} after
{cmd:teffects}; {cmd:pstest} after {cmd:psmatch2}.  The {cmd:balance} table
here is the one-unit version of the same idea.{p_end}


{marker references}{...}
{title:References}

{phang}Abadie, A.  2021.  Using synthetic controls: Feasibility, data
requirements, and methodological aspects.  {it:Journal of Economic Literature}
59: 391-425.  {browse "https://doi.org/10.1257/jel.20191450":doi:10.1257/jel.20191450}{p_end}

{phang}Abadie, A., A. Diamond, and J. Hainmueller.  2010.  Synthetic control
methods for comparative case studies: Estimating the effect of California's
tobacco control program.  {it:Journal of the American Statistical Association}
105: 493-505.  {browse "https://doi.org/10.1198/jasa.2009.ap08746":doi:10.1198/jasa.2009.ap08746}{p_end}

{phang}Hainmueller, J.  2012.  Entropy balancing for causal effects: A
multivariate reweighting method to produce balanced samples in observational
studies.  {it:Political Analysis} 20: 25-46.
{browse "https://doi.org/10.1093/pan/mpr025":doi:10.1093/pan/mpr025}{p_end}

{phang}Iacus, S. M., G. King, and G. Porro.  2012.  Causal inference without
balance checking: Coarsened exact matching.  {it:Political Analysis} 20: 1-24.
{browse "https://doi.org/10.1093/pan/mpr013":doi:10.1093/pan/mpr013}{p_end}

{phang}Rubin, D. B.  1980.  Bias reduction using Mahalanobis-metric matching.
{it:Biometrics} 36: 293-298.
{browse "https://doi.org/10.2307/2529981":doi:10.2307/2529981}{p_end}

{phang}Stuart, E. A.  2010.  Matching methods for causal inference: A review
and a look forward.  {it:Statistical Science} 25: 1-21.
{browse "https://doi.org/10.1214/09-STS313":doi:10.1214/09-STS313}{p_end}


{marker author}{...}
{title:Author}

{pstd}
Eric A. Booth, Sr Researcher, Texas 2036 (eric.a.booth@gmail.com), 2026.
MIT-licensed.  Issues and suggestions at the
{browse "https://github.com/ericabooth/twinmatch-stata-public":GitHub repository}.{p_end}
