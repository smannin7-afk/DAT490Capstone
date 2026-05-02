
suppressPackageStartupMessages({
  library(lme4)
  library(broom.mixed)
  library(readr)
  library(dplyr)
})

out_dir <- "outputs/multilevel"
df <- read_csv(file.path(out_dir, "multilevel_model_input.csv"), show_col_types = FALSE)

df <- df %>%
  mutate(
    target_approved = as.integer(target_approved),
    state_code = factor(state_code),
    loan_purpose = factor(loan_purpose),
    loan_type = factor(loan_type),
    applicant_sex = factor(applicant_sex),
    occupancy_type = factor(occupancy_type),
    lien_status = factor(lien_status),
    applicant_age = factor(applicant_age)
  )

if ("Purchase" %in% levels(df$loan_purpose)) df$loan_purpose <- relevel(df$loan_purpose, ref = "Purchase")
if ("Conventional" %in% levels(df$loan_type)) df$loan_type <- relevel(df$loan_type, ref = "Conventional")
if ("Joint" %in% levels(df$applicant_sex)) df$applicant_sex <- relevel(df$applicant_sex, ref = "Joint")

ctrl <- glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 200000))

null_model <- glmer(
  target_approved ~ 1 + (1 | state_code),
  data = df,
  family = binomial(link = "logit"),
  control = ctrl,
  nAGQ = 0
)

full_model <- glmer(
  target_approved ~ state_median_income_z + lender_concentration_hhi_z +
    dti_ordinal + log_loan_amount + log_income + loan_to_value_ratio +
    ltv_missing + dti_missing + loan_purpose + loan_type + applicant_sex +
    occupancy_type + lien_status + applicant_age + (1 | state_code),
  data = df,
  family = binomial(link = "logit"),
  control = ctrl,
  nAGQ = 0
)

slope_model <- glmer(
  target_approved ~ state_median_income_z + lender_concentration_hhi_z +
    dti_ordinal + log_loan_amount + log_income + loan_to_value_ratio +
    ltv_missing + dti_missing + loan_purpose + loan_type + applicant_sex +
    occupancy_type + lien_status + applicant_age + (1 + dti_ordinal | state_code),
  data = df,
  family = binomial(link = "logit"),
  control = ctrl,
  nAGQ = 0
)

null_tau2 <- as.numeric(VarCorr(null_model)$state_code[1, 1])
null_icc <- null_tau2 / (null_tau2 + (pi^2 / 3))
full_tau2 <- as.numeric(VarCorr(full_model)$state_code[1, 1])
full_icc <- full_tau2 / (full_tau2 + (pi^2 / 3))

null_table <- tibble(
  parameter = c("Grand intercept", "Between-state variance", "Individual-level variance", "Intraclass Correlation", "Number of states", "Number of applications", "Log-likelihood"),
  estimate = c(fixef(null_model)[1], null_tau2, pi^2 / 3, null_icc, length(unique(df$state_code)), nrow(df), as.numeric(logLik(null_model)))
)

full_fixed <- tidy(full_model, effects = "fixed")
full_var <- tibble(term = c("Residual between-state variance", "Residual ICC"), estimate = c(full_tau2, full_icc), std.error = c(NA, NA), statistic = c(NA, NA), p.value = c(NA, NA))
full_table <- bind_rows(full_fixed, full_var)

lrt <- anova(full_model, slope_model)
slope_summary <- tibble(
  statistic = c("lrt_chisq", "lrt_df", "lrt_p", "full_tau2", "full_icc"),
  value = c(lrt$Chisq[2], lrt$`Chi Df`[2], lrt$`Pr(>Chisq)`[2], full_tau2, full_icc)
)
slope_terms <- tidy(slope_model, effects = "fixed") %>% filter(term == "state_median_income_z:dti_ordinal" | term == "dti_ordinal")

ran <- ranef(full_model, condVar = TRUE)$state_code
post_var <- attr(ran, "postVar")
eb <- tibble(
  state_code = rownames(ran),
  eb_residual = ran[, "(Intercept)"],
  se = sqrt(as.numeric(post_var[1, 1, ])),
  ci_low = eb_residual - 1.96 * se,
  ci_high = eb_residual + 1.96 * se
)

write_csv(null_table, file.path(out_dir, "table1_null_model.csv"))
write_csv(full_table, file.path(out_dir, "table2_full_random_intercept.csv"))
write_csv(slope_summary, file.path(out_dir, "random_slope_lrt_summary.csv"))
write_csv(slope_terms, file.path(out_dir, "random_slope_fixed_terms.csv"))
write_csv(eb, file.path(out_dir, "figure9_eb_residuals.csv"))
saveRDS(null_model, file.path(out_dir, "null_model.rds"))
saveRDS(full_model, file.path(out_dir, "full_random_intercept_model.rds"))
saveRDS(slope_model, file.path(out_dir, "random_slope_model.rds"))
