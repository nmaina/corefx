# =============================================================================
# Check: Do we have enough data for clinical_status?
# Run this script to see which outcome/status variables exist and their completeness.
# =============================================================================
library(tidyverse)
library(janitor)
library(readxl)

data_path <- "Data/2ndline_Data request_4Nov2025_v1_shared.xlsx"
dataout_dir <- "Dataout"

# Read and clean names (same as read_clean_01.R)
df <- read_excel(data_path, sheet = 1, na = c("", "NA", "N/A", "NULL", " ", ".")) %>%
  as_tibble() %>%
  clean_names()

n_total <- nrow(df)

# Variables that can support clinical_status
status_vars <- c(
  "reason_for_exit",
  "clinical_status_sep2024",
  "clinical_status_mar2025"
)

# Which exist?
existing <- status_vars[status_vars %in% names(df)]
missing_vars <- setdiff(status_vars, names(df))

cat("--- Clinical status / reason_for_exit data check ---\n\n")
cat("Total rows:", n_total, "\n\n")

cat("Variables found in data:", paste(existing, collapse = ", "), "\n")
if (length(missing_vars) > 0)
  cat("Variables NOT in data:", paste(missing_vars, collapse = ", "), "\n\n")

# Summary per variable
summary_list <- list()
for (v in existing) {
  n_miss <- sum(is.na(df[[v]]))
  pct_miss <- round(100 * n_miss / n_total, 1)
  cat("---", v, "---\n")
  cat("  Non-missing:", n_total - n_miss, "(", 100 - pct_miss, "%)\n")
  cat("  Missing:   ", n_miss, "(", pct_miss, "%)\n")
  tbl <- table(df[[v]], useNA = "ifany")
  cat("  Distribution:\n")
  print(tbl)
  cat("\n")
  summary_list[[v]] <- tibble(
    variable = v,
    n_total = n_total,
    n_non_missing = n_total - n_miss,
    pct_complete = round(100 - pct_miss, 1),
    n_missing = n_miss
  )
}

# One-row verdict
summary_tbl <- bind_rows(summary_list)
if (nrow(summary_tbl) == 0) {
  cat("CONCLUSION: No reason_for_exit or clinical_status_* variables found in the data.\n")
  cat("You need to request one of these from the data team.\n")
} else {
  best <- summary_tbl %>% filter(pct_complete == max(pct_complete)) %>% slice(1)
  cat("CONCLUSION: Best available variable for clinical_status:", best$variable, "\n")
  cat("  Completeness:", best$pct_complete, "% (", best$n_non_missing, "of", n_total, "rows)\n")
  if (best$pct_complete < 80)
    cat("  WARNING: Consider asking data team to improve completeness or clarify definition.\n")
}

# Save summary
readr::write_csv(summary_tbl, file.path(dataout_dir, "clinical_status_data_check.csv"))
cat("\nSummary written to", file.path(dataout_dir, "clinical_status_data_check.csv"), "\n")
