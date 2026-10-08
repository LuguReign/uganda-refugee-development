# Analysis plan and decision log

## Confirmatory reproduction target

Reproduce the eight public-goods outcomes in SI Table S16 with the archive's data, controls, binary treatment, fixed effects, distance restriction, and cluster inference. Success is agreement in coefficient and standard-error rounding to three decimals and exact sample sizes. Full-paper reproduction is outside this target.

## Exploratory extension

Selected after inspecting the archive and before fitting extension models, on 8 October 2026. This local plan is not external preregistration.

- Moderator: 2001 raw public primary-school access, at/below vs above median across baseline-control-complete parishes, before radius restriction.
- Primary endpoint: archive-standardized public primary schools; comparator: secondary schools.
- Contrast: change in continuous exposure slope in 2016/2020 relative to 2011.
- Specification: original continuous model plus group-by-wave and exposure-by-group-by-wave terms.
- Inference: directly estimate the lower-minus-higher group contrast with covariance-aware standard errors.
- Robustness: 100/150/200km radius and raw outcome units.
- No adjustment for exploratory multiple testing; no causal mechanism claim.

## Decisions discovered during reproduction

1. Standardize transformed presence before dropping missing baseline covariates or applying a radius.
2. Match S16's quantiles from standardized Nearest, even when classifying Nearest + 20. This is a reproduction choice, not an endorsement of binning.
3. Preserve seven out-of-range bin exclusions.
4. Distinguish `min_distance` for presence construction from `min_distance_01` for sampling.
5. Remove fixed effects nested in parish clusters from the small-sample parameter penalty to match reghdfe behavior.
6. Report year-standardized primary-school units separately from raw schools-per-thousand-child units.
7. Retain uncertain and negative findings, including the continuous index contrast; do not select only favorable outcomes.

## Open work

Full original R execution; primary-record/geocoding audit; continuous-treatment identification diagnostics; overlap/influence checks; spatial inference; common-scale outcome reconstruction; public-opinion replication.
