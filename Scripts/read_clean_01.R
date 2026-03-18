# =============================================================================
# Second-line ART Kenya: Data load, clean, and cohort definition
# Protocol: HIV virological and clinical outcomes on 2nd-line ART (2018-2024)
# =============================================================================
#
# Overview (easy to explain):
#   This script reads the raw second-line ART Excel file, standardises names
#   and types, audits missingness and duplicates, cleans and harmonises values,
#   flags outliers, derives analysis variables (regimen anchor, status,
#   follow-up), and applies the protocol inclusion window. The result is
#   df_analysis (one row per patient, Oct 2018–Sep 2024) and audit outputs
#   in Dataout. Each section below starts with a short "What we did" summary.
#
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Load and basic setup
# -----------------------------------------------------------------------------
# What we did: Load required packages, set the path to the raw Excel file, and
# read the first sheet into a tibble. We treat empty strings and common NA
# codes as missing. df_raw is kept unchanged; df is the working copy for all
# cleaning steps.
# -----------------------------------------------------------------------------
library(tidyverse)
library(janitor)
library(lubridate)
library(readxl)
library(writexl)

# -----------------------------------------------------------------------------
# Output control (turn off writing while iterating)
# -----------------------------------------------------------------------------
# Set to TRUE when you are ready to write outputs to the Dataout folder.
WRITE_OUTPUTS <- FALSE

# Paths (relative to project root); all output files go into dataout
# Use updated extract: 2ndline_Data request_25Feb2026_.xlsx (note trailing underscore)
data_path <- "Data/2ndline_Data request_25Feb2026_.xlsx"
dataout_dir <- "Dataout"
if (WRITE_OUTPUTS && !dir.exists(dataout_dir)) dir.create(dataout_dir, recursive = TRUE)

# Import: raw read-only object (for CSV use readr::read_csv(path, col_types = ..., na = c("", "NA")))
# readxl: sheet 1 is data dictionary, sheet 2 is the patient-level data
df_raw <- read_excel(
  data_path,
  sheet = 2,
  na = c("", "NA", "N/A", "NULL", " ", ".")
) %>%
  as_tibble()

# Working copy; do not modify df_raw
df <- df_raw

# -----------------------------------------------------------------------------
# 2. Schema and naming
# -----------------------------------------------------------------------------
# What we did: Standardise column names to lowercase snake_case so they are
# consistent and easy to use in code. We check that key variables exist, set
# correct data types (dates as Date, IDs as character, categories as factor),
# and ensure cause_of_death is character so ICD/text is preserved. This avoids
# type errors and missing variables later.
# -----------------------------------------------------------------------------
# Clean column names: lowercase, snake_case, no special chars
df <- df %>% clean_names()

# Map new Feb 2026 column names to the legacy names expected downstream
df <- df %>%
  rename(
    de_identified = de_identified_client_id,
    birthdate = date_of_birth,
    gender = sex,
    first_line_start_date = date_of_art_initiation,
    second_line_start_date = date_of_switch_to_second_line_art,
    arv_regimen_2nd_line_start = second_line_regimen_dtg_based_or_pi_based,
    baseline_cd4 = baseline_cd4_count_cells_mm3,
    who_stage = who_stage_at_diagnosis_stage_i_iv,
    advanced_hiv_disease = advanced_hiv_disease_yes_no_cd4_200_or_who_stage_iii_iv,
    opportunistic_infections = presence_of_opportunistic_infections,
    adherence_rating = adherence_rating_at_switch
  )

# Rename advanced HIV column (janitor leaves long name)
adv_col <- names(df)[grepl("advanced_hiv", names(df), ignore.case = TRUE)]
if (length(adv_col) == 1L && adv_col != "advanced_hiv_disease")
  df <- df %>% rename(advanced_hiv_disease = !!sym(adv_col))

# Verify key variables and enforce classes
key_vars <- c(
  "de_identified", "gender", "birthdate",
  "first_line_start_date", "second_line_start_date",
  "arv_regimen_2nd_line_start", "latest_vl_date",
  "vl_status", "baseline_cd4",
  "adherence_rating", "morisky_mmas8",
  "opportunistic_infections"
)
missing_key <- setdiff(key_vars, names(df))
if (length(missing_key) > 0) warning("Key variables not found: ", paste(missing_key, collapse = ", "))

# Enforce types: ID as character, dates as Date, factors for categorical
df <- df %>%
  mutate(
    de_identified = as.character(de_identified),
    birthdate = as.Date(birthdate),
    first_line_start_date = as.Date(first_line_start_date),
    second_line_start_date = as.Date(second_line_start_date),
    latest_vl_date = as.Date(latest_vl_date),
    gender = as.factor(gender),
    vl_status = as.factor(vl_status),
    adherence_rating = as.factor(adherence_rating),
    advanced_hiv_disease = as.factor(advanced_hiv_disease)
  )

# Cause of death: ensure character if present (keeps ICD/text intact)
if ("cause_of_death" %in% names(df)) {
  df <- df %>% mutate(cause_of_death = as.character(cause_of_death))
}

# -----------------------------------------------------------------------------
# 3. Initial data audit
# -----------------------------------------------------------------------------
# What we did: Summarise the dataset before cleaning—row count, number of
# patients, date range of second-line start, and rows per patient. We compute
# missingness for every variable and by gender for key covariates, then write
# these tables to Dataout so we can report data quality and plan handling of
# missing data.
# -----------------------------------------------------------------------------
audit <- list(
  n_rows = nrow(df),
  n_cols = ncol(df),
  n_distinct_patients = n_distinct(df$de_identified),
  second_line_date_range = range(df$second_line_start_date, na.rm = TRUE),
  rows_per_patient = df %>% count(de_identified, name = "n_rows") %>% pull(n_rows)
)

# High-level counts
cat("--- Initial data audit ---\n")
cat("Rows:", audit$n_rows, "\n")
cat("Distinct patients (ID):", audit$n_distinct_patients, "\n")
cat("Second-line start range:", as.character(audit$second_line_date_range[1]), "to", as.character(audit$second_line_date_range[2]), "\n")
cat("Rows per person: min =", min(audit$rows_per_patient), ", max =", max(audit$rows_per_patient), ", mean =", round(mean(audit$rows_per_patient), 2), "\n")

# Missingness per variable
missingness <- df %>%
  summarise(across(everything(), ~ sum(is.na(.x)))) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "n_missing") %>%
  mutate(
    pct_missing = round(100 * n_missing / nrow(df), 2),
    .after = n_missing
  )
cat("\nVariables with any missing:\n")
print(missingness %>% filter(n_missing > 0) %>% arrange(desc(n_missing)))

# Missingness by sex (key stratum)
missing_by_sex <- df %>%
  group_by(gender) %>%
  summarise(
    n = n(),
    across(
      c(arv_regimen_2nd_line_start, who_stage, baseline_cd4, adherence_rating, morisky_mmas8, vl_status),
      ~ round(100 * mean(is.na(.x)), 1),
      .names = "pct_na_{.col}"
    ),
    .groups = "drop"
  )
cat("\nMissingness % by gender (key vars):\n")
print(missing_by_sex)

# Write missingness tables to dataout folder
if (WRITE_OUTPUTS) {
  readr::write_csv(missingness, file.path(dataout_dir, "missingness.csv"))
  readr::write_csv(missing_by_sex, file.path(dataout_dir, "missingness_by_sex.csv"))
  write_xlsx(
    list(missingness = missingness, missingness_by_sex = missing_by_sex),
    path = file.path(dataout_dir, "missingness_tables.xlsx")
  )
}

# -----------------------------------------------------------------------------
# 4. De-duplication and ID logic
# -----------------------------------------------------------------------------
# What we did: Enforce one row per patient. We find duplicate patient IDs and,
# when present, keep only the first record per ID (ordered by second-line start
# date) and drop the rest. This matches the protocol’s cohort definition:
# one record per patient on second-line ART.
# -----------------------------------------------------------------------------
# Grain: one row per person (per protocol: second-line cohort, one record per patient)
# Check for duplicate IDs
dup_ids <- df %>%
  count(de_identified, name = "n") %>%
  filter(n > 1)
n_dup <- nrow(dup_ids)
n_dup_patients <- sum(dup_ids$n - 1)

if (n_dup > 0) {
  cat("\nDuplicate IDs:", n_dup, "IDs with", n_dup_patients, "extra rows.\n")
  # Protocol: one row per person → keep first record per ID (by second_line_start_date)
  df <- df %>%
    arrange(de_identified, second_line_start_date) %>%
    distinct(de_identified, .keep_all = TRUE)
  cat("Resolved: kept first record per de_identified. N after dedup:", nrow(df), "\n")
} else {
  cat("\nNo duplicate de_identified; grain is one row per person.\n")
}

# Document decision
# DECISION: Dataset is one row per person. Duplicates (if any) resolved by keeping
# first second-line start date per patient.

# -----------------------------------------------------------------------------
# 5. Value cleaning and standardization
# -----------------------------------------------------------------------------
# What we did: Make values consistent and clinically plausible. We recode
# gender (e.g. F/M to Female/Male), set impossible or placeholder numbers to
# NA (e.g. CD4 <0 or >10000, BMI outside 10-80), harmonise VL status labels,
# create a grouped reason_for_exit for analysis, and build cause-of-death
# indicators (has_cause_of_death, cause_of_death_category) when the column
# exists. This gives clean categories and avoids invalid numbers in analyses.
# -----------------------------------------------------------------------------
# Harmonize gender
df <- df %>%
  mutate(
    gender = fct_recode(gender,
      "Female" = "F",
      "Male" = "M"
    )
  )

# Standardize impossible/special codes to NA (e.g. 9999, -1 for numeric)
df <- df %>%
  mutate(
    baseline_cd4 = if_else(baseline_cd4 < 0 | baseline_cd4 > 10000, NA_real_, baseline_cd4),
    height_cm = if_else(!is.na(height_cm) & (height_cm < 20 | height_cm > 250), NA_real_, height_cm),
    weight_kg = if_else(!is.na(weight_kg) & (weight_kg < 2 | weight_kg > 300), NA_real_, weight_kg),
    bmi = if_else(!is.na(bmi) & (bmi < 10 | bmi > 80), NA_real_, bmi),
    morisky_mmas8 = if_else(!is.na(morisky_mmas8) & (morisky_mmas8 < 0 | morisky_mmas8 > 8), NA_real_, morisky_mmas8)
  )

# Harmonize vl_status (ensure consistent levels)
df <- df %>%
  mutate(
    vl_status = fct_recode(vl_status,
      "Suppressed" = "Suppressed",
      "Unsuppressed" = "Unsuppressed"
    )
  )

# Reason for exit: grouped category for analysis (keep original reason_for_exit)
exit_keep <- c(
  "PATIENT DIED", "PATIENT TRANSFERRED OUT", "POOR ADHERENCE, NOS",
  "SELF DISCONNECTED FROM CARE", "HIGH VIRAL LOAD", "OTHER NON-CODED"
)
# New Feb 2026 extract does not carry a raw reason_for_exit column; if missing,
# create an NA placeholder so downstream code runs (clinical status handled
# separately using clinical_status_* variables).
if (!"reason_for_exit" %in% names(df)) {
  df$reason_for_exit <- NA_character_
}
df <- df %>%
  mutate(
    reason_for_exit_grouped = case_when(
      is.na(reason_for_exit) ~ NA_character_,
      as.character(reason_for_exit) %in% exit_keep ~ as.character(reason_for_exit),
      TRUE ~ "Other"
    ),
    reason_for_exit_grouped = factor(reason_for_exit_grouped, levels = c(exit_keep, "Other"))
  )

# Cause of death: indicators and optional category (only if cause_of_death column exists)
if ("cause_of_death" %in% names(df)) {
  df <- df %>%
    mutate(
      has_cause_of_death = !is.na(cause_of_death) & trimws(cause_of_death) != "",
      # Simple category: AIDS-related (HIV/TB/OI keywords) vs Other vs Unspecified (blank/NA)
      cause_of_death_category = case_when(
        is.na(cause_of_death) | trimws(cause_of_death) == "" ~ NA_character_,
        grepl("aids|hiv|tb|tuberculosis|opportunistic|pneumocystis|cryptococc|meningitis|toxoplasm|cmv|candidiasis|kaposi", tolower(cause_of_death)) ~ "AIDS-related",
        TRUE ~ "Non-AIDS"
      ),
      cause_of_death_category = factor(cause_of_death_category, levels = c("AIDS-related", "Non-AIDS"))
    )
} else {
  df <- df %>%
    mutate(
      has_cause_of_death = NA,
      cause_of_death_category = factor(NA, levels = c("AIDS-related", "Non-AIDS"))
    )
}

# -----------------------------------------------------------------------------
# 6. Outliers and plausibility checks
# -----------------------------------------------------------------------------
# What we did: Flag values outside plausible clinical ranges without deleting
# them. We derive age at second-line start and flag impossible ages; we add
# flags for CD4, weight, height, BMI, Morisky score (and later follow-up and
# BP). Outlier counts and ranges are written to Dataout for review. Rows are
# kept so we can decide later whether to exclude or recode.
# -----------------------------------------------------------------------------
# Variables to check and plausible ranges (clinical/logic):
#   baseline_cd4    : 0-3000 cells/mm³ (CD4 count at second-line start)
#   age_second_line : 0-100 years (derived from birthdate, second_line_start_date)
#   weight_kg       : 2.5-200 kg (children and adults)
#   height_cm       : 45-220 cm (infant to adult)
#   bmi             : 12-60 kg/m² (severe underweight to obese)
#   morisky_mmas8    : 0-8 (adherence scale, by definition)
#   fu_years        : 0-6.5 (follow-up; study window Oct 2018-Sep 2024) [checked in step 8]
#   systolic_bp     : 70-250 mmHg (if present)
#   diastolic_bp    : 40-150 mmHg (if present)

# Define plausible ranges and flag (do not drop yet; log for review)
issues_log <- tibble(
  variable = character(),
  id = character(),
  value = NA_real_,
  bound = character(),
  action = character()
)

# Age at second-line start (derived later); flag if birthdate after second_line_start
df <- df %>%
  mutate(
    age_second_line = as.numeric(second_line_start_date - birthdate) / 365.25,
    flag_age_impossible = age_second_line < 0 | age_second_line > 120
  )
if (any(df$flag_age_impossible, na.rm = TRUE)) {
  n_impl <- sum(df$flag_age_impossible, na.rm = TRUE)
  cat("\nFlagged", n_impl, "rows with impossible age (birthdate vs second-line start).\n")
  df <- df %>% mutate(age_second_line = if_else(flag_age_impossible, NA_real_, age_second_line))
}
df <- df %>% select(-flag_age_impossible)

# CD4, weight, height already bounded in step 5; add flags for audit
df <- df %>%
  mutate(
    flag_cd4_out = !is.na(baseline_cd4) & (baseline_cd4 < 0 | baseline_cd4 > 3000),
    flag_weight_out = !is.na(weight_kg) & (weight_kg < 2 | weight_kg > 300),
    flag_height_out = !is.na(height_cm) & (height_cm < 30 | height_cm > 250),
    flag_bmi_out = !is.na(bmi) & (bmi < 12 | bmi > 60),
    flag_morisky_out = !is.na(morisky_mmas8) & (morisky_mmas8 < 0 | morisky_mmas8 > 8)
  )

# -----------------------------------------------------------------------------
# 7. Missing data handling (pre-descriptive)
# -----------------------------------------------------------------------------
# What we did: Create binary indicators for whether key covariates were
# observed (e.g. has_baseline_cd4, has_who_stage, has_adherence, has_vl_status,
# has_regimen). These are used for descriptive tables and to define analysis
# subsets. We do not impute missing values here; that is left for the
# modelling stage if needed.
# -----------------------------------------------------------------------------
# Classify: create "ever measured" / "has value" indicators for key covariates
df <- df %>%
  mutate(
    has_baseline_cd4 = !is.na(baseline_cd4),
    has_who_stage = !is.na(who_stage),
    has_adherence = !is.na(adherence_rating) | !is.na(morisky_mmas8),
    has_vl_status = !is.na(vl_status),
    has_regimen = !is.na(arv_regimen_2nd_line_start)
  )

# Structural missing: e.g. third_line only if escalated
# Unobserved: treat as NA; no imputation here (postpone to inferential stage)

# -----------------------------------------------------------------------------
# 8. Variable derivation
# -----------------------------------------------------------------------------
# What we did: Build analysis variables from raw columns. We classify
# second-line regimen into anchor (DTG vs PI vs Other) and NRTI backbone
# (TDF vs AZT vs ABC); create viral_suppressed (binary from vl_status);
# create status (Active / Transferred out / Died / LTFU/other / Other) using
# reason_for_exit and cause_of_death; compute follow-up time and end date;
# add outlier flags for follow-up and BP; and run consistency checks on dates.
# Outlier summary tables are written to Dataout.
# -----------------------------------------------------------------------------
# Anchor: DTG vs PI (PI = ATV, LOP, DRV; RTV is booster, not anchor)
df <- df %>%
  mutate(
    regimen_anchor = case_when(
      is.na(arv_regimen_2nd_line_start) ~ NA_character_,
      grepl("DTG", arv_regimen_2nd_line_start, ignore.case = TRUE)  ~ "DTG",
      grepl("ATV|LOP|DRV", arv_regimen_2nd_line_start, ignore.case = TRUE) ~ "PI",
      TRUE ~ "Other"
    ),
    regimen_anchor = factor(regimen_anchor, levels = c("DTG", "PI", "Other"))
  )

# NRTI backbone: TDF vs AZT vs ABC (first present in regimen; mutually exclusive for analysis)
df <- df %>%
  mutate(
    nrti_backbone = case_when(
      is.na(arv_regimen_2nd_line_start) ~ NA_character_,
      grepl("TDF", arv_regimen_2nd_line_start, ignore.case = TRUE)  ~ "TDF",
      grepl("AZT", arv_regimen_2nd_line_start, ignore.case = TRUE) ~ "AZT",
      grepl("ABC", arv_regimen_2nd_line_start, ignore.case = TRUE) ~ "ABC",
      TRUE ~ "Other"
    ),
    nrti_backbone = factor(nrti_backbone, levels = c("TDF", "AZT", "ABC", "Other"))
  )

# Binary viral suppression (outcome): <200 copies/mL per protocol
df <- df %>%
  mutate(
    viral_suppressed = case_when(
      vl_status %in% "Suppressed" ~ TRUE,
      vl_status %in% "Unsuppressed" ~ FALSE,
      TRUE ~ NA
    )
  )

# Status (outcome): active vs LTFU / transfer / died
# Uses reason_for_exit; when cause_of_death exists, non-NA cause_of_death also implies Died
df <- df %>%
  mutate(
    status = case_when(
      reason_for_exit %in% "PATIENT DIED" ~ "Died",
      has_cause_of_death %in% TRUE ~ "Died",
      reason_for_exit %in% "PATIENT TRANSFERRED OUT" ~ "Transferred out",
      reason_for_exit %in% c("POOR ADHERENCE, NOS", "SELF DISCONNECTED FROM CARE", "HIGH VIRAL LOAD") ~ "LTFU/other",
      !is.na(reason_for_exit) ~ "Other",
      TRUE ~ "Active"
    ),
    status = factor(status, levels = c("Active", "Transferred out", "Died", "LTFU/other", "Other"))
  )
# Keep clinical_status as alias for backward compatibility
df <- df %>% mutate(clinical_status = status)

# Baseline covariates (for models): use as-is; already have advanced_hiv_disease
# Follow-up time (years) from second-line start to latest VL or study end (censored at study end)
# Study end = 2024-09-30 so we do not count person-time beyond the protocol window.
STUDY_END <- as.Date("2024-09-30")
df <- df %>%
  mutate(
    fu_end = pmin(coalesce(latest_vl_date, STUDY_END), STUDY_END),
    fu_years = as.numeric(fu_end - second_line_start_date) / 365.25,
    fu_years = pmax(0, fu_years, na.rm = TRUE)
  )

# Outlier flag for follow-up: only flag impossible values (fu_years < 0).
# Long follow-up is not an outlier — people are censored at study end, so fu_years can be up to ~6 years.
df <- df %>% mutate(flag_fu_years_out = !is.na(fu_years) & (fu_years < 0))
if ("systolic_bp" %in% names(df)) df <- df %>% mutate(flag_sbp_out = !is.na(systolic_bp) & (systolic_bp < 70 | systolic_bp > 250))
if ("diastolic_bp" %in% names(df)) df <- df %>% mutate(flag_dbp_out = !is.na(diastolic_bp) & (diastolic_bp < 40 | diastolic_bp > 150))

# Consistency checks
df <- df %>%
  mutate(
    check_second_after_first = is.na(first_line_start_date) | is.na(second_line_start_date) | second_line_start_date >= first_line_start_date,
    check_birth_before_second = is.na(birthdate) | is.na(second_line_start_date) | birthdate <= second_line_start_date,
    check_death_after_second = !reason_for_exit %in% "PATIENT DIED" | is.na(second_line_start_date) | TRUE  # cause_of_death date if needed
  )
n_inconsist <- sum(!df$check_second_after_first, na.rm = TRUE) + sum(!df$check_birth_before_second, na.rm = TRUE)
if (n_inconsist > 0) cat("\nConsistency flags:", n_inconsist, "rows with date logic issues (see check_*).\n")

# Outlier summary: counts and ranges per variable (write to Dataout)
outlier_spec <- tribble(
  ~variable,         ~lower_bound, ~upper_bound, ~flag_col,
  "baseline_cd4",    0,           3000,         "flag_cd4_out",
  "age_second_line", 0,           100,           NA_character_,
  "weight_kg",       2,           300,          "flag_weight_out",
  "height_cm",       30,          250,          "flag_height_out",
  "bmi",             12,          60,           "flag_bmi_out",
  "morisky_mmas8",   0,           8,            "flag_morisky_out",
  "fu_years",        0,           10,           "flag_fu_years_out",
  "systolic_bp",     70,          250,          "flag_sbp_out",
  "diastolic_bp",    40,          150,          "flag_dbp_out"
)
outlier_summary_list <- vector("list", nrow(outlier_spec))
for (i in seq_len(nrow(outlier_spec))) {
  v <- outlier_spec$variable[i]
  if (!v %in% names(df)) next
  flag_col <- outlier_spec$flag_col[i]
  n_non_na <- sum(!is.na(df[[v]]))
  n_out <- if (length(flag_col) && !is.na(flag_col) && flag_col %in% names(df)) sum(df[[flag_col]], na.rm = TRUE) else sum(df[[v]] < outlier_spec$lower_bound[i] | df[[v]] > outlier_spec$upper_bound[i], na.rm = TRUE)
  vals <- df[[v]]
  min_obs <- if (n_non_na > 0) min(vals, na.rm = TRUE) else NA_real_
  max_obs <- if (n_non_na > 0) max(vals, na.rm = TRUE) else NA_real_
  outlier_summary_list[[i]] <- tibble(
    variable = v,
    lower_bound = outlier_spec$lower_bound[i],
    upper_bound = outlier_spec$upper_bound[i],
    n_non_na = n_non_na,
    n_out_of_range = n_out,
    pct_out_of_range = round(100 * n_out / max(1, n_non_na), 2),
    min_observed = min_obs,
    max_observed = max_obs
  )
}
outlier_summary <- bind_rows(outlier_summary_list) %>% filter(!is.na(variable))
if (WRITE_OUTPUTS) {
  readr::write_csv(outlier_summary, file.path(dataout_dir, "outlier_summary.csv"))
  write_xlsx(list(outlier_summary = outlier_summary), path = file.path(dataout_dir, "outlier_summary.xlsx"))
}

# -----------------------------------------------------------------------------
# VL history: long-format df (vl_df) from packed string column
# -----------------------------------------------------------------------------
# Some extracts store VL history after switch in a single string column where:
# - Each measurement is encoded as \"YYYY-MM-DD;VL\" (date;value)
# - Multiple measurements are separated by \"|\"
# We create a long-format data frame (one row per VL) with:
#   de_identified, birthdate, second_line_start_date, vl_date, vl_value
# and save it for downstream use.

vl_col_name <- NULL
if ("vl_history_after_switch" %in% names(df)) vl_col_name <- "vl_history_after_switch"
if (is.null(vl_col_name) && "all_vl_results_after_2nd_line" %in% names(df)) vl_col_name <- "all_vl_results_after_2nd_line"

if (!is.null(vl_col_name)) {
  vl_raw <- df %>%
    select(de_identified, birthdate, second_line_start_date, !!sym(vl_col_name)) %>%
    rename(vl_history = !!sym(vl_col_name))

  vl_df <- vl_raw %>%
    separate_rows(vl_history, sep = "\\|") %>%
    filter(!is.na(vl_history), vl_history != "") %>%
    separate(
      vl_history,
      into = c("vl_date_raw", "vl_value_raw"),
      sep = ";",
      fill = "right",
      remove = TRUE
    ) %>%
    mutate(
      vl_date_raw = stringr::str_trim(vl_date_raw),
      vl_value_raw = stringr::str_trim(vl_value_raw),
      vl_date = as.Date(vl_date_raw),
      vl_value = suppressWarnings(as.numeric(vl_value_raw))
    ) %>%
    select(
      de_identified,
      birthdate,
      second_line_start_date,
      vl_date,
      vl_value
    ) %>%
    # Deduplicate exact repeats (common in some EMR extracts)
    distinct(de_identified, second_line_start_date, vl_date, vl_value, .keep_all = TRUE) %>%
    arrange(de_identified, vl_date)
  # vl_df is kept in memory for downstream use; not written to disk here.
  cat("VL history long-format dataframe (vl_df) created in memory.\n")
  # Summary by person: number of VLs and first/last VL date
  vl_counts <- vl_df %>%
    group_by(de_identified) %>%
    summarise(
      n_vl = sum(!is.na(vl_value)),
      first_vl_date = min(vl_date, na.rm = TRUE),
      last_vl_date  = max(vl_date, na.rm = TRUE),
      vl_span_years = as.numeric(last_vl_date - first_vl_date) / 365.25,
      .groups = "drop"
    )
  # Distribution of n_vl across people
  vl_counts_dist <- vl_counts %>%
    count(n_vl, name = "n_patients") %>%
    mutate(pct = round(100 * n_patients / sum(n_patients), 1))
  # Wide format (one row per person): vl_date_1/vl_value_1, vl_date_2/vl_value_2, ...
  # NOTE: This can create a very wide table if some patients have many VLs.
  vl_df_wide <- vl_df %>%
    filter(!is.na(vl_date)) %>%
    group_by(de_identified, birthdate, second_line_start_date) %>%
    arrange(vl_date, .by_group = TRUE) %>%
    mutate(vl_idx = row_number()) %>%
    ungroup() %>%
    select(de_identified, birthdate, second_line_start_date, vl_idx, vl_date, vl_value) %>%
    pivot_wider(
      id_cols = c(de_identified, birthdate, second_line_start_date),
      names_from = vl_idx,
      values_from = c(vl_date, vl_value),
      names_glue = "{.value}_{vl_idx}"
    )
  cat("VL counts by de_identified (vl_counts) and distribution (vl_counts_dist) created in memory.\n")
  cat("Deduplicated VL wide dataframe (vl_df_wide) created in memory.\n")
} else {
  cat("No VL history string column found (vl_history_after_switch or all_vl_results_after_2nd_line); vl_df not created.\n")
}

# -----------------------------------------------------------------------------
# 9. Cohort restriction and final checks
# -----------------------------------------------------------------------------
# What we did: Apply the protocol inclusion window (second-line start between
# Oct 2018 and Sep 2024) and drop rows with missing patient ID. We save the
# resulting analysis cohort as df_analysis, write flagged outliers to Dataout
# for review, then drop audit/flag columns from df_analysis and save df_raw
# and df_analysis as RDS for use in downstream scripts.
# -----------------------------------------------------------------------------
# Protocol: second-line ART between October 2018 and September 2024; Western Kenya
PROTOCOL_START <- as.Date("2018-10-01")
PROTOCOL_END   <- as.Date("2024-09-30")

df_analysis <- df %>%
  filter(
    !is.na(second_line_start_date),
    second_line_start_date >= PROTOCOL_START,
    second_line_start_date <= PROTOCOL_END,
    !is.na(de_identified)
  )

# Exclusions (document counts) for protocol window
n_before <- nrow(df)
n_after_date <- df %>%
  filter(
    !is.na(second_line_start_date),
    second_line_start_date >= PROTOCOL_START,
    second_line_start_date <= PROTOCOL_END
  ) %>%
  nrow()
n_excluded_date <- n_before - n_after_date
n_excluded_na_id <- sum(is.na(df$de_identified))
n_final <- nrow(df_analysis)

cat("\n--- Cohort restriction (protocol window) ---\n")
cat("N before any exclusion:", n_before, "\n")
cat("N excluded (outside Oct 2018 - Sep 2024 or NA date):", n_excluded_date, "\n")
cat("N excluded (NA ID):", n_excluded_na_id, "\n")
cat("N in analysis cohort (df_analysis):", n_final, "\n")

# Optional: subcohort with at least 6 months follow-up after T0
df_analysis_6m <- df_analysis %>%
  filter(fu_years >= 0.5)
n_6m <- nrow(df_analysis_6m)
cat("N in 6+ month follow-up subcohort (df_analysis_6m):", n_6m, "\n")

# Optional: restrict to confirmed second-line failure per protocol definition
# Uncomment if analysis is only among confirmed failures:
# df_analysis <- df_analysis %>% filter(confirmed_vl_failure %in% "Confirmed Failure")

# Optional: exclude missing regimen for regimen comparisons (Obj 2 & 3)
# df_analysis_regimen <- df_analysis %>% filter(has_regimen, regimen_anchor %in% c("DTG", "PI"))

# Outlier review: rows with any flagged value (keep flag cols for review)
df_outliers <- df_analysis %>%
  filter(if_any(starts_with("flag_"), ~ .x == TRUE))

if (WRITE_OUTPUTS) {
  readr::write_csv(df_outliers, file.path(dataout_dir, "df_outliers.csv"))
  write_xlsx(list(df_outliers = df_outliers), path = file.path(dataout_dir, "df_outliers.xlsx"))
  saveRDS(df_outliers, file.path(dataout_dir, "df_outliers.rds"))
}

# Freeze structure: drop audit flags if desired for cleaner analysis object
df_analysis <- df_analysis %>%
  select(-starts_with("check_"), -starts_with("flag_"))

# Save objects for downstream scripts
if (WRITE_OUTPUTS) {
  saveRDS(df_raw, file.path(dataout_dir, "df_raw.rds"))
  saveRDS(df_analysis, file.path(dataout_dir, "df_analysis.rds"))
  # Optional: readr::write_csv(df_analysis, file.path(dataout_dir, "df_analysis.csv"))
}

# Combined Excel workbook for data-quality review (one file, multiple tabs)
# Includes: missingness tables, outlier summary, and df_outliers.
combined_xlsx_path <- file.path(dataout_dir, "data_quality_review.xlsx")
if (WRITE_OUTPUTS) {
  tryCatch(
    write_xlsx(
      purrr::compact(list(
        missingness = if (exists("missingness")) missingness else NULL,
        missingness_by_sex = if (exists("missing_by_sex")) missing_by_sex else NULL,
        outlier_summary = if (exists("outlier_summary")) outlier_summary else NULL,
        df_outliers = if (exists("df_outliers")) df_outliers else NULL
      )),
      path = combined_xlsx_path
    ),
    error = function(e) {
      cat("[WARN] Could not write data_quality_review.xlsx (is it open in Excel?).\n")
      cat("[WARN] ", conditionMessage(e), "\n", sep = "")
      invisible(NULL)
    }
  )
}

cat("\nDone.\n")
