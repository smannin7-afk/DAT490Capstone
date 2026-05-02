# DAT490Capstone Reproducibility Files

This folder contains reproducibility files for the DAT 490 HMDA mortgage approval prediction capstone.

## Expected data layout

Do not commit the raw 2023 HMDA file because it is too large. Place the cleaned analytical dataset here:

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

## Notebook map

| Paper artifact | Notebook | Output |
|---|---|---|
| Table 1 null multilevel model | `multilevel/01_multilevel_analysis.ipynb` | `outputs/multilevel/table1_null_model.csv` |
| Table 2 full random-intercept model | `multilevel/01_multilevel_analysis.ipynb` | `outputs/multilevel/table2_full_random_intercept.csv` |
| Random-slope model comparison | `multilevel/01_multilevel_analysis.ipynb` | `outputs/multilevel/random_slope_lrt_summary.csv` |
| Figure 9 EB residuals | `multilevel/01_multilevel_analysis.ipynb` | `outputs/multilevel/figure9_eb_residuals.csv` |
| Table 4 held-out model results | `evaluation/01_evaluation_model_comparison.ipynb` | `outputs/evaluation/table4_heldout_metrics.csv` |
| Table 4 bootstrap intervals | `evaluation/01_evaluation_model_comparison.ipynb` | `outputs/evaluation/table4_bootstrap_intervals.csv` |
| Figure 10 model comparison | `evaluation/01_evaluation_model_comparison.ipynb` | `outputs/evaluation/fig10_model_comparison_recreated.png` |
| Table 5 fairness screening | `evaluation/01_evaluation_model_comparison.ipynb` | `outputs/evaluation/table5_fairness_screening_with_ztests.csv` |
| Equalized-odds follow-up | `evaluation/01_evaluation_model_comparison.ipynb` | `outputs/evaluation/equalized_odds_screening_soft_voting.csv` |

## Running order

1. Confirm the cleaned analytical dataset exists in `data/processed/`.
2. Run `multilevel/01_multilevel_analysis.ipynb` from the repository root or from the `multilevel/` folder.
3. Confirm held-out predictions exist in `outputs/predictions/heldout_predictions.csv`.
4. Run `evaluation/01_evaluation_model_comparison.ipynb` from the repository root or from the `evaluation/` folder.

## Dependencies

Install the Python requirements:

```bash
pip install -r requirements.txt
```

For the multilevel model, install R packages:

```r
install.packages(c("lme4", "broom.mixed", "readr", "dplyr"))
```

## Final submission tag

After outputs are verified:

```bash
git tag v1.0-final-submission
git push origin v1.0-final-submission
```
