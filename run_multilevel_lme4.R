suppressPackageStartupMessages({
  library(lme4)
  library(readr)
  library(dplyr)
  library(broom.mixed)
})

set.seed(490)

in_path <- "outputs/multilevel/multilevel_model_input.csv"
out_dir <- "outputs/multilevel"

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(in_path)) {
  stop(
    "Missing input file: ", in_path,
    "\nRun multilevel/01_multilevel_analysis.ipynb first to create this intermediate CSV."
  )
}

df <- read_csv(in_path, show_col_types = FALSE)

to_numeric_safe <- function(x) {
  as.numeric(gsub("[%$,]", "", trimws(as.character(x))))
}

safe_relevel <- function(x, refs) {
  f <- factor(x)
  for (ref in refs) {
    if (ref %in% levels(f)) {
      return(relevel(f, ref = ref))
    }
  }
  f
}

if (!"state_median_income_z" %in% names(df) && "state_median_income" %in% names(df)) {
  df$state_median_income_z <- as.numeric(scale(to_numeric_safe(df$state_median_income)))
}

if (!"lender_concentration_hhi_z" %in% names(df) && "lender_concentration_hhi" %in% names(df)) {
  df$lender_concentration_hhi_z <- as.numeric(scale(to_numeric_safe(df$lender_concentration_hhi)))
}

if (!"dti_ordinal" %in% names(df)) {
  if (!"debt_to_income_ratio" %in% names(df)) {
    stop("Input must contain either dti_ordinal or debt_to_income_ratio.")
  }

  dti_text <- trimws(as.character(df$debt_to_income_ratio))
  df$dti_ordinal <- dplyr::case_when(
    dti_text %in% c("<20%", "<20") ~ 1,
    grepl("20", dti_text) & grepl("30", dti_text) ~ 2,
    grepl("30", dti_text) & grepl("36", dti_text) ~ 3,
    grepl("36", dti_text) & grepl("50", dti_text) ~ 4,
    grepl("50", dti_text) & grepl("60", dti_text) ~ 5,
    dti_text %in% c(">60%", ">60") ~ 6,
    TRUE ~ suppressWarnings(as.numeric(dti_text))
  )
}

if (!"log_loan_amount" %in% names(df)) {
  if (!"loan_amount" %in% names(df)) {
    stop("Input must contain loan_amount or log_loan_amount.")
  }
  df$loan_amount <- to_numeric_safe(df$loan_amount)
  df$log_loan_amount <- log1p(df$loan_amount)
}

if (!"log_income" %in% names(df)) {
  if (!"income" %in% names(df)) {
    stop("Input must contain income or log_income.")
  }
  df$income <- to_numeric_safe(df$income)
  df$log_income <- log1p(pmax(df$income, 0))
}

if (!"ltv_ratio" %in% names(df)) {
  if (!"loan_to_value_ratio" %in% names(df)) {
    stop("Input must contain loan_to_value_ratio or ltv_ratio.")
  }
  df$ltv_ratio <- to_numeric_safe(df$loan_to_value_ratio)
}

if (!"ltv_missing" %in% names(df)) {
  df$ltv_missing <- as.integer(is.na(df$ltv_ratio))
}

df$ltv_ratio[is.na(df$ltv_ratio)] <- median(df$ltv_ratio, na.rm = TRUE)

required_columns <- c(
  "target",
  "state_code",
  "state_median_income_z",
  "lender_concentration_hhi_z",
  "dti_ordinal",
  "log_loan_amount",
  "log_income",
  "ltv_ratio",
  "loan_purpose",
  "loan_type",
  "applicant_sex",
  "ltv_missing"
)

missing_columns <- setdiff(required_columns, names(df))
if (length(missing_columns) > 0) {
  stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
}

df <- df %>%
  mutate(
    target = as.integer(target),
    state_code = factor(state_code),
    loan_purpose = safe_relevel(loan_purpose, c("Purchase", "Home purchase", "1")),
    loan_type = safe_relevel(loan_type, c("Conventional", "1")),
    applicant_sex = safe_relevel(applicant_sex, c("Joint", "joint")),
    dti_ordinal = as.numeric(dti_ordinal),
    log_loan_amount = as.numeric(log_loan_amount),
    log_income = as.numeric(log_income),
    ltv_ratio = as.numeric(ltv_ratio),
    state_median_income_z = as.numeric(state_median_income_z),
    lender_concentration_hhi_z = as.numeric(lender_concentration_hhi_z),
    ltv_missing = as.integer(ltv_missing)
  )

optional_terms <- c()

if ("lien_status" %in% names(df)) {
  df$lien_status <- factor(df$lien_status)
  optional_terms <- c(optional_terms, "lien_status")
}

if ("occupancy_type" %in% names(df)) {
  df$occupancy_type <- factor(df$occupancy_type)
  optional_terms <- c(optional_terms, "occupancy_type")
}

if ("applicant_age" %in% names(df)) {
  df$applicant_age <- factor(df$applicant_age)
  optional_terms <- c(optional_terms, "applicant_age")
}

fixed_terms <- c(
  "state_median_income_z",
  "lender_concentration_hhi_z",
  "dti_ordinal",
  "log_loan_amount",
  "log_income",
  "ltv_ratio",
  "loan_purpose",
  "loan_type",
  "applicant_sex",
  "ltv_missing",
  optional_terms
)

model_columns <- unique(c("target", "state_code", fixed_terms))
model_data <- df %>%
  select(all_of(model_columns)) %>%
  filter(complete.cases(.))

if (length(unique(model_data$target)) != 2) {
  stop("The target column must contain two classes after filtering.")
}

base_rhs <- paste(fixed_terms, collapse = " + ")

null_formula <- as.formula("target ~ 1 + (1 | state_code)")
full_formula <- as.formula(paste("target ~", base_rhs, "+ (1 | state_code)"))
slope_formula <- as.formula(paste("target ~", base_rhs, "+ (1 + dti_ordinal | state_code)"))
interaction_formula <- as.formula(paste(
  "target ~",
  base_rhs,
  "+ state_median_income_z:dti_ordinal + (1 + dti_ordinal | state_code)"
))

glmer_control <- glmerControl(
  optimizer = "bobyqa",
  optCtrl = list(maxfun = 200000)
)

null_model <- glmer(
  null_formula,
  data = model_data,
  family = binomial(link = "logit"),
  control = glmer_control,
  nAGQ = 1
)

full_model <- glmer(
  full_formula,
  data = model_data,
  family = binomial(link = "logit"),
  control = glmer_control,
  nAGQ = 1
)

slope_model_no_interaction <- glmer(
  slope_formula,
  data = model_data,
  family = binomial(link = "logit"),
  control = glmer_control,
  nAGQ = 1
)

interaction_model <- glmer(
  interaction_formula,
  data = model_data,
  family = binomial(link = "logit"),
  control = glmer_control,
  nAGQ = 1
)

latent_logit_variance <- pi^2 / 3
null_tau2 <- as.numeric(VarCorr(null_model)$state_code[1, 1])
null_icc <- null_tau2 / (null_tau2 + latent_logit_variance)

table1 <- tibble(
  parameter = c(
    "Grand intercept (gamma_00)",
    "Between-state variance (tau2)",
    "Individual-level variance (pi^2/3)",
    "Intraclass Correlation (ICC)",
    "Number of states",
    "Number of applications",
    "Log-likelihood"
  ),
  estimate = c(
    fixef(null_model)[["(Intercept)"]],
    null_tau2,
    latent_logit_variance,
    null_icc,
    nlevels(model_data$state_code),
    nrow(model_data),
    as.numeric(logLik(null_model))
  )
)

write_csv(table1, file.path(out_dir, "table1_null_model.csv"))

full_fixed <- tidy(full_model, effects = "fixed") %>%
  select(term, estimate, std.error, statistic, p.value)

full_tau2 <- as.numeric(VarCorr(full_model)$state_code[1, 1])

r2_marginal <- NA_real_
r2_conditional <- NA_real_

if (requireNamespace("performance", quietly = TRUE)) {
  r2_out <- suppressWarnings(performance::r2_nakagawa(full_model))
  r2_marginal <- as.numeric(r2_out$R2_marginal)
  r2_conditional <- as.numeric(r2_out$R2_conditional)
}

full_variance <- tibble(
  term = c(
    "Residual between-state variance (tau2)",
    "Marginal R2_m",
    "Conditional R2_c"
  ),
  estimate = c(full_tau2, r2_marginal, r2_conditional),
  std.error = NA_real_,
  statistic = NA_real_,
  p.value = NA_real_
)

table2 <- bind_rows(full_fixed, full_variance)

write_csv(table2, file.path(out_dir, "table2_full_random_intercept.csv"))

lrt_slope <- anova(full_model, slope_model_no_interaction, test = "Chisq")

random_slope_lrt_summary <- tibble(
  comparison = "full_random_intercept_vs_random_slope_no_interaction",
  logLik_full_random_intercept = as.numeric(logLik(full_model)),
  logLik_random_slope = as.numeric(logLik(slope_model_no_interaction)),
  df_full_random_intercept = attr(logLik(full_model), "df"),
  df_random_slope = attr(logLik(slope_model_no_interaction), "df"),
  df_difference = attr(logLik(slope_model_no_interaction), "df") - attr(logLik(full_model), "df"),
  chisq = lrt_slope$Chisq[2],
  p_value = lrt_slope$`Pr(>Chisq)`[2]
)

write_csv(random_slope_lrt_summary, file.path(out_dir, "random_slope_lrt_summary.csv"))

slope_vc <- as.data.frame(VarCorr(slope_model_no_interaction))

tau00 <- slope_vc %>%
  filter(grp == "state_code", var1 == "(Intercept)", is.na(var2)) %>%
  pull(vcov)

tau11 <- slope_vc %>%
  filter(grp == "state_code", var1 == "dti_ordinal", is.na(var2)) %>%
  pull(vcov)

tau01 <- slope_vc %>%
  filter(grp == "state_code", var1 == "(Intercept)", var2 == "dti_ordinal") %>%
  pull(vcov)

random_slope_variance <- tibble(
  parameter = c("tau00_intercept_variance", "tau11_dti_slope_variance", "tau01_intercept_slope_covariance"),
  estimate = c(tau00[1], tau11[1], tau01[1])
)

write_csv(random_slope_variance, file.path(out_dir, "random_slope_variance_components.csv"))

interaction_fixed <- tidy(interaction_model, effects = "fixed") %>%
  filter(grepl("state_median_income_z:dti_ordinal|dti_ordinal:state_median_income_z", term)) %>%
  select(term, estimate, std.error, statistic, p.value)

write_csv(interaction_fixed, file.path(out_dir, "random_slope_fixed_terms.csv"))

eb <- ranef(full_model, condVar = TRUE)$state_code
eb_df <- tibble(
  state_code = rownames(eb),
  eb_residual = eb[, "(Intercept)"]
) %>%
  arrange(eb_residual)

write_csv(eb_df, file.path(out_dir, "figure9_eb_residuals.csv"))

convergence_summary <- tibble(
  model = c("null_model", "full_model", "slope_model_no_interaction", "interaction_model"),
  log_likelihood = c(
    as.numeric(logLik(null_model)),
    as.numeric(logLik(full_model)),
    as.numeric(logLik(slope_model_no_interaction)),
    as.numeric(logLik(interaction_model))
  ),
  optimizer = "bobyqa",
  nAGQ = 1,
  singular = c(
    isSingular(null_model),
    isSingular(full_model),
    isSingular(slope_model_no_interaction),
    isSingular(interaction_model)
  )
)

write_csv(convergence_summary, file.path(out_dir, "multilevel_convergence_summary.csv"))

cat("Finished multilevel reproducibility run.\n")
cat("Outputs written to:", out_dir, "\n")
cat("Null ICC:", round(null_icc, 6), "\n")
cat("Full residual ICC:", round(full_tau2 / (full_tau2 + latent_logit_variance), 6), "\n")
cat("Random-slope LRT df difference:", random_slope_lrt_summary$df_difference, "\n")
