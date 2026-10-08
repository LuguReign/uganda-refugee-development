# Refugee Hosting and Local Development in Uganda

An independent replication and exploratory extension of selected public-service analyses from **Zhou, Grossman, and Ge (2023)**. Prepared for Nicholas Reign Lugu as an economics and political-economy research portfolio. No affiliation or endorsement by the source authors or Dartmouth is implied.

## Results

- Real data: **26,890 parish-wave observations, 5,378 parishes, five waves (2001–2020)**.
- **All eight S16 coefficients, standard errors, and sample sizes match** at published precision.
- Geographic linkage uses the original parish identifier, with all retained analysis keys found.
- A baseline-access extension and raw-unit/radius sensitivity analyses show that conclusions depend on the outcome scale and estimand.
- Five tests cover panel integrity, external numerical reconciliation, absorption, explicit dummy OLS agreement, and covariance-aware contrasts.

The standardized primary-school heterogeneity contrast in 2020 is **−0.027 (95% CI −0.058 to 0.003)**. A raw-unit check gives **−0.120 schools per thousand children (95% CI −0.217 to −0.024)**. These are different estimands. The project does not claim definitive heterogeneous causal effects or uniform improvement in every service.

## Read and explore

- `reports/Uganda_Refugee_Hosting_Research_Memo.pdf`: eight-page research memo.
- `docs/index.html`: self-contained interactive results explorer; open directly in a browser.
- `reports/Uganda_Research_Seminar.pptx`: editable seminar presentation.
- `teaching/fixed_effects_and_contrasts.ipynb`: teaching notebook.
- `output/s16_reconciliation.csv`: publication benchmark and calculated estimates.

## Reproduce offline

Requires Python 3.10+; checked with Python 3.12. The checked versions appear in `output/run_manifest.json`.

```bash
python -m pip install -r requirements.txt
python run_analysis.py
python -m unittest discover -s tests -v
python build_outputs.py
```

Compressed real source inputs are included. The pipeline reads `.csv.gz` if the original `.csv` is absent. No synthetic data substitute for the Uganda records. Numerical analysis requires NumPy, pandas, and SciPy. Matplotlib and ReportLab produce the figures and memo. Rebuilding the PPTX separately uses OpenAI Artifact Tool; the exported presentation is included for ordinary PowerPoint use.

## Structure

| Folder | Purpose |
|---|---|
| `data/raw/` | Immutable real panel and original geography |
| `data/source/` | Unmodified archived author code and readme |
| `src/` | Original transparent absorbed OLS implementation |
| `output/` | Machine-readable estimates, audit, provenance |
| `reports/` | Research memo and seminar presentation |
| `docs/` | Offline explorer and figures |
| `teaching/` | Worked learning notebook |
| `tests/` | Statistical and data checks |

## Identification and scope

The continuous model uses parish and region-wave effects, time-varying transformed refugee presence, and thirteen baseline covariates interacted with waves. Inference clusters by parish, with nested-effect small-sample correction. Post-2011 contrasts describe changes in exposure slopes. They are not automatically average treatment effects on a fixed treated group.

The source code bins Nearest + 20 presence using standardized Nearest quantiles for S16. Replication preserves that convention and its seven treatment exclusions. The 150km sample cutoff uses **settlements active in 2001**, while the exposure construction uses current settlement distance. Primary-school standardized outcomes have year-specific scaling. These implementation choices matter and are documented in the memo.

Completed scope: selected public-goods specifications and one exploratory school-access extension. Outside scope: public-opinion replication, health-utilization replication, causal aid mechanisms, complete execution of original R/knitr files, upstream primary-record reconstruction, and spatially robust inference.

## Attribution and AI disclosure

Zhou, Yang-Yang, Guy Grossman, and Shuning Ge. 2023. “Inclusive refugee-hosting can improve local development and prevent public backlash.” *World Development* 166: 106203. https://doi.org/10.1016/j.worlddev.2023.106203.

Replication archive, Harvard Dataverse V1: https://doi.org/10.7910/DVN/TXSZDC. The archive displays CC0 1.0 terms. Data and archived author code retain their provenance and attribution; this project's code license does not replace third-party terms.

OpenAI Codex assisted with source inspection, programming, drafting, and checking. Estimates come from executed code. Claude Code use and independent human peer review are not claimed. Review the material before using it in an application or describing personal contributions.
