{smcl}
{* *! version 0.1.0  2026-07-06}{...}
{viewerjumpto "Syntax" "twinmatch##syntax"}{...}
{viewerjumpto "Description" "twinmatch##description"}{...}
{viewerjumpto "Options" "twinmatch##options"}{...}
{viewerjumpto "Remarks" "twinmatch##remarks"}{...}
{viewerjumpto "Examples" "twinmatch##examples"}{...}
{viewerjumpto "Stored results" "twinmatch##results"}{...}

{title:Title}

{p2colset 5 18 20 2}{...}
{p2col :{cmd:twinmatch} {hline 2}}Policy-twin selection by Mahalanobis distance{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:twinmatch} {varlist} {ifin}{cmd:,} {cmd:id(}{varname}{cmd:)}
{cmd:treated(}{it:unit}{cmd:)} [{it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{syntab :Required}
{synopt :{cmd:id(}{varname}{cmd:)}}unit identifier; string or numeric, must be unique{p_end}
{synopt :{cmd:treated(}{it:unit}{cmd:)}}id value of the treated unit (the unit to be matched){p_end}

{syntab :Optional}
{synopt :{cmd:ntwins(}{it:#}{cmd:)}}number of nearest twins to report; default is {cmd:ntwins(3)}{p_end}
{synopt :{cmd:generate(}{it:newvar}{cmd:)}}store every unit's distance to the treated unit{p_end}
{synopt :{cmd:standardize}}z-score the covariates and use Euclidean distance on
the z-scores instead of the full Mahalanobis metric{p_end}
{synoptline}
{p 4 6 2}{it:varlist} contains the numeric matching covariates.
Observations with a missing covariate or a blank id are excluded.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:twinmatch} finds the comparison units that most resemble one treated
unit on a set of covariates {hline 2} its "policy twins."  It computes the
Mahalanobis distance from every unit to the treated unit, ranks the
comparison units from nearest to farthest, and reports the {cmd:ntwins()}
closest.  Ties are broken by data order, so results are exactly reproducible
without a seed.

{pstd}
The command is a small-{it:N} comparison-group helper for program evaluation:
when one district, county, campus, or hospital adopts a policy, it selects
the handful of untreated units against which before/after trajectories can
be compared.  It is a conceptual kin of donor selection in synthetic control
designs (see Cattaneo et al. 2024 and synthetic control methods generally):
it selects comparison units, but does not weight them or estimate treatment
effects.


{marker options}{...}
{title:Options}

{phang}{cmd:id(}{varname}{cmd:)} names the unit identifier.  A numeric id
is converted to its string form for matching and reporting, so
{cmd:treated("5")} matches the numeric id 5.  The treated value must
identify exactly one observation in the estimation sample.{p_end}

{phang}{cmd:treated(}{it:unit}{cmd:)} gives the id value of the treated unit.
Values are matched after trimming leading and trailing spaces.{p_end}

{phang}{cmd:ntwins(}{it:#}{cmd:)} sets how many nearest comparison units to
report and store; it must be at least 1 and no larger than the number of
comparison units in the sample.{p_end}

{phang}{cmd:generate(}{it:newvar}{cmd:)} creates a {cmd:double} variable
holding each in-sample unit's distance to the treated unit (0 for the
treated unit itself).  This is useful for plotting the full distance
distribution or for choosing a caliper.{p_end}

{phang}{cmd:standardize} replaces the full Mahalanobis metric with Euclidean
distance on z-scored covariates (equivalently, Mahalanobis with a diagonal
covariance matrix).  Because full Mahalanobis distance also adjusts for the
correlations among covariates, a pair of highly correlated covariates is
partially discounted; {cmd:standardize} weights every covariate equally on
the standard-deviation scale, which is often easier to defend when covariate
scales differ wildly and the correlation structure is noisy in small
samples.{p_end}


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
{bf:What twinmatch does not do.}  It does not weight the selected twins,
estimate effects, or test balance.  Treat the twin list as the starting
point for a comparative case study or a donor pool for synthetic control,
not as an estimator.


{marker examples}{...}
{title:Examples}

{pstd}Three policy twins for one unit, on three covariates:{p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. twinmatch mpg price weight, id(make) treated("Volvo 260")}{p_end}

{pstd}Five twins, storing every unit's distance for inspection:{p_end}
{phang2}{cmd:. twinmatch mpg price weight, id(make) treated("Volvo 260") ntwins(5) generate(dist260)}{p_end}
{phang2}{cmd:. sort dist260}{p_end}
{phang2}{cmd:. list make dist260 in 1/10}{p_end}

{pstd}Z-scored (diagonal) metric when scales differ wildly:{p_end}
{phang2}{cmd:. twinmatch mpg price weight, id(make) treated("Volvo 260") standardize}{p_end}

{pstd}Restrict the donor pool with {cmd:if}, for example to foreign cars:{p_end}
{phang2}{cmd:. twinmatch mpg price weight if foreign | make == "Volvo 260", id(make) treated("Volvo 260")}{p_end}

{pstd}Retrieve the twins programmatically:{p_end}
{phang2}{cmd:. twinmatch mpg price weight, id(make) treated("Volvo 260")}{p_end}
{phang2}{cmd:. display `"`r(twins)'"'}{p_end}
{phang2}{cmd:. local first : word 1 of `r(twins)'}{p_end}
{phang2}{cmd:. display `"nearest twin: `first'"'}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:twinmatch} stores in {cmd:r()}:{p_end}
{synoptset 14 tabbed}{...}
{synopt :{cmd:r(N)}}number of observations in the estimation sample{p_end}
{synopt :{cmd:r(k)}}number of twins reported{p_end}
{synopt :{cmd:r(twins)}}ids of the {cmd:r(k)} nearest twins, nearest first;
space-separated, each id wrapped in compound quotes so ids containing spaces
survive (extract with {cmd:local x : word # of `r(twins)'}){p_end}
{synopt :{cmd:r(dists)}}space-separated distances aligned with {cmd:r(twins)}{p_end}
{synopt :{cmd:r(treated)}}id of the treated unit{p_end}
{synopt :{cmd:r(metric)}}{cmd:mahalanobis} or {cmd:standardized}{p_end}
{p2colreset}{...}


{title:References}

{pstd}
Cattaneo, M. D., Y. Feng, F. Palomba, and R. Titiunik.  2024.
Uncertainty quantification in synthetic controls with staggered treatment
adoption.  Working paper; see also their {it:scpi} software.{p_end}

{pstd}
Abadie, A.  2021.  Using synthetic controls: Feasibility, data requirements,
and methodological aspects.  {it:Journal of Economic Literature} 59(2):
391-425.{p_end}


{title:Author}

{pstd}
Eric A. Booth, Sr Researcher, Texas 2036 (eric.a.booth@gmail.com), 2026.  MIT-licensed.{p_end}
