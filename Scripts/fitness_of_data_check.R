# =============================================================================
# Fitness of data check — SAP alignment
# Run after read_clean_01.R (uses df_analysis from Dataout).
# Verifies that the dataset has the variables and completeness needed for the
# pharmacoepidemiologic SAP (T0, exposure, outcomes, baseline, censoring).
# =============================================================================

library(tidyverse)

dataout_dir <- "Dataout"
rds_path <- file.path(dataout_dir, "df_analysis.rds")

# -----------------------------------------------------------------------------
# 1. Load analysis cohort (or raw data if RDS not found)
# -----------------------------------------------------------------------------
if (file.exists(rds_path)) {
  df <- readRDS(rds_path)
  cat("Loaded df_analysis from", rds_path, "— N =", nrow(df), "\n\n")
} else {
  cat("WARNING: df_analysis.rds not found. Run read_clean_01.R first if you want the cleaned cohort.\n")
  cat("Attempting to load raw Excel for minimal check (2ndline_Data request_25Feb2026)...\n\n")
  if (!requireNamespace("readxl", quietly = TRUE)) install.packages("readxl", repos = "https://cloud.r-project.org")
  if (!requireNamespace("janitor", quietly = TRUE)) install.packages("janitor", repos = "https://cloud.r-project.org")
  data_path <- "Data/2ndline_Data request_25Feb2026.xlsx"
  if (!file.exists(data_path)) {
    stop("Neither df_analysis.rds nor raw Excel (2ndline_Data request_25Feb2026.xlsx) found. Check the Data folder.")
  }
  # Sheet 1 = data dictionary, Sheet 2 = data (2ndline_Data request_25Feb2026)
  df <- readxl::read_excel(data_path, sheet = 2, na = c("", "NA", "N/A")) %>%
    as_tibble() %>%
    janitor::clean_names()
  df <- df %>%
    filter(
      !is.na(second_line_start_date),
      second_line_start_date >= as.Date("2018-10-01"),
      second_line_start_date <= as.Date("2024-09-30"),
      !is.na(de_identified)
    )
  cat("Loaded raw data (window applied) — N =", nrow(df), "\n\n")
}

n <- nrow(df)

# -----------------------------------------------------------------------------
# 2. Define SAP variable groups and required variables
# -----------------------------------------------------------------------------
sap_vars <- list(
  cohort_t0 = c("de_identified", "second_line_start_date", "first_line_start_date"),
  exposure = c("arv_regimen_2nd_line_start", "regimen_anchor", "nrti_backbone"),
  baseline = c(
    "birthdate", "gender", "facility_name", "who_stage", "baseline_cd4",
    "advanced_hiv_disease", "adherence_rating", "morisky_mmas8", "date_hiv_diagnosis"
  ),
  outcomes = c("vl_status", "viral_suppressed", "reason_for_exit", "cause_of_death", "status", "clinical_status"),
  follow_up = c("latest_vl_date", "fu_years"),
  censoring = c("reason_for_exit")
)
# Optional: regimen_switch_date not in standard extract
all_sap <- unique(c(unlist(sap_vars), "fu_years", "regimen_anchor", "nrti_backbone", "viral_suppressed", "status"))

# -----------------------------------------------------------------------------
# 3. Check presence and completeness
# -----------------------------------------------------------------------------
check_one <- function(data, var) {
  if (!var %in% names(data)) {
    return(list(present = FALSE, n_non_na = 0, pct = 0))
  }
  n_na <- sum(is.na(data[[var]]))
  n_ok <- n - n_na
  pct <- round(100 * n_ok / n, 1)
  list(present = TRUE, n_non_na = n_ok, pct = pct)
}

results <- tibble(
  variable = character(),
  group = character(),
  present = logical(),
  n_non_na = integer(),
  pct_complete = numeric(),
  fitness = character()
)

for (grp in names(sap_vars)) {
  for (v in sap_vars[[grp]]) {
    if (v %in% names(df)) {
      x <- check_one(df, v)
      fit <- case_when(
        x$pct >= 95 ~ "OK",
        x$pct >= 70 ~ "Partial",
        x$pct >= 30 ~ "Weak",
        TRUE ~ "Limited"
      )
      results <- bind_rows(results, tibble(
        variable = v,
        group = grp,
        present = TRUE,
        n_non_na = x$n_non_na,
        pct_complete = x$pct,
        fitness = fit
      ))
    } else {
      results <- bind_rows(results, tibble(
        variable = v,
        group = grp,
        present = FALSE,
        n_non_na = 0L,
        pct_complete = 0,
        fitness = "Missing"
      ))
    }
  }
}

# -----------------------------------------------------------------------------
# 4. Inclusion criteria checks (SAP 3.2)
# -----------------------------------------------------------------------------
# At least 6 months on ART by T0
if ("first_line_start_date" %in% names(df) && "second_line_start_date" %in% names(df)) {
  df <- df %>% mutate(
    first_line_days = as.numeric(second_line_start_date - first_line_start_date),
    meets_6mo_art = first_line_days >= 180
  )
  n_6mo <- sum(df$meets_6mo_art, na.rm = TRUE)
  pct_6mo <- round(100 * n_6mo / n, 1)
} else {
  n_6mo <- NA
  pct_6mo <- NA
}

# At least 2 VL measurements (proxy: non-missing vl_status or all_vl_results)
if ("all_vl_results_after_2nd_line" %in% names(df)) {
  has_vl_info <- !is.na(df$vl_status) | (!is.na(df$all_vl_results_after_2nd_line) & nchar(as.character(df$all_vl_results_after_2nd_line)) > 0)
} else {
  has_vl_info <- !is.na(df$vl_status) %in% TRUE
}
n_2vl <- sum(has_vl_info, na.rm = TRUE)
pct_2vl <- round(100 * n_2vl / n, 1)

# -----------------------------------------------------------------------------
# 5. Regimen and calendar year (for channeling)
# -----------------------------------------------------------------------------
if ("regimen_anchor" %in% names(df)) {
  regimen_dist <- df %>% count(regimen_anchor, name = "n") %>% mutate(pct = round(100 * n / sum(n), 1))
} else {
  regimen_dist <- NULL
}
if ("second_line_start_date" %in% names(df)) {
  df <- df %>% mutate(year_t0 = as.integer(format(second_line_start_date, "%Y")))
  year_dist <- df %>% count(year_t0, name = "n") %>% mutate(pct = round(100 * n / sum(n), 1))
} else {
  year_dist <- NULL
}

# -----------------------------------------------------------------------------
# 6. Print report
# -----------------------------------------------------------------------------
cat("========== FITNESS OF DATA CHECK ==========\n\n")
cat("Cohort N:", n, "\n\n")

cat("--- Variable presence and completeness ---\n")
print(results %>% select(variable, group, present, n_non_na, pct_complete, fitness))
cat("\n")

cat("--- Inclusion criteria (SAP 3.2) ---\n")
cat("  At least 6 months on ART by T0:", n_6mo, "(", pct_6mo, "%)\n")
cat("  Has VL information (proxy for ≥2 VLs):", n_2vl, "(", pct_2vl, "%)\n")
cat("\n")

if (!is.null(regimen_dist)) {
  cat("--- Regimen at T0 (exposure) ---\n")
  print(regimen_dist)
  cat("\n")
}
if (!is.null(year_dist)) {
  cat("--- Calendar year of T0 (channeling) ---\n")
  print(year_dist)
  cat("\n")
}

# Verdict
ok <- sum(results$fitness == "OK", na.rm = TRUE)
partial <- sum(results$fitness == "Partial", na.rm = TRUE)
weak <- sum(results$fitness == "Weak", na.rm = TRUE)
limited <- sum(results$fitness == "Limited", na.rm = TRUE)
missing <- sum(!results$present)

cat("--- Fitness summary ---\n")
cat("  OK (≥95% complete):     ", ok, " variables\n")
cat("  Partial (70–94%):      ", partial, " variables\n")
cat("  Weak (30–69%):         ", weak, " variables\n")
cat("  Limited (<30%):        ", limited, " variables\n")
cat("  Missing in dataset:    ", missing, " variables\n")
cat("\n")

t0_ok <- "second_line_start_date" %in% names(df) && sum(is.na(df$second_line_start_date)) == 0
regimen_ok <- "regimen_anchor" %in% names(df) && sum(!is.na(df$regimen_anchor)) / n >= 0.9
vl_ok <- "viral_suppressed" %in% names(df) | ("vl_status" %in% names(df) && sum(!is.na(df$vl_status)) / n >= 0.9)

if (t0_ok && regimen_ok && vl_ok) {
  cat("VERDICT: Data are FIT for initial descriptive and comparison analysis (T0, exposure, virological outcomes).\n")
  cat("         Report limitations for: clinical status (reason_for_exit/cause_of_death largely missing), baseline missingness (WHO, CD4, adherence).\n")
} else {
  cat("VERDICT: Review required. T0 or exposure or virological outcome has gaps; see table above.\n")
}

# -----------------------------------------------------------------------------
# 7. Write outputs
# -----------------------------------------------------------------------------
readr::write_csv(results, file.path(dataout_dir, "fitness_of_data_report.csv"))
cat("\nReport saved to", file.path(dataout_dir, "fitness_of_data_report.csv"), "\n")

# Optional: append inclusion criteria to report
inclusion_summary <- tibble(
  check = c("N cohort", "≥6 months ART by T0", "Has VL info (proxy ≥2 VLs)"),
  n = c(n, n_6mo, n_2vl),
  pct = c(100, pct_6mo, pct_2vl)
)
readr::write_csv(inclusion_summary, file.path(dataout_dir, "fitness_inclusion_checks.csv"))
cat("Inclusion checks saved to", file.path(dataout_dir, "fitness_inclusion_checks.csv"), "\n")
