# DAT490Capstone Reproducibility Files

This repository contains reproducibility files for the DAT 490 HMDA mortgage approval prediction capstone.

## Expected data layout

Do not commit the raw 2023 HMDA LAR file because it is too large. Place the raw file here:

```text
data/raw/2023_public_lar_csv.csv
```

The cleaning script creates the cleaned analytical dataset here:

```text
data/processed/hmda_2023_analytical.parquet
```

The multilevel notebook also needs state-level covariates if they are not already included in the analytical dataset:

```text
data/external/state_covariates.csv
```

Expected columns in `state_covariates.csv`:

```text
state_code,state_median_income,lender_concentration_hhi
```

The evaluation notebook expects held-out prediction probabilities here:

```text
outputs/predictions/heldout_predictions.csv
```

`outputs/multilevel/multilevel_model_input.csv` is an intermediate file created by `multilevel/01_multilevel_analysis.ipynb` from the cleaned parquet and state covariates. Do not commit it unless your instructor specifically asks for generated intermediate files.

## Notebook map

| Paper artifact | Notebook or script | Output |
|---|---|---|
| Table 1 null multilevel model | `multilevel/01_multilevel_analysis.ipynb` + `multilevel/run_multilevel_lme4.R` | `outputs/multilevel/table1_null_model.csv` |
| Table 2 full random-intercept model | `multilevel/01_multilevel_analysis.ipynb` + `multilevel/run_multilevel_lme4.R` | `outputs/multilevel/table2_full_random_intercept.csv` |
| Random-slope model comparison | `multilevel/01_multilevel_analysis.ipynb` + `multilevel/run_multilevel_lme4.R` | `outputs/multilevel/random_slope_lrt_summary.csv` |
| Cross-level interaction term | `multilevel/01_multilevel_analysis.ipynb` + `multilevel/run_multilevel_lme4.R` | `outputs/multilevel/random_slope_fixed_terms.csv` |
| Figure 9 EB residuals | `multilevel/01_multilevel_analysis.ipynb` + `multilevel/run_multilevel_lme4.R` | `outputs/multilevel/figure9_eb_residuals.csv` |
| Table 3 HMDA analytical dataset structure | `data/prepare_hmda_dataset.py` | `data/processed/hmda_2023_analytical.parquet` |
| Table 4 held-out model results | `evaluation/01_evaluation_model_comparison.ipynb` | `outputs/evaluation/table4_heldout_metrics.csv` |
| Table 4 bootstrap intervals | `evaluation/01_evaluation_model_comparison.ipynb` | `outputs/evaluation/table4_bootstrap_intervals.csv` |
| Figure 10 model comparison | `evaluation/01_evaluation_model_comparison.ipynb` | `outputs/evaluation/fig10_model_comparison_recreated.png` |
| Table 5 fairness screening | `evaluation/01_evaluation_model_comparison.ipynb` | `outputs/evaluation/table5_fairness_screening_with_ztests.csv` |
| Equalized-odds follow-up | `evaluation/01_evaluation_model_comparison.ipynb` | `outputs/evaluation/equalized_odds_screening_soft_voting.csv` |

## Running order

1. Download the 2023 HMDA Loan/Application Records (LAR) CSV from the CFPB/FFIEC HMDA publication site.
2. Place the raw file at:

```text
data/raw/2023_public_lar_csv.csv
```

3. Run the data preparation script from the repository root:

```bash
python data/prepare_hmda_dataset.py
```

4. Confirm the cleaned analytical dataset exists:

```text
data/processed/hmda_2023_analytical.parquet
```

5. Run the multilevel notebook from the repository root:

```text
multilevel/01_multilevel_analysis.ipynb
```

6. The multilevel notebook creates:

```text
outputs/multilevel/multilevel_model_input.csv
```

7. Run the R model script from the repository root:

```bash
Rscript multilevel/run_multilevel_lme4.R
```

8. Confirm held-out predictions exist:

```text
outputs/predictions/heldout_predictions.csv
```

9. Run the evaluation notebook from the repository root:

```text
evaluation/01_evaluation_model_comparison.ipynb
```

## Reproducibility settings

| Setting | Value |
|---|---|
| Python version | 3.11.x |
| R version | 4.2 or newer |
| Random seed | 42 |
| Train/test split | Stratified 80/20 |
| Evaluation target | Denied-class probabilities |
| Bootstrap iterations | 1,000 |

## Python dependencies

Install the Python requirements:

```bash
pip install -r requirements.txt
```

## R dependencies

Install the R requirements:

```r
install.packages(c("lme4", "broom.mixed", "readr", "dplyr", "performance"))
```

## Verification checklist

Before submission, verify that the generated outputs match the final report:

```text
outputs/multilevel/table1_null_model.csv
outputs/multilevel/table2_full_random_intercept.csv
outputs/multilevel/random_slope_lrt_summary.csv
outputs/multilevel/random_slope_fixed_terms.csv
outputs/multilevel/figure9_eb_residuals.csv
outputs/evaluation/table4_heldout_metrics.csv
outputs/evaluation/table4_bootstrap_intervals.csv
outputs/evaluation/fig10_model_comparison_recreated.png
outputs/evaluation/table5_fairness_screening_with_ztests.csv
outputs/evaluation/equalized_odds_screening_soft_voting.csv
```

The random-slope LRT output is based on the random-slope model without the fixed cross-level interaction so that the model comparison has a two-parameter difference. The cross-level interaction estimate is written separately from the interaction model to `random_slope_fixed_terms.csv`.

## Final submission tag

After outputs are verified:

```bash
git tag v1.0-final-submission
git push origin v1.0-final-submission
```
