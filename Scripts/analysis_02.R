#!/usr/bin/env Rscript

# =============================================================================
# analysis_02.R
# Descriptive and comparison analyses by SAP objectives
#
# What this script does
# ---------------------
# - Loads the cleaned cohort (df_analysis) created by read_clean_01.R.
# - Creates:
#   * Table 1: Baseline demographic/clinical characteristics overall and by
#     second-line regimen anchor (DTG, PI, Other, NA).
#   * Table 2: Overall virological and clinical outcomes, plus follow-up time.
#   * Table 3: Outcomes by regimen anchor (DTG vs PI) for Objective 2.
#   * Table 4: Outcomes by NRTI backbone (TDF vs AZT vs ABC) for Objective 3.
# - Prints key intermediate summaries to the console to help with interpretation.
#
# Inputs
# ------
# - Dataout/df_analysis.rds  (one row per patient; produced by read_clean_01.R)
#
# Outputs (tables for manuscript)
# -------------------------------
# - Dataout/Table1_baseline_by_regimen_anchor.csv
# - Dataout/Table2_overall_outcomes.csv
# - Dataout/Table3_outcomes_by_regimen_anchor.csv
# - Dataout/Table4_outcomes_by_nrti_backbone.csv
#
# These map directly onto: Table 1 = demographics/baseline,
# Table 2 = Objective 1, Table 3 = Objective 2, Table 4 = Objective 3.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(readr)
  library(writexl)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

dataout_dir <- "Dataout"
analysis_rds <- file.path(dataout_dir, "df_analysis.rds")

if (!file.exists(analysis_rds)) {
  stop("df_analysis.rds not found. Run Scripts/read_clean_01.R first.")
}

df <- readRDS(analysis_rds)
cat("Loaded df_analysis from", analysis_rds, "— N =", nrow(df), "\n\n")

# -----------------------------------------------------------------------------
# Helper functions (counts, proportions, medians)
# -----------------------------------------------------------------------------

# Helper: simple count and percent table for a categorical variable
tab_prop <- function(data, var, denom = NULL) {
  v <- enquo(var)
  d <- data %>%
    count(!!v, name = "n") %>%
    mutate(pct = round(100 * n / sum(n), 1))
  if (!is.null(denom)) {
    d <- d %>% mutate(pct = round(100 * n / denom, 1))
  }
  d
}

# Helper: summarise a continuous variable overall (median and IQR)
summarise_cont_overall <- function(data, var) {
  v <- enquo(var)
  data %>%
    summarise(
      n = sum(!is.na(!!v)),
      median = median(!!v, na.rm = TRUE),
      p25 = quantile(!!v, 0.25, na.rm = TRUE),
      p75 = quantile(!!v, 0.75, na.rm = TRUE)
    )
}

# Helper: summarise a continuous variable by grouping variable
summarise_cont_by <- function(data, var, group) {
  v <- enquo(var)
  g <- enquo(group)
  data %>%
    group_by(!!g) %>%
    summarise(
      n = sum(!is.na(!!v)),
      median = median(!!v, na.rm = TRUE),
      p25 = quantile(!!v, 0.25, na.rm = TRUE),
      p75 = quantile(!!v, 0.75, na.rm = TRUE),
      .groups = "drop"
    )
}

# -----------------------------------------------------------------------------
# Derive analysis helpers used across objectives
# - year_t0: calendar year of second-line start (for channeling)
# - period_t0: early vs late period (2018–2020 vs 2021–2024)
# - age_group: Child (<10), Adolescent (10–19), Adult (20–49), Older adult (≥50)
# - first_line_duration_years: time on ART before switch to second-line
# - cd4_cat: <200, 200–349, 350–499, ≥500 cells/mm³
# - bmi_cat: Underweight, Normal, Overweight, Obese (WHO cut-offs)
# -----------------------------------------------------------------------------
df <- df %>%
  mutate(
    year_t0 = as.integer(format(second_line_start_date, "%Y")),
    period_t0 = case_when(
      year_t0 <= 2020 ~ "2018–2020",
      year_t0 >= 2021 ~ "2021–2024",
      TRUE ~ NA_character_
    ),
    age_group = case_when(
      age_second_line < 10 ~ "Child",
      age_second_line < 20 ~ "Adolescent",
      age_second_line < 50 ~ "Adult",
      !is.na(age_second_line) ~ "Older adult",
      TRUE ~ NA_character_
    ),
    first_line_duration_years = as.numeric(second_line_start_date - first_line_start_date) / 365.25,
    cd4_cat = case_when(
      baseline_cd4 < 200 ~ "<200",
      baseline_cd4 < 350 ~ "200–349",
      baseline_cd4 < 500 ~ "350–499",
      baseline_cd4 >= 500 ~ "≥500",
      TRUE ~ NA_character_
    ),
    bmi_cat = case_when(
      bmi < 18.5 ~ "Underweight",
      bmi < 25 ~ "Normal",
      bmi < 30 ~ "Overweight",
      bmi >= 30 ~ "Obese",
      TRUE ~ NA_character_
    ),
    years_since_hiv_diagnosis = if_else(
      !is.na(date_hiv_diagnosis) & !is.na(second_line_start_date),
      as.numeric(second_line_start_date - date_hiv_diagnosis) / 365.25,
      NA_real_
    )
  )

# DTG vs PI cohort for Table 1 and regimen comparisons (exclude Other/NA)
df_reg <- df %>%
  filter(regimen_anchor %in% c("DTG", "PI"))

cat("=== Objective 1: Cohort description and baseline characteristics ===\n\n")

# 1a) Overall cohort size and distribution of exposure groups
#     - Overall N
#     - Regimen anchor (DTG / PI / Other / NA)
#     - NRTI backbone (TDF / AZT / ABC / Other / NA)
#     - Calendar year and period of T0
overall_n <- nrow(df)
cat("Overall N:", overall_n, "\n\n")

reg_anchor_tab <- tab_prop(df, regimen_anchor)
cat("Regimen anchor at T0 (DTG / PI / Other / NA):\n")
print(reg_anchor_tab)
cat("\n")

nrti_tab <- tab_prop(df, nrti_backbone)
cat("NRTI backbone at T0 (TDF / AZT / ABC / Other / NA):\n")
print(nrti_tab)
cat("\n")

year_tab <- tab_prop(df, year_t0)
cat("Calendar year of second-line start (T0):\n")
print(year_tab)
cat("\n")

period_tab <- tab_prop(df %>% filter(!is.na(period_t0)), period_t0)
cat("Calendar period of T0 (for channeling):\n")
print(period_tab)
cat("\n")

# 1b) Table 1: Baseline characteristics by regimen (DTG vs PI only)
#     - Columns: Overall, DTG, PI. Rows: demographics, HIV history, vital signs,
#       adherence, programmatic (per protocol list). Age as continuous and
#       categorical (Child, Adolescent, Adult, Older adult).
#     - Appendix: same structure among adults only; optional brief table for
#       children/adolescents if numbers allow.

# Helpers for DTG vs PI tables (data = df_reg): output columns variable, level, Overall, DTG, PI.
row_cont_dtg_pi <- function(data, var, label) {
  v <- enquo(var)
  overall_s <- summarise_cont_overall(data, !!v)
  by_s <- summarise_cont_by(data, !!v, regimen_anchor)
  row_dtg <- by_s %>% filter(regimen_anchor == "DTG")
  row_pi  <- by_s %>% filter(regimen_anchor == "PI")
  tibble(
    variable = label,
    level = "",
    Overall = sprintf("%.1f (%.1f–%.1f)", overall_s$median, overall_s$p25, overall_s$p75),
    DTG = if (nrow(row_dtg) > 0) sprintf("%.1f (%.1f–%.1f)", row_dtg$median, row_dtg$p25, row_dtg$p75) else NA_character_,
    PI  = if (nrow(row_pi) > 0)  sprintf("%.1f (%.1f–%.1f)", row_pi$median, row_pi$p25, row_pi$p75)  else NA_character_
  )
}
# Categorical section: variable name only on first row; level rows have blank variable (no repetition)
cat_sec_dtg_pi <- function(data, var, var_label) {
  v <- enquo(var)
  v_nm <- as.character(rlang::get_expr(v))
  overall_tab <- data %>%
    count(!!v, name = "n") %>%
    mutate(
      pct = round(100 * n / sum(n), 1),
      Overall = sprintf("%d (%.1f%%)", n, pct),
      variable = var_label,
      level = as.character(!!v)
    ) %>%
    select(variable, level, Overall)
  by_reg <- data %>%
    count(regimen_anchor, !!v, name = "n") %>%
    group_by(regimen_anchor) %>%
    mutate(pct = round(100 * n / sum(n), 1)) %>%
    ungroup() %>%
    mutate(
      value = sprintf("%d (%.1f%%)", n, pct),
      level = as.character(.data[[v_nm]])
    ) %>%
    select(level, regimen_anchor, value)
  res <- overall_tab %>%
    left_join(by_reg %>% filter(regimen_anchor == "DTG") %>% select(level, DTG = value), by = "level") %>%
    left_join(by_reg %>% filter(regimen_anchor == "PI")  %>% select(level, PI = value),  by = "level")
  # Show variable name only on first row; blank for subsequent levels
  res %>% mutate(variable = if_else(row_number() == 1L, variable, ""))
}

cat("Building Table 1 (baseline by regimen: DTG vs PI)...\n")

# Build Table 1 from df_reg (DTG vs PI only). Include only variables that exist.
tab1_parts <- list(
  row_cont_dtg_pi(df_reg, age_second_line, "Age at second-line (years), median (IQR)"),
  cat_sec_dtg_pi(df_reg, age_group, "Age group"),
  cat_sec_dtg_pi(df_reg, gender, "Sex")
)
tab1_parts <- c(tab1_parts, list(
  row_cont_dtg_pi(df_reg, first_line_duration_years, "Duration on ART before switch (years), median (IQR)"),
  cat_sec_dtg_pi(df_reg, who_stage, "WHO clinical stage at switch"),
  row_cont_dtg_pi(df_reg, baseline_cd4, "Baseline CD4 (cells/mm³), median (IQR)"),
  cat_sec_dtg_pi(df_reg, cd4_cat, "Baseline CD4 category"),
  cat_sec_dtg_pi(df_reg, advanced_hiv_disease, "Advanced HIV disease (CD4 <200 or WHO III/IV)"),
  cat_sec_dtg_pi(df_reg, nrti_backbone, "NRTI backbone")
))
if ("weight_kg" %in% names(df_reg)) tab1_parts <- c(tab1_parts, list(row_cont_dtg_pi(df_reg, weight_kg, "Weight (kg), median (IQR)")))
if ("bmi" %in% names(df_reg)) tab1_parts <- c(tab1_parts, list(row_cont_dtg_pi(df_reg, bmi, "BMI, median (IQR)")))
if ("bmi_cat" %in% names(df_reg)) tab1_parts <- c(tab1_parts, list(cat_sec_dtg_pi(df_reg, bmi_cat, "BMI category")))
if ("adherence_rating" %in% names(df_reg)) tab1_parts <- c(tab1_parts, list(cat_sec_dtg_pi(df_reg, adherence_rating, "Adherence rating")))
if ("morisky_mmas8" %in% names(df_reg)) tab1_parts <- c(tab1_parts, list(cat_sec_dtg_pi(df_reg, morisky_mmas8, "Morisky MMAS-8")))
if ("years_since_hiv_diagnosis" %in% names(df_reg)) tab1_parts <- c(tab1_parts, list(row_cont_dtg_pi(df_reg, years_since_hiv_diagnosis, "Years since HIV diagnosis, median (IQR)")))

tab1_rows <- bind_rows(tab1_parts)

# Morisky is continuous in data; cat_sec will treat it as categorical (0–8). If preferred as continuous, add row_cont_dtg_pi for morisky_mmas8 and drop cat. For now keep categorical so we see distribution.
tab1 <- tab1_rows %>%
  mutate(level = replace(level, level == "NA", NA_character_))

write_csv(tab1, file.path(dataout_dir, "Table1_baseline_DTG_vs_PI.csv"))
cat("Table 1 written to Dataout/Table1_baseline_DTG_vs_PI.csv\n\n")

# Legacy wide table (overall + DTG, PI, Other, NA) for backward compatibility
make_cat_section <- function(data, var, var_label) {
  v <- enquo(var)
  overall_tab <- data %>%
    count(!!v, name = "n") %>%
    mutate(
      pct = round(100 * n / sum(n), 1),
      overall = sprintf("%d (%.1f%%)", n, pct),
      var = var_label,
      level = as.character(!!v)
    ) %>%
    select(var, level, overall)
  by_reg <- data %>%
    count(regimen_anchor, !!v, name = "n") %>%
    group_by(regimen_anchor) %>%
    mutate(pct = round(100 * n / sum(n), 1)) %>%
    ungroup() %>%
    mutate(col = as.character(regimen_anchor), value = sprintf("%d (%.1f%%)", n, pct)) %>%
    select(level = !!v, col, value)
  overall_tab %>%
    left_join(by_reg %>% filter(col == "DTG") %>% select(level, DTG = value), by = "level") %>%
    left_join(by_reg %>% filter(col == "PI") %>% select(level, PI = value), by = "level") %>%
    left_join(by_reg %>% filter(col == "Other") %>% select(level, Other = value), by = "level") %>%
    left_join(by_reg %>% filter(col == "NA") %>% select(level, `NA` = value), by = "level")
}
age_overall_stats <- summarise_cont_overall(df, age_second_line)
age_by_reg <- summarise_cont_by(df, age_second_line, regimen_anchor) %>%
  mutate(col = as.character(regimen_anchor), value = sprintf("%.1f (%.1f–%.1f)", median, p25, p75)) %>%
  select(col, value)
age_row <- tibble(var = "Age at second-line (years)", level = "",
  overall = sprintf("%.1f (%.1f–%.1f)", age_overall_stats$median, age_overall_stats$p25, age_overall_stats$p75),
  DTG = age_by_reg$value[age_by_reg$col == "DTG"][1],
  PI = age_by_reg$value[age_by_reg$col == "PI"][1],
  Other = age_by_reg$value[age_by_reg$col == "Other"][1],
  `NA` = age_by_reg$value[age_by_reg$col == "NA"][1])
tab1_legacy <- bind_rows(
  age_row,
  make_cat_section(df, gender, "Gender"),
  make_cat_section(df, who_stage, "WHO stage"),
  make_cat_section(df, advanced_hiv_disease, "Advanced HIV disease")
)
write_csv(tab1_legacy, file.path(dataout_dir, "Table1_baseline_by_regimen_anchor.csv"))

# Supplementary: Baseline among adults only (DTG vs PI) — same structure as Table 1
df_adults <- df_reg %>% filter(age_group == "Adult")
if (nrow(df_adults) >= 10) {
  tab_appendix_adults <- bind_rows(
    row_cont_dtg_pi(df_adults, age_second_line, "Age at second-line (years), median (IQR)"),
    cat_sec_dtg_pi(df_adults, gender, "Sex"),
    row_cont_dtg_pi(df_adults, first_line_duration_years, "Duration on ART before switch (years), median (IQR)"),
    cat_sec_dtg_pi(df_adults, who_stage, "WHO clinical stage at switch"),
    row_cont_dtg_pi(df_adults, baseline_cd4, "Baseline CD4 (cells/mm³), median (IQR)"),
    cat_sec_dtg_pi(df_adults, cd4_cat, "Baseline CD4 category"),
    cat_sec_dtg_pi(df_adults, advanced_hiv_disease, "Advanced HIV disease"),
    cat_sec_dtg_pi(df_adults, nrti_backbone, "NRTI backbone"),
    row_cont_dtg_pi(df_adults, weight_kg, "Weight (kg), median (IQR)"),
    row_cont_dtg_pi(df_adults, bmi, "BMI, median (IQR)"),
    cat_sec_dtg_pi(df_adults, bmi_cat, "BMI category"),
    cat_sec_dtg_pi(df_adults, adherence_rating, "Adherence rating"),
    cat_sec_dtg_pi(df_adults, morisky_mmas8, "Morisky MMAS-8"),
    row_cont_dtg_pi(df_adults, years_since_hiv_diagnosis, "Years since HIV diagnosis, median (IQR)")
  ) %>% mutate(level = replace(level, level == "NA", NA_character_))
  write_csv(tab_appendix_adults, file.path(dataout_dir, "Appendix_Table_Adults_baseline_DTG_vs_PI.csv"))
  cat("Appendix (adults only) written to Dataout/Appendix_Table_Adults_baseline_DTG_vs_PI.csv, N =", nrow(df_adults), "\n\n")
} else {
  tab_appendix_adults <- NULL
  cat("Appendix adults not written (N < 10).\n\n")
}

# Optional: children and adolescents combined (if numbers allow)
df_paeds <- df_reg %>% filter(age_group %in% c("Child", "Adolescent"))
if (nrow(df_paeds) >= 10) {
  tab_appendix_paeds <- bind_rows(
    row_cont_dtg_pi(df_paeds, age_second_line, "Age at second-line (years), median (IQR)"),
    cat_sec_dtg_pi(df_paeds, age_group, "Age group"),
    cat_sec_dtg_pi(df_paeds, gender, "Sex"),
    row_cont_dtg_pi(df_paeds, first_line_duration_years, "Duration on ART before switch (years), median (IQR)"),
    cat_sec_dtg_pi(df_paeds, who_stage, "WHO clinical stage at switch"),
    row_cont_dtg_pi(df_paeds, baseline_cd4, "Baseline CD4 (cells/mm³), median (IQR)"),
    cat_sec_dtg_pi(df_paeds, cd4_cat, "Baseline CD4 category"),
    cat_sec_dtg_pi(df_paeds, advanced_hiv_disease, "Advanced HIV disease"),
    cat_sec_dtg_pi(df_paeds, nrti_backbone, "NRTI backbone")
  ) %>% mutate(level = replace(level, level == "NA", NA_character_))
  write_csv(tab_appendix_paeds, file.path(dataout_dir, "Appendix_Table_Children_Adolescents_baseline_DTG_vs_PI.csv"))
  cat("Appendix (children/adolescents) written to Dataout/Appendix_Table_Children_Adolescents_baseline_DTG_vs_PI.csv, N =", nrow(df_paeds), "\n\n")
} else {
  tab_appendix_paeds <- NULL
  cat("Appendix children/adolescents not written (N < 10).\n\n")
}

cat("=== Objective 2: Virological and clinical outcomes by regimen anchor (DTG vs PI) ===\n\n")

cat("N in anchor comparison cohort (DTG vs PI):", nrow(df_reg), "\n")
print(tab_prop(df_reg, regimen_anchor))
cat("\n")

# 2a) Virological outcomes by regimen_anchor (DTG vs PI)
#     - Latest VL after second-line: suppressed (<200 copies/mL) vs not
if ("viral_suppressed" %in% names(df_reg)) {
  viro_anchor <- df_reg %>%
    count(regimen_anchor, viral_suppressed) %>%
    group_by(regimen_anchor) %>%
    mutate(pct = round(100 * n / sum(n), 1)) %>%
    ungroup()
  cat("Viral suppression by regimen_anchor (latest VL <200 copies/mL):\n")
  print(viro_anchor)
  cat("\n")
} else if ("vl_status" %in% names(df_reg)) {
  viro_anchor <- df_reg %>%
    count(regimen_anchor, vl_status) %>%
    group_by(regimen_anchor) %>%
    mutate(pct = round(100 * n / sum(n), 1)) %>%
    ungroup()
  cat("Virological status by regimen_anchor (vl_status):\n")
  print(viro_anchor)
  write_csv(viro_anchor, file.path(dataout_dir, "outcomes_virological_by_regimen_anchor.csv"))
  cat("\n")
}

# 2b) Clinical status by regimen_anchor
#     - Status at end of follow-up: Active / Transferred out / Died / LTFU/other / Other
status_var <- if ("status" %in% names(df_reg)) "status" else if ("clinical_status" %in% names(df_reg)) "clinical_status" else NULL

if (!is.null(status_var)) {
  status_anchor <- df_reg %>%
    count(regimen_anchor, .data[[status_var]]) %>%
    group_by(regimen_anchor) %>%
    mutate(pct = round(100 * n / sum(n), 1)) %>%
    ungroup()
  cat("Clinical status at end of follow-up by regimen_anchor:\n")
  print(status_anchor)
  cat("\n")
} else {
  cat("No status/clinical_status variable found; clinical outcomes by regimen_anchor not produced.\n\n")
}

# 2c) Follow-up time by regimen_anchor
#     - Median and IQR of follow-up time (years) from T0
if ("fu_years" %in% names(df_reg)) {
  fu_by_reg <- summarise_cont_by(df_reg, fu_years, regimen_anchor)
  cat("Follow-up time (years) by regimen_anchor:\n")
  print(fu_by_reg)
  cat("\n")
}

cat("=== Objective 3: Outcomes by NRTI backbone (TDF vs AZT vs ABC) ===\n\n")

df_nrti <- df %>%
  filter(nrti_backbone %in% c("TDF", "AZT", "ABC"))

cat("N in NRTI backbone comparison cohort (TDF vs AZT vs ABC):", nrow(df_nrti), "\n")
print(tab_prop(df_nrti, nrti_backbone))
cat("\n")

# 3a) Virological outcomes by backbone (TDF vs AZT vs ABC)
if ("viral_suppressed" %in% names(df_nrti)) {
  viro_nrti <- df_nrti %>%
    count(nrti_backbone, viral_suppressed) %>%
    group_by(nrti_backbone) %>%
    mutate(pct = round(100 * n / sum(n), 1)) %>%
    ungroup()
  cat("Viral suppression by NRTI backbone:\n")
  print(viro_nrti)
  cat("\n")
} else if ("vl_status" %in% names(df_nrti)) {
  viro_nrti <- df_nrti %>%
    count(nrti_backbone, vl_status) %>%
    group_by(nrti_backbone) %>%
    mutate(pct = round(100 * n / sum(n), 1)) %>%
    ungroup()
  cat("Virological status by NRTI backbone (vl_status):\n")
  print(viro_nrti)
  write_csv(viro_nrti, file.path(dataout_dir, "outcomes_virological_by_nrti_backbone.csv"))
  cat("\n")
}

# 3b) Clinical status by backbone
if (!is.null(status_var)) {
  status_nrti <- df_nrti %>%
    count(nrti_backbone, .data[[status_var]]) %>%
    group_by(nrti_backbone) %>%
    mutate(pct = round(100 * n / sum(n), 1)) %>%
    ungroup()
  cat("Clinical status at end of follow-up by NRTI backbone:\n")
  print(status_nrti)
  cat("\n")
}

# 3c) Follow-up by backbone
if ("fu_years" %in% names(df_nrti)) {
  fu_by_nrti <- summarise_cont_by(df_nrti, fu_years, nrti_backbone)
  cat("Follow-up time (years) by NRTI backbone:\n")
  print(fu_by_nrti)
  cat("\n")
}

cat("=== Building manuscript tables (Table 2–4) ===\n\n")

# Table 2: Overall outcomes (Objective 1)
# - Virological outcomes overall
# - Clinical status overall
# - Overall follow-up time (median, IQR)
cat("Building Table 2 (overall outcomes)...\n")

# Overall virological outcomes
if ("viral_suppressed" %in% names(df)) {
  viro_overall <- df %>%
    count(viral_suppressed, name = "n") %>%
    mutate(
      pct = round(100 * n / sum(n), 1),
      row = if_else(viral_suppressed, "Viral suppression <200 copies/mL", "Not suppressed"),
      table = "Table 2"
    ) %>%
    select(table, row, n, pct)
} else if ("vl_status" %in% names(df)) {
  viro_overall <- df %>%
    count(vl_status, name = "n") %>%
    mutate(
      pct = round(100 * n / sum(n), 1),
      row = paste0("Virological status: ", as.character(vl_status)),
      table = "Table 2"
    ) %>%
    select(table, row, n, pct)
} else {
  viro_overall <- tibble(table = character(), row = character(), n = integer(), pct = numeric())
}

# Overall clinical status
status_overall <- NULL
if (!is.null(status_var)) {
  status_overall <- df %>%
    count(.data[[status_var]], name = "n") %>%
    mutate(
      pct = round(100 * n / sum(n), 1),
      row = paste0("Clinical status: ", as.character(.data[[status_var]])),
      table = "Table 2"
    ) %>%
    select(table, row, n, pct)
}

# Overall follow-up
fu_overall <- NULL
if ("fu_years" %in% names(df)) {
  fu_stats <- summarise_cont_overall(df, fu_years)
  fu_overall <- tibble(
    table = "Table 2",
    row = "Follow-up time (years), median (IQR)",
    n = fu_stats$n,
    pct = NA_real_,
    summary = sprintf("%.2f (%.2f–%.2f)", fu_stats$median, fu_stats$p25, fu_stats$p75)
  )
}

table2 <- bind_rows(
  viro_overall,
  status_overall %||% tibble(table = character(), row = character(), n = integer(), pct = numeric()),
  fu_overall %||% tibble(table = character(), row = character(), n = integer(), pct = numeric(), summary = character())
)

write_csv(table2, file.path(dataout_dir, "Table2_overall_outcomes.csv"))
cat("Table 2 written to Dataout/Table2_overall_outcomes.csv\n\n")

# Table 3: Outcomes by regimen anchor (DTG vs PI) — Objective 2
# - Virological outcomes by anchor
# - Clinical status by anchor
# - Follow-up time by anchor
cat("Building Table 3 (DTG vs PI outcomes)...\n")

table3_viro <- if (exists("viro_anchor")) viro_anchor %>%
  mutate(
    outcome = if_else(viral_suppressed, "Suppressed", "Not suppressed"),
    table = "Table 3",
    row_group = "Virological outcome"
  ) %>%
  select(table, row_group, regimen_anchor, outcome, n, pct) else NULL

table3_status <- if (exists("status_anchor")) status_anchor %>%
  mutate(
    table = "Table 3",
    row_group = "Clinical status",
    outcome = as.character(.data[[status_var]])
  ) %>%
  select(table, row_group, regimen_anchor, outcome, n, pct) else NULL

table3_fu <- if (exists("fu_by_reg")) fu_by_reg %>%
  mutate(
    table = "Table 3",
    row_group = "Follow-up time (years)",
    outcome = "median (IQR)",
    summary = sprintf("%.2f (%.2f–%.2f)", median, p25, p75)
  ) %>%
  select(table, row_group, regimen_anchor, outcome, summary) else NULL

table3 <- bind_rows(
  table3_viro %||% tibble(),
  table3_status %||% tibble(),
  table3_fu %||% tibble()
)

write_csv(table3, file.path(dataout_dir, "Table3_outcomes_by_regimen_anchor.csv"))
cat("Table 3 written to Dataout/Table3_outcomes_by_regimen_anchor.csv\n\n")

# Table 4: Outcomes by NRTI backbone — Objective 3
# - Virological outcomes by backbone
# - Clinical status by backbone
# - Follow-up time by backbone
cat("Building Table 4 (NRTI backbone outcomes)...\n")

table4_viro <- if (exists("viro_nrti")) viro_nrti %>%
  mutate(
    outcome = if_else(viral_suppressed, "Suppressed", "Not suppressed"),
    table = "Table 4",
    row_group = "Virological outcome"
  ) %>%
  select(table, row_group, nrti_backbone, outcome, n, pct) else NULL

table4_status <- if (exists("status_nrti")) status_nrti %>%
  mutate(
    table = "Table 4",
    row_group = "Clinical status",
    outcome = as.character(.data[[status_var]])
  ) %>%
  select(table, row_group, nrti_backbone, outcome, n, pct) else NULL

table4_fu <- if (exists("fu_by_nrti")) fu_by_nrti %>%
  mutate(
    table = "Table 4",
    row_group = "Follow-up time (years)",
    outcome = "median (IQR)",
    summary = sprintf("%.2f (%.2f–%.2f)", median, p25, p75)
  ) %>%
  select(table, row_group, nrti_backbone, outcome, summary) else NULL

table4 <- bind_rows(
  table4_viro %||% tibble(),
  table4_status %||% tibble(),
  table4_fu %||% tibble()
)

write_csv(table4, file.path(dataout_dir, "Table4_outcomes_by_nrti_backbone.csv"))
cat("Table 4 written to Dataout/Table4_outcomes_by_nrti_backbone.csv\n\n")

# Combined Excel workbook: all analysis tables in one file (different tabs)
analysis_xlsx_path <- file.path(dataout_dir, "analysis_tables.xlsx")
wb_sheets <- list(
  Table1_baseline_DTG_vs_PI = tab1,
  Table2_overall_outcomes = table2,
  Table3_by_regimen_anchor = table3,
  Table4_by_nrti_backbone = table4
)
if (exists("tab_appendix_adults") && !is.null(tab_appendix_adults)) wb_sheets$Appendix_Adults <- tab_appendix_adults
if (exists("tab_appendix_paeds") && !is.null(tab_appendix_paeds))  wb_sheets$Appendix_Children_Adolescents <- tab_appendix_paeds
write_xlsx(wb_sheets, path = analysis_xlsx_path)
cat("Analysis tables workbook (all in one file):", analysis_xlsx_path, "\n")
cat("Analysis by objectives completed. Tables written to Dataout.\n")
