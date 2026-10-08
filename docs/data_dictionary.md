# Analysis variables

| Variable | Interpretation | Treatment |
|---|---|---|
| parish_id | Original parish identifier | Parish-wave key; geographic join to P_02_ID |
| year | 2001, 2006, 2011, 2016, 2020 | Wave indicators, not annual data |
| region / district | Original geography | Region-wave effects; retained district labels |
| min_distance | Current nearest-settlement distance, km | Determines Nearest + 20 construction |
| min_distance_01 | Distance to settlement active in 2001, km | Sample radius restriction |
| nearest_exposure | Released nearest-settlement exposure | asinh then full-panel z-score |
| sum_exposure_20km_rad | Released aggregate nearby exposure | Used when current nearest distance <20km |
| presence | Reconstructed Nearest + 20 exposure | Full-panel standardization before exclusions |
| binary_presence | Archived S16 bin | Cutoffs from complete-case Nearest z-score quantiles |
| s16_treatment | Post-wave exposure bin, zero in pre-waves | Year-varying binary regressor |
| low_access | 2001 raw primary access <= complete-case median | Fixed parish moderator |
| public_primary_schools_per_thousand_kids_parish_level | Released raw public-primary access | Schools per thousand primary-age children |
| public_primary_schools_per_thousand_kids_parish_level_standardized | Released primary access standardized within wave | Relative within-wave units |
| public_per_thousand_kid / _standardized | Released secondary school access | Preserve archive scaling |
| road_density_standardized | Released road measure | Only 2011, 2016, 2020 available |
| minmax_count_pop_hcii_standardized | Released HC2 access | 2001–2016, unavailable 2020 |
| multiply4_minmax_hciii / hciv / hcv_standardized | Released tier-specific health access | Preserve author transformations; unavailable 2020 |
| PGindex_mean | Released public-goods composite | Archive index units; no redefinition |

The 13 controls appear explicitly in `run_analysis.py`. Raw source definitions remain governed by the authors' code. This project does not reconstruct each upstream transformation. Missing structural waves are left missing.
