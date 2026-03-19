# second_line_full_pipeline.R
# End-to-end pipeline:
#   1) Read AMRS Excel extract
#   2) Clean and normalize key variables
#   3) Parse VL history (vl_history_after_switch) into long format + deduplicate
#   4) Build df_study cohort (eligibility and T0)
#   5) Objective 1-3: descriptive tables + log-binomial models (with RR output)
#   6) Objective 4: OI burden in virological failure subset
# Resistance mutation frequencies are scaffolded (requires a merged genotype file).
#
# NOTE:
# - This script assumes the Excel sheet has the columns corresponding to your
#   AMRS variable names after clean_names().
# - It recomputes VL outcomes inside the study window from vl_history_after_switch
#   to avoid problems where latest_vl_date extends beyond study end.
#
# Run:
#   Rscript Scripts/second_line_full_pipeline.R --data "Data/2ndline_Data request_25Feb2026_.xlsx"
#
# Optional flags:
#   --study-start "2018-10-01"
#   --study-end   "2024-09-30"
#

suppressPackageStartupMessages({
  library(tidyverse)
  library(janitor)
  library(lubridate)
  library(readxl)
  library(stringr)
  library(ggplot2)
})

# =========================
# 0) Runtime configuration
# =========================
args <- commandArgs(trailingOnly = TRUE)

write_csv_safe <- function(x, path) {
  tryCatch(
    {
      readr::write_csv(x, path)
      return(invisible(path))
    },
    error = function(e) {
      alt <- sub(
        "\\.csv$",
        paste0("_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"),
        path
      )
      readr::write_csv(x, alt)
      message("Could not overwrite (file may be open). Wrote instead:\n  ", alt)
      return(invisible(alt))
    }
  )
}

get_arg <- function(flag, default = NULL) {
  if (!flag %in% args) return(default)
  i <- which(args == flag)[1]
  if (is.na(i) || i == length(args)) return(default)
  args[i + 1]
}

data_path <- get_arg("--data", "Data/2ndline_Data request_25Feb2026_.xlsx")
study_start <- as.Date(get_arg("--study-start", "2018-10-01"))
study_end <- as.Date(get_arg("--study-end", "2024-09-30"))

# Project root: Script/.. so relative paths work
argv0 <- commandArgs(trailingOnly = FALSE)[1]
script_path <- suppressWarnings(normalizePath(argv0, winslash = "/", mustWork = FALSE))
script_dir <- if (!is.na(script_path) && file.exists(script_path)) dirname(script_path) else getwd()
proj_root <- suppressWarnings(normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = FALSE))
if (is.na(proj_root) || !dir.exists(proj_root)) proj_root <- getwd()

# Resolve data_path relative to project root if needed
data_candidates <- unique(c(
  data_path,
  file.path(proj_root, data_path),
  file.path(getwd(), data_path)
))

data_path_abs <- NULL
for (cand in data_candidates) {
  if (!is.na(cand) && file.exists(cand)) {
    data_path_abs <- suppressWarnings(normalizePath(cand, winslash = "/", mustWork = TRUE))
    break
  }
}
if (is.null(data_path_abs)) {
  stop("Could not find data file. Tried:\n- ", paste(data_candidates, collapse = "\n- "))
}

data_path <- data_path_abs

# Derive project root from the resolved data file path (expected: .../project/Data/<file>)
proj_root <- suppressWarnings(normalizePath(file.path(dirname(dirname(data_path)), ""), winslash = "/", mustWork = FALSE))
if (!is.na(proj_root) && dir.exists(proj_root)) {
  setwd(proj_root)
  dataout_dir <- file.path(proj_root, "Dataout", "pipeline_outputs_one_script")
  if (!dir.exists(dataout_dir)) dir.create(dataout_dir, recursive = TRUE)
}
cat("Input:", data_path, "\n")
cat("Study window:", as.character(study_start), "to", as.character(study_end), "\n")

na_codes <- c("", "NA", "N/A", "NULL", " ", ".", "Not_documented", "Not Documented")

# ==================================
# 1) Read source extract (sheet = 2)
# ==================================
data_path_read <- data_path
tmp_xlsx <- tempfile(fileext = ".xlsx")
copied_to_tmp <- tryCatch({
  file.copy(data_path, tmp_xlsx, overwrite = TRUE)
}, error = function(e) FALSE)

# If the original Excel is locked by another process (often OneDrive/Excel),
# reading a temporary copy tends to work better.
if (isTRUE(copied_to_tmp) && file.exists(tmp_xlsx)) {
  data_path_read <- tmp_xlsx
  cat("Read: using temporary Excel copy to avoid file locks.\n")
}

df_raw <- tryCatch(
  read_excel(
    data_path_read,
    sheet = 2,
    na = na_codes
  ) %>%
    as_tibble() %>%
    clean_names(),
  error = function(e) {
    stop(
      "Failed to read the Excel file with readxl.\n",
      "This often happens if the file is open in Excel or still syncing in OneDrive.\n",
      "Please close the Excel file and ensure OneDrive sync is complete, then re-run.\n",
      "Original error: ", conditionMessage(e)
    )
  }
)

if (identical(data_path_read, tmp_xlsx) && file.exists(tmp_xlsx)) {
  unlink(tmp_xlsx)
}

# -------------------------------
# 1) Select and rename variables
# -------------------------------
# These renames match the cleaned names used earlier in your project.
rename_map <- list(
  de_identified = "de_identified_client_id",
  birthdate = "date_of_birth",
  gender = "sex",
  first_line_start_date = "date_of_art_initiation",
  second_line_start_date = "date_of_switch_to_second_line_art",
  arv_regimen_2nd_line_start = "second_line_regimen_dtg_based_or_pi_based",
  # Pre-switch VLs (if present)
  vl1_before_switch = "vl1_before_switch",
  vl1_date_before_switch = "vl1_date_before_switch",
  vl2_before_switch = "vl2_before_switch",
  vl2_date_before_switch = "vl2_date_before_switch",
  baseline_viral_load_result = "baseline_viral_load_result",
  baseline_viral_load_date = "baseline_viral_load_date",
  baseline_cd4 = "baseline_cd4_count_cells_mm3",
  who_stage = "who_stage_at_diagnosis_stage_i_iv",
  advanced_hiv_disease = "advanced_hiv_disease_yes_no_cd4_200_or_who_stage_iii_iv",
  opportunistic_infections = "presence_of_opportunistic_infections",
  adherence_rating = "adherence_rating_at_switch",
  morisky_mmas8 = "morisky_mmas8",
  morisky_mmas4 = "morisky_mmas4",
  date_hiv_diagnosis = "date_of_hiv_diagnosis",
  latest_vl = "latest_vl",
  latest_vl_date = "latest_vl_date",
  vl_status = "vl_status",
  vl_history_after_switch = "vl_history_after_switch",
  # Longitudinal refill data after switch (Excel column BC)
  art_refill_duration_history_after_switch = "art_refill_duration_history_after_switch",
  clinical_status_sep2024 = "clinical_status_sep2024",
  # After clean_names(), this column is usually "cause_of_death_if_applicable"
  cause_of_death = "cause_of_death_if_applicable",
  # OI burden (for failures)
  date_of_oi_diagnosis = "date_of_oi_diagnosis",
  oii_condition_specify = "opportunistic_infections_diagnosed_specify_condition",
  oii_treatment_started = "oi_treatment_initiated",
  # After clean_names(), this column is usually "confirmed_tb_after_switch_1_yes_0_no"
  confirmed_tb_after_switch = "confirmed_tb_after_switch_1_yes_0_no",
  tb_treatment_start_date = "tb_treatment_start_date",
  tb_treatment_started = "tb_treatment_started",
  # For failure definitions / extra context
  reason_for_switch = "reason_for_switch"
)

missing_in_excel <- names(rename_map)[!(unlist(rename_map) %in% names(df_raw))]

## Rename in-place so we don't carry duplicates of "old" + "new" variables.
## - rename_map is named as: new_name -> old_name
## - we only rename those old_name columns that actually exist
rename_map_existing <- rename_map[names(rename_map)[unlist(rename_map) %in% names(df_raw)]]
df <- df_raw %>% rename(!!!rename_map_existing)

# For expected columns that aren't in the Excel extract, create them as NA
missing_new <- setdiff(names(rename_map), names(rename_map_existing))
if (length(missing_new) > 0) {
  warning(
    "Excel missing expected columns (will be created as NA): ",
    paste(missing_new, collapse = ", ")
  )
  for (new_nm in missing_new) df[[new_nm]] <- NA
}

df <- df %>%
  mutate(
    # Enforce core types
    de_identified = as.character(de_identified),
    birthdate = as.Date(birthdate),
    first_line_start_date = as.Date(first_line_start_date),
    second_line_start_date = as.Date(second_line_start_date),
    latest_vl_date = as.Date(latest_vl_date),
    baseline_cd4 = suppressWarnings(as.numeric(baseline_cd4)),
    weight_kg = suppressWarnings(as.numeric(weight_kg)),
    height_cm = suppressWarnings(as.numeric(height_cm)),
    bmi = suppressWarnings(as.numeric(bmi)),
    systolic_bp = suppressWarnings(as.numeric(systolic_bp)),
    diastolic_bp = suppressWarnings(as.numeric(diastolic_bp)),
    adherence_rating = as.character(adherence_rating),
    morisky_mmas8 = suppressWarnings(as.numeric(morisky_mmas8)),
    morisky_mmas4 = suppressWarnings(as.numeric(morisky_mmas4)),
    date_hiv_diagnosis = as.Date(date_hiv_diagnosis),
    vl1_before_switch = suppressWarnings(as.numeric(vl1_before_switch)),
    vl2_before_switch = suppressWarnings(as.numeric(vl2_before_switch)),
    baseline_viral_load_result = suppressWarnings(as.numeric(baseline_viral_load_result)),
    vl1_date_before_switch = as.Date(vl1_date_before_switch),
    vl2_date_before_switch = as.Date(vl2_date_before_switch),
    baseline_viral_load_date = as.Date(baseline_viral_load_date)
  )

# Gender harmonization (robust to F/M encodings)
df <- df %>%
  mutate(
    gender = case_when(
      stringr::str_to_upper(as.character(gender)) %in% c("F", "FEMALE") ~ "Female",
      stringr::str_to_upper(as.character(gender)) %in% c("M", "MALE") ~ "Male",
      TRUE ~ NA_character_
    ),
    gender = factor(gender, levels = c("Female", "Male"))
  )

# Keep only study-variable columns plus VL history
keep_cols <- c(
  "de_identified", "birthdate", "gender",
  "first_line_start_date", "second_line_start_date",
  "arv_regimen_2nd_line_start",
  "vl1_before_switch", "vl1_date_before_switch",
  "vl2_before_switch", "vl2_date_before_switch",
  "baseline_viral_load_result", "baseline_viral_load_date",
  "baseline_cd4", "who_stage", "advanced_hiv_disease",
  "adherence_rating", "morisky_mmas8", "morisky_mmas4",
  "date_hiv_diagnosis",
  "latest_vl", "latest_vl_date", "vl_status",
  "vl_history_after_switch",
  "art_refill_duration_history_after_switch",
  "clinical_status_sep2024", "cause_of_death",
  "reason_for_switch",
  "opportunistic_infections", "date_of_oi_diagnosis", "oii_condition_specify",
  "oii_treatment_started", "confirmed_tb_after_switch", "tb_treatment_start_date",
  "tb_treatment_started",
  # plus some optional baseline vitals if present in df_raw
  intersect(c("weight_kg", "height_cm", "bmi", "systolic_bp", "diastolic_bp"), names(df))
)
df <- df %>% select(any_of(keep_cols))

# ---------------------------------
# 2) Helpers: parsing and outcomes
# ---------------------------------

excel_numeric_date_to_date <- function(x) {
  # If x is numeric serial, convert using Excel origin 1899-12-30
  if (is.numeric(x)) return(as.Date(x, origin = "1899-12-30"))
  x
}

to_date_mixed <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (is.numeric(x)) return(excel_numeric_date_to_date(x))
  if (is.character(x)) {
    parsed <- suppressWarnings(lubridate::parse_date_time(
      x,
      orders = c("ymd", "Ymd", "dmy", "dmY", "mdy", "mdY"),
      exact = FALSE
    ))
    return(as.Date(parsed))
  }
  as.Date(x)
}

# Parse vl_history_after_switch cell into long tibble: vl_date, vl_value
parse_vl_history_cell <- function(history_cell) {
  if (is.na(history_cell)) {
    return(tibble(vl_date = as.Date(character()), vl_value = numeric()))
  }
  s <- as.character(history_cell)
  s <- str_trim(s)
  if (is.na(s) || s == "" || toupper(s) == "NULL") {
    return(tibble(vl_date = as.Date(character()), vl_value = numeric()))
  }

  # Split by '|'
  parts <- unlist(str_split(s, "\\|"))
  parts <- str_trim(parts)
  parts <- parts[parts != ""]
  if (length(parts) == 0) {
    return(tibble(vl_date = as.Date(character()), vl_value = numeric()))
  }

  # Extract date and value from each part; expect "...YYYY-MM-DD;VALUE..." somewhere in part
  date_str <- str_extract(parts, "\\d{4}-\\d{2}-\\d{2}")
  val_str <- str_extract(parts, ";\\s*[-+]?[0-9]*\\.?[0-9]+")
  val_str <- ifelse(is.na(val_str), NA_character_, str_replace(val_str, "^;\\s*", ""))

  tibble(
    vl_date = as.Date(date_str),
    vl_value = suppressWarnings(as.numeric(val_str))
  ) %>%
    filter(!is.na(vl_date) & !is.na(vl_value))
}

# Parse art_refill_duration_history_after_switch cell into long tibble: refill_date, days_dispensed
# Expected format: "YYYY-MM-DD;14 | YYYY-MM-DD;28 | ..."
parse_refill_history_cell <- function(history_cell) {
  if (is.na(history_cell)) {
    return(tibble(refill_date = as.Date(character()), days_dispensed = numeric()))
  }
  s <- as.character(history_cell)
  s <- str_trim(s)
  if (is.na(s) || s == "" || toupper(s) == "NULL") {
    return(tibble(refill_date = as.Date(character()), days_dispensed = numeric()))
  }

  parts <- unlist(str_split(s, "\\|"))
  parts <- str_trim(parts)
  parts <- parts[parts != ""]
  if (length(parts) == 0) {
    return(tibble(refill_date = as.Date(character()), days_dispensed = numeric()))
  }

  date_str <- str_extract(parts, "\\d{4}-\\d{2}-\\d{2}")
  days_str <- str_extract(parts, ";\\s*[-+]?[0-9]*\\.?[0-9]+")
  days_str <- ifelse(is.na(days_str), NA_character_, str_replace(days_str, "^;\\s*", ""))

  tibble(
    refill_date = as.Date(date_str),
    days_dispensed = suppressWarnings(as.numeric(days_str))
  ) %>%
    filter(!is.na(refill_date) & !is.na(days_dispensed))
}

make_regimen_anchor <- function(x) {
  s <- stringr::str_to_lower(as.character(x))
  case_when(
    str_detect(s, "dtg|dolutegravir") ~ "DTG",
    str_detect(s, "atv|lop|drv|pi\\b|ritonavir|lpv|boost") ~ "PI",
    TRUE ~ NA_character_
  )
}

make_nrti_backbone <- function(x) {
  s <- toupper(as.character(x))
  case_when(
    str_detect(s, "TDF") ~ "TDF",
    str_detect(s, "AZT") ~ "AZT",
    str_detect(s, "ABC") ~ "ABC",
    TRUE ~ "Other"
  )
}

make_status <- function(clin_sep2024, cause_of_death) {
  cs_low <- tolower(trimws(as.character(clin_sep2024)))
  cd <- toupper(trimws(as.character(cause_of_death)))
  has_cod <- !is.na(cd) & cd != "" & cd != "NULL" & cd != "NOT_DOCUMENTED"

  case_when(
    str_detect(cs_low, "died|death|dead") ~ "Died",
    has_cod ~ "Died",
    str_detect(cs_low, "transfer") ~ "Transferred out",
    str_detect(cs_low, "ltfu|lost") ~ "LTFU/other",
    str_detect(cs_low, "active") ~ "Active",
    TRUE ~ "Other"
  )
}

merge_intervals_length <- function(starts, ends) {
  # Returns total length (days) of union of closed intervals [start, end]
  if (length(starts) == 0) return(0)
  ord <- order(starts, ends, na.last = NA)
  s <- as.Date(starts[ord])
  e <- as.Date(ends[ord])
  s <- s[!is.na(s) & !is.na(e)]
  e <- e[!is.na(s) & !is.na(e)]
  if (length(s) == 0) return(0)

  total <- 0
  cur_s <- s[1]
  cur_e <- e[1]
  if (cur_e < cur_s) {
    tmp <- cur_s
    cur_s <- cur_e
    cur_e <- tmp
  }

  if (length(s) > 1) {
    for (i in 2:length(s)) {
      si <- s[i]
      ei <- e[i]
      if (ei < si) {
        tmp <- si
        si <- ei
        ei <- tmp
      }
      # merge if overlapping or adjacent
      if (si <= (cur_e + 1)) {
        cur_e <- max(cur_e, ei, na.rm = TRUE)
      } else {
        total <- total + (as.numeric(cur_e - cur_s) + 1)
        cur_s <- si
        cur_e <- ei
      }
    }
  }
  total <- total + (as.numeric(cur_e - cur_s) + 1)
  total
}

# ---------------------------------
# 3) Parse VL history into long df
# ---------------------------------
cat("Parsing VL history (vl_history_after_switch)...\n")

vl_long <- df %>%
  select(de_identified, vl_history_after_switch) %>%
  mutate(vl_parsed = purrr::map(vl_history_after_switch, parse_vl_history_cell)) %>%
  select(de_identified, vl_parsed) %>%
  tidyr::unnest(vl_parsed) %>%
  distinct(de_identified, vl_date, vl_value)

cat("VL long rows:", nrow(vl_long), "\n")

# Within study window
vl_in_window <- vl_long %>%
  filter(!is.na(vl_date), vl_date >= study_start, vl_date <= study_end)

vl_counts <- vl_in_window %>%
  group_by(de_identified) %>%
  summarise(n_vl_in_window = n_distinct(vl_date), .groups = "drop")

vl_latest <- vl_in_window %>%
  group_by(de_identified) %>%
  slice_max(order_by = vl_date, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  transmute(de_identified, latest_vl_date_in_window = vl_date, latest_vl_in_window = vl_value)

cat("Parsing ART refill history (art_refill_duration_history_after_switch)...\n")
refill_long <- df %>%
  select(de_identified, art_refill_duration_history_after_switch) %>%
  mutate(refill_parsed = purrr::map(art_refill_duration_history_after_switch, parse_refill_history_cell)) %>%
  select(de_identified, refill_parsed) %>%
  tidyr::unnest(refill_parsed) %>%
  distinct(de_identified, refill_date, days_dispensed) %>%
  mutate(
    refill_date = as.Date(refill_date),
    days_dispensed = suppressWarnings(as.numeric(days_dispensed))
  ) %>%
  filter(!is.na(refill_date) & !is.na(days_dispensed) & days_dispensed >= 0)

refill_dedup <- refill_long %>%
  group_by(de_identified, refill_date) %>%
  summarise(days_dispensed = max(days_dispensed, na.rm = TRUE), .groups = "drop") %>%
  mutate(
    interval_start = refill_date,
    interval_end = refill_date + pmax(0, round(days_dispensed) - 1)
  )

refill_pdc <- refill_dedup %>%
  mutate(
    window_start = as.Date(study_start),
    window_end = as.Date(study_end),
    overlap_start = pmax(interval_start, window_start),
    overlap_end = pmin(interval_end, window_end),
    covered_days = pmax(0, as.numeric(overlap_end - overlap_start) + 1)
  ) %>%
  group_by(de_identified) %>%
  summarise(
    refill_covered_days_in_window = merge_intervals_length(
      overlap_start[covered_days > 0],
      overlap_end[covered_days > 0]
    ),
    refill_events_in_window = sum(covered_days > 0, na.rm = TRUE),
    .groups = "drop"
  )

# Additional refill-based continuity metrics (proxy disengagement / gaps)
refill_continuity <- refill_dedup %>%
  arrange(de_identified, interval_start, interval_end) %>%
  group_by(de_identified) %>%
  mutate(
    next_start = lead(interval_start),
    gap_days_to_next = pmax(0, as.numeric(next_start - interval_end) - 1)
  ) %>%
  summarise(
    last_refill_date = suppressWarnings(max(interval_start, na.rm = TRUE)),
    last_refill_end_date = suppressWarnings(max(interval_end, na.rm = TRUE)),
    max_gap_days_between_refills = suppressWarnings(max(gap_days_to_next, na.rm = TRUE)),
    any_gap_ge_30 = any(!is.na(gap_days_to_next) & gap_days_to_next >= 30),
    any_gap_ge_60 = any(!is.na(gap_days_to_next) & gap_days_to_next >= 60),
    any_gap_ge_90 = any(!is.na(gap_days_to_next) & gap_days_to_next >= 90),
    .groups = "drop"
  ) %>%
  mutate(
    days_since_refill_end_at_study_end = as.numeric(as.Date(study_end) - last_refill_end_date)
  )

# -----------------------------------------------------------------------------
# Virological failure definition (Kenya guideline style)
# Confirmed VF: TWO VL results > 1000 copies/mL at least 90 days apart
# Pending confirmation: exactly ONE elevated VL (>1000) with no confirming second test
# Not failing: everything else
# -----------------------------------------------------------------------------
vf_elevated <- vl_in_window %>%
  filter(vl_value > 1000) %>%
  arrange(de_identified, vl_date) %>%
  group_by(de_identified) %>%
  mutate(
    next_elevated_date = lead(vl_date),
    gap_days = as.numeric(next_elevated_date - vl_date)
  ) %>%
  ungroup()

vf_status <- vf_elevated %>%
  group_by(de_identified) %>%
  summarise(
    n_elevated_vls = n(),
    vf_confirmed = any(!is.na(gap_days) & gap_days >= 90),
    .groups = "drop"
  )

# -----------------------------
# 4) Build derived patient vars
# -----------------------------

df2 <- df %>%
  mutate(
    second_line_start_date = as.Date(second_line_start_date),
    first_line_start_date = as.Date(first_line_start_date),
    date_hiv_diagnosis = to_date_mixed(date_hiv_diagnosis),
    vl1_date_before_switch = to_date_mixed(vl1_date_before_switch),
    vl2_date_before_switch = to_date_mixed(vl2_date_before_switch),
    baseline_viral_load_date = to_date_mixed(baseline_viral_load_date),
    regimen_anchor = make_regimen_anchor(arv_regimen_2nd_line_start),
    nrti_backbone = make_nrti_backbone(arv_regimen_2nd_line_start)
  ) %>%
  left_join(vl_counts, by = "de_identified") %>%
  left_join(vl_latest, by = "de_identified") %>%
  left_join(refill_pdc, by = "de_identified") %>%
  left_join(refill_continuity, by = "de_identified") %>%
  left_join(vf_status, by = "de_identified") %>%
  mutate(
    has_2_vl_in_window = !is.na(n_vl_in_window) & n_vl_in_window >= 2,
    viral_suppressed_in_window = !is.na(latest_vl_in_window) & latest_vl_in_window < 200,
    vf_confirmed = replace_na(vf_confirmed, FALSE),
    n_elevated_vls = replace_na(n_elevated_vls, 0L),
    vf_pending = !vf_confirmed & n_elevated_vls == 1,
    vf_not_failing = !vf_confirmed & !vf_pending,
    years_since_hiv_diagnosis = if_else(
      !is.na(date_hiv_diagnosis) & !is.na(second_line_start_date),
      as.numeric(second_line_start_date - date_hiv_diagnosis) / 365.25,
      NA_real_
    ),
    status = make_status(clinical_status_sep2024, cause_of_death),
    clinical_status = status,
    # Baseline VL at/around switch (if available in extract)
    baseline_vl_at_switch = coalesce(baseline_viral_load_result, vl2_before_switch, vl1_before_switch),
    baseline_vl_date_at_switch = coalesce(baseline_viral_load_date, vl2_date_before_switch, vl1_date_before_switch),
    baseline_vl_at_switch = if_else(
      !is.na(baseline_vl_at_switch) & baseline_vl_at_switch >= 0 & baseline_vl_at_switch <= 1e8,
      as.numeric(baseline_vl_at_switch),
      NA_real_
    ),
    baseline_vl_date_at_switch = to_date_mixed(baseline_vl_date_at_switch),
    baseline_vl_date_at_switch = if_else(
      !is.na(baseline_vl_date_at_switch) &
        baseline_vl_date_at_switch >= as.Date("1990-01-01") &
        baseline_vl_date_at_switch <= (as.Date(second_line_start_date) + 365),
      baseline_vl_date_at_switch,
      as.Date(NA)
    ),
    adherence_cat_at_switch = case_when(
      is.na(morisky_mmas8) | morisky_mmas8 == 0 ~ NA_character_,
      morisky_mmas8 >= 8 ~ "High",
      morisky_mmas8 >= 6 ~ "Medium",
      morisky_mmas8 > 0 ~ "Low",
      TRUE ~ NA_character_
    ),
    adherence_cat_at_switch = factor(
      adherence_cat_at_switch,
      levels = c("Low", "Medium", "High")
    ),
    adherence_cat_mmas4 = case_when(
      is.na(morisky_mmas4) ~ NA_character_,
      morisky_mmas4 >= 4 ~ "High",
      morisky_mmas4 >= 3 ~ "Medium",
      morisky_mmas4 >= 0 ~ "Low",
      TRUE ~ NA_character_
    ),
    adherence_cat_mmas4 = factor(
      adherence_cat_mmas4,
      levels = c("Low", "Medium", "High")
    ),
    followup_days_in_window = pmax(0, as.numeric(as.Date(study_end) - pmax(as.Date(second_line_start_date), as.Date(study_start))) + 1),
    pdc_in_window = if_else(
      followup_days_in_window > 0,
      pmin(1, refill_covered_days_in_window / followup_days_in_window),
      NA_real_
    ),
    pdc_cat = case_when(
      is.na(pdc_in_window) ~ NA_character_,
      pdc_in_window >= 0.95 ~ ">=0.95",
      pdc_in_window >= 0.80 ~ "0.80-0.94",
      TRUE ~ "<0.80"
    ),
    pdc_cat = factor(pdc_cat, levels = c("<0.80", "0.80-0.94", ">=0.95")),
    regimen_anchor = factor(regimen_anchor, levels = c("DTG", "PI")),
    nrti_backbone = factor(nrti_backbone, levels = c("TDF", "AZT", "ABC")),
    # Confirmed virological failure
    virological_failure = vf_confirmed
  )

# -----------------------------
# 5) Cohort restriction / CONSORT logging
# -----------------------------
cat("Building cohort...\n")

consort <- tibble(step = character(), n = integer())

add_consort <- function(step, n) {
  consort <<- bind_rows(consort, tibble(step = step, n = n))
}

df_cohort0 <- df2 %>%
  filter(!is.na(de_identified))
add_consort("Non-missing ID", nrow(df_cohort0))

df_cohort1 <- df_cohort0 %>%
  filter(!is.na(second_line_start_date) & second_line_start_date >= study_start & second_line_start_date <= study_end)
add_consort(paste0("Switch in window [", study_start, ", ", study_end, "]"), nrow(df_cohort1))

df_cohort2 <- df_cohort1 %>%
  mutate(first_line_days = as.numeric(second_line_start_date - first_line_start_date)) %>%
  filter(!is.na(first_line_days) & first_line_days >= 180)
add_consort("First-line duration >= 6 months", nrow(df_cohort2))

df_cohort3 <- df_cohort2 %>%
  filter(has_2_vl_in_window)
add_consort("At least 2 VL dates in window", nrow(df_cohort3))

df_study <- df_cohort3
cat("df_study N:", nrow(df_study), "\n")

write_csv(consort, file.path(dataout_dir, "consort_cohort_flow.csv"))

# Extra derived variables used in downstream reporting
df_study <- df_study %>%
  mutate(
    age_second_line = as.numeric(second_line_start_date - birthdate) / 365.25,
    age_category = case_when(
      age_second_line < 15 ~ "Child/Adolescent (<15)",
      age_second_line < 25 ~ "Young adult (15-24)",
      TRUE ~ "Adult (>=25)"
    ),
    age_category = factor(
      age_category,
      levels = c("Child/Adolescent (<15)", "Young adult (15-24)", "Adult (>=25)")
    ),
    viraemic_at_switch = case_when(
      !is.na(baseline_vl_at_switch) & baseline_vl_at_switch > 1000 ~ "Yes",
      !is.na(baseline_vl_at_switch) & baseline_vl_at_switch <= 1000 ~ "No",
      TRUE ~ NA_character_
    ),
    viraemic_at_switch = factor(viraemic_at_switch, levels = c("No", "Yes"))
  )

# Save cohort for downstream analysis
saveRDS(df_study, file.path(dataout_dir, "df_study.rds"))

cat("\n=== Missing data in key model variables ===\n")
df_study %>%
  select(
    regimen_anchor, nrti_backbone, baseline_cd4, who_stage,
    viraemic_at_switch, pdc_cat, gender,
    baseline_vl_at_switch, years_since_hiv_diagnosis,
    adherence_cat_at_switch,
    viral_suppressed_in_window
  ) %>%
  summarise(across(everything(), ~ sum(is.na(.x)))) %>%
  pivot_longer(
    everything(),
    names_to = "variable",
    values_to = "n_missing"
  ) %>%
  mutate(pct = round(100 * n_missing / nrow(df_study), 1)) %>%
  arrange(desc(n_missing)) %>%
  print(n = 20)

# ---------------------------------------
# 6) Objective 1: Baseline Table by DTG/PI
# ---------------------------------------
cat("Objective 1: Baseline table...\n")

tab_median_iqr <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NA_character_)
  med <- median(x)
  q1 <- quantile(x, 0.25)
  q3 <- quantile(x, 0.75)
  sprintf("%.1f (%.1f-%.1f)", med, q1, q3)
}

tab_cat <- function(df_in, var) {
  v <- df_in[[var]]
  v <- as.character(v)
  out <- df_in %>%
    summarise(
      n_non_na = sum(!is.na(.data[[var]])),
      tab = list(count(data.frame(v), v) %>% rename(value = v, n = n))
    )
  # not used
  NULL
}

df_reg <- df_study %>% filter(regimen_anchor %in% c("DTG", "PI"))

baseline_cont <- c("age_second_line", "first_line_start_date", "baseline_cd4", "years_since_hiv_diagnosis")
# Derive age and categories
df_reg <- df_reg %>%
  mutate(
    age_second_line = as.numeric(second_line_start_date - birthdate) / 365.25,
    cd4_cat = case_when(
      !is.na(baseline_cd4) & baseline_cd4 < 200 ~ "<200",
      !is.na(baseline_cd4) & baseline_cd4 < 350 ~ "200-349",
      !is.na(baseline_cd4) & baseline_cd4 < 500 ~ "350-499",
      !is.na(baseline_cd4) & baseline_cd4 >= 500 ~ ">=500",
      TRUE ~ NA_character_
    ),
    bmi_cat = case_when(
      !is.na(bmi) & bmi < 18.5 ~ "Underweight",
      !is.na(bmi) & bmi < 25 ~ "Normal",
      !is.na(bmi) & bmi < 30 ~ "Overweight",
      !is.na(bmi) & bmi >= 30 ~ "Obese",
      TRUE ~ NA_character_
    )
  )

# Table rows (simple CSV output)
make_table1 <- function(df_in, cont_vars, cat_vars, cat_var_labels = NULL) {
  out <- list()

  for (v in cont_vars) {
    if (!v %in% names(df_in)) next
    med_all <- tab_median_iqr(df_in[[v]])
    dtg_med <- tab_median_iqr(df_in %>% filter(regimen_anchor == "DTG") %>% pull(!!sym(v)))
    pi_med <- tab_median_iqr(df_in %>% filter(regimen_anchor == "PI") %>% pull(!!sym(v)))
    p <- tryCatch(
      wilcox.test(df_in[[v]] ~ df_in$regimen_anchor)$p.value,
      error = function(e) NA_real_
    )
    out[[length(out) + 1]] <- tibble(
      variable = v,
      level = "",
      Overall = med_all,
      DTG = dtg_med,
      PI = pi_med,
      p_value = round(p, 3)
    )
  }

  for (v in cat_vars) {
    if (!v %in% names(df_in)) next
    v_disp <- if (!is.null(cat_var_labels) && v %in% names(cat_var_labels)) {
      unname(cat_var_labels[[v]])
    } else {
      v
    }
    tab_all <- df_in %>%
      count(!!sym(v), name = "n") %>%
      mutate(pct = round(100 * n / sum(n), 1),
             Overall = paste0(n, " (", pct, "%)"),
             variable = if_else(row_number() == 1L, v_disp, ""),
             level = as.character(!!sym(v))) %>%
      select(variable, level, Overall)

    tab_dtg <- df_in %>%
      filter(regimen_anchor == "DTG") %>%
      count(!!sym(v), name = "n") %>%
      mutate(pct = round(100 * n / sum(n), 1),
             value = paste0(n, " (", pct, "%)"),
             level = as.character(!!sym(v))) %>%
      select(level, DTG = value)

    tab_pi <- df_in %>%
      filter(regimen_anchor == "PI") %>%
      count(!!sym(v), name = "n") %>%
      mutate(pct = round(100 * n / sum(n), 1),
             value = paste0(n, " (", pct, "%)"),
             level = as.character(!!sym(v))) %>%
      select(level, PI = value)

    merged <- tab_all %>%
      left_join(tab_dtg, by = "level") %>%
      left_join(tab_pi, by = "level")

    p <- tryCatch(
      chisq.test(table(df_in[[v]], df_in$regimen_anchor))$p.value,
      error = function(e) NA_real_
    )
    merged <- merged %>%
      mutate(p_value = if_else(row_number() == 1L, round(p, 3), NA_real_))

    out[[length(out) + 1]] <- merged
  }

  bind_rows(out)
}

# Do NOT add morisky_mmas8 / morisky_mmas4 here — numeric scores create one row per distinct value in Excel.
cat_vars <- c(
  "gender", "age_category",
  "who_stage", "cd4_cat", "bmi_cat",
  "nrti_backbone",
  "viraemic_at_switch",
  "pdc_cat",
  "adherence_rating", "adherence_cat_at_switch", "adherence_cat_mmas4"
)
cont_vars <- c("age_second_line", "baseline_cd4", "years_since_hiv_diagnosis")

tab1 <- make_table1(
  df_reg,
  cont_vars = cont_vars,
  cat_vars = cat_vars,
  cat_var_labels = c(
    adherence_cat_at_switch = "Adherence (MMAS-8 at switch)",
    adherence_cat_mmas4 = "Adherence (MMAS-4)",
    adherence_rating = "Adherence rating (clinician)",
    pdc_cat = "Refill adherence (PDC)"
  )
)
tab1_path <- file.path(dataout_dir, "Objective1_Table1_baseline_DTG_vs_PI.csv")
ok_csv <- tryCatch(
  {
    write_csv(tab1, tab1_path)
    TRUE
  },
  error = function(e) {
    alt <- file.path(
      dataout_dir,
      paste0("Objective1_Table1_baseline_DTG_vs_PI_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
    )
    write_csv(tab1, alt)
    message(
      "Could not overwrite Table 1 CSV (close Excel if the file is open). Wrote instead:\n  ", alt
    )
    FALSE
  }
)
if (ok_csv) {
  cat(
    "\n>>> Table 1 (Low/Medium/High adherence): ",
    normalizePath(tab1_path, winslash = "/"),
    "\n    Open THIS file — not a sheet built from raw morisky_mmas8/morisky_mmas4 columns.\n\n"
  )
}
if (requireNamespace("writexl", quietly = TRUE)) {
  xlsx_path <- file.path(dataout_dir, "Objective1_Table1_baseline_DTG_vs_PI.xlsx")
  tryCatch(
    writexl::write_xlsx(list(Table1_DTG_vs_PI = tab1), xlsx_path),
    error = function(e) message("Could not write .xlsx (file may be open in Excel).")
  )
}

# -----------------------------------------------------------
# Objective 1 supplementary descriptive outputs (proposal-led)
# -----------------------------------------------------------
# Additional descriptive outputs used in proposal
clinical_outcomes <- df_study %>%
  filter(regimen_anchor %in% c("DTG", "PI")) %>%
  count(regimen_anchor, clinical_status, name = "n") %>%
  group_by(regimen_anchor) %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  ungroup()
write_csv_safe(clinical_outcomes, file.path(dataout_dir, "Objective1_Clinical_outcomes_by_regimen.csv"))

supp_by_age <- df_study %>%
  filter(regimen_anchor %in% c("DTG", "PI")) %>%
  count(age_category, regimen_anchor, viral_suppressed_in_window, name = "n") %>%
  group_by(age_category, regimen_anchor) %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  ungroup()
write_csv_safe(supp_by_age, file.path(dataout_dir, "Objective1_Suppression_by_age_category_and_regimen.csv"))

viraemic_tab <- df_study %>%
  count(viraemic_at_switch, viral_suppressed_in_window, name = "n") %>%
  group_by(viraemic_at_switch) %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  ungroup()
write_csv_safe(viraemic_tab, file.path(dataout_dir, "Objective1_Suppression_by_viraemic_at_switch.csv"))

# --------------------------------------------------------------------
# Objective 1 agreement check: self-report (MMAS-8) vs refill (PDC)
# --------------------------------------------------------------------
morisky_vs_pdc <- df_study %>%
  filter(!is.na(adherence_cat_at_switch), !is.na(pdc_cat)) %>%
  count(adherence_cat_at_switch, pdc_cat, name = "n") %>%
  group_by(adherence_cat_at_switch) %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  ungroup() %>%
  arrange(adherence_cat_at_switch, pdc_cat)

write_csv_safe(morisky_vs_pdc, file.path(dataout_dir, "Objective1_Morisky_vs_PDC_agreement.csv"))

cat("\n=== Morisky at switch vs PDC after switch ===\n")
print(morisky_vs_pdc)

# Optional agreement statistic (weighted kappa).
# Uses vcd if installed; skipped silently otherwise.
if (requireNamespace("vcd", quietly = TRUE)) {
  kappa_out <- tryCatch({
    agreement_tbl <- xtabs(n ~ adherence_cat_at_switch + pdc_cat, data = morisky_vs_pdc)
    kappa_fit <- vcd::Kappa(agreement_tbl)
    unweighted <- as.numeric(kappa_fit$Unweighted[1])
    weighted <- as.numeric(kappa_fit$Weighted[1])
    kappa_summary <- tibble(
      measure = c("Unweighted kappa", "Weighted kappa"),
      estimate = c(unweighted, weighted),
      interpretation = case_when(
        estimate < 0.20 ~ "Slight agreement",
        estimate < 0.40 ~ "Fair agreement",
        estimate < 0.60 ~ "Moderate agreement",
        estimate < 0.80 ~ "Substantial agreement",
        TRUE ~ "Almost perfect agreement"
      )
    )
    print(kappa_summary)
    write_csv_safe(
      kappa_summary,
      file.path(dataout_dir, "Objective1_Morisky_vs_PDC_kappa.csv")
    )
    TRUE
  }, error = function(e) {
    message("Kappa calculation skipped: ", conditionMessage(e))
    FALSE
  })
  if (isTRUE(kappa_out)) {
    cat("Wrote: Objective1_Morisky_vs_PDC_kappa.csv\n")
  }
}

# Figure: viral suppression by regimen anchor
fig1_df <- df_reg %>%
  filter(!is.na(viral_suppressed_in_window)) %>%
  count(regimen_anchor, viral_suppressed_in_window) %>%
  group_by(regimen_anchor) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  ungroup()

p1 <- ggplot(fig1_df, aes(x = regimen_anchor, y = pct, fill = factor(viral_suppressed_in_window))) +
  geom_col(position = position_dodge(width = 0.8)) +
  labs(x = "Regimen anchor", y = "Percent", fill = "Viral suppressed (<200)") +
  theme_minimal()

ggsave(file.path(dataout_dir, "Objective1_Figure_viral_suppression.png"), p1, width = 8, height = 4, dpi = 200)

# ------------------------------------------
# 7) Objective 2: DTG vs PI log-binomial RR
# ------------------------------------------
cat("Objective 2: DTG vs PI models...\n")

model_df2 <- df_study %>%
  filter(
    regimen_anchor %in% c("DTG", "PI"),
    !is.na(viral_suppressed_in_window),
    !is.na(pdc_in_window)
  )

# Confounder set: keep minimal to match "only what you need"
# Adjust as desired.
model_df2 <- model_df2 %>%
  mutate(
    age_second_line = as.numeric(second_line_start_date - birthdate) / 365.25,
    baseline_cd4 = suppressWarnings(as.numeric(baseline_cd4)),
    advanced_hiv_disease = as.character(advanced_hiv_disease),
    years_since_hiv_diagnosis = suppressWarnings(as.numeric(years_since_hiv_diagnosis)),
    who_stage = as.character(who_stage),
    viraemic_at_switch = factor(viraemic_at_switch, levels = c("No", "Yes")),
    baseline_vl_at_switch = suppressWarnings(as.numeric(baseline_vl_at_switch)),
    baseline_vl_at_switch_log10 = log10(pmax(0, baseline_vl_at_switch) + 1),
    pdc_cat = factor(pdc_cat, levels = c("<0.80", "0.80-0.94", ">=0.95")),
    age_5yr_band = cut(
      age_second_line,
      breaks = seq(15, 85, by = 5),
      right = FALSE,
      include.lowest = TRUE
    ),
    age_5yr_band = relevel(age_5yr_band, ref = "[30,35)")
  )

run_log_binomial <- function(df_in, formula) {
  # Try log-binomial (log link). If it fails to converge, fallback to Poisson + robust SE.
  fit <- try(glm(formula, data = df_in, family = binomial(link = "log")), silent = TRUE)
  if (!inherits(fit, "try-error")) return(list(model = fit, method = "log-binomial"))

  fit2 <- glm(formula, data = df_in, family = poisson(link = "log"))
  return(list(model = fit2, method = "poisson-fallback"))
}

# Unadjusted
fit_u2 <- run_log_binomial(model_df2, viral_suppressed_in_window ~ regimen_anchor)

# Adjusted (minimal)
fit_a2 <- run_log_binomial(
  model_df2,
  viral_suppressed_in_window ~ regimen_anchor +
    nrti_backbone +
    who_stage + baseline_cd4 + baseline_vl_at_switch_log10 +
    viraemic_at_switch +
    years_since_hiv_diagnosis +
    age_5yr_band + gender + pdc_cat
)

extract_rr <- function(fit_obj) {
  fit <- fit_obj$model
  method <- fit_obj$method

  if (identical(method, "poisson-fallback")) {
    if (!requireNamespace("sandwich", quietly = TRUE) || !requireNamespace("lmtest", quietly = TRUE)) {
      stop(
        "Poisson fallback was used, but robust SE packages are missing. Please install: sandwich, lmtest"
      )
    }
    robust <- lmtest::coeftest(fit, vcov. = sandwich::vcovHC(fit, type = "HC0"))
    rr <- exp(robust[, "Estimate"])
    lower <- exp(robust[, "Estimate"] - 1.96 * robust[, "Std. Error"])
    upper <- exp(robust[, "Estimate"] + 1.96 * robust[, "Std. Error"])
    p_value <- robust[, "Pr(>|z|)"]
    return(tibble(
      term = rownames(robust),
      RR = rr, lower = lower, upper = upper,
      p_value = p_value,
      method = method
    ))
  }

  coefs <- summary(fit)$coefficients
  rr <- exp(coef(fit))
  se <- coefs[, "Std. Error"]
  lower <- exp(coef(fit) - 1.96 * se)
  upper <- exp(coef(fit) + 1.96 * se)
  p_value <- coefs[, "Pr(>|z|)"]
  tibble(
    term = rownames(coefs),
    RR = rr, lower = lower, upper = upper,
    p_value = p_value,
    method = method
  )
}

rr_u2 <- extract_rr(fit_u2)
rr_a2 <- extract_rr(fit_a2)

fit_viraemic <- run_log_binomial(
  model_df2 %>% filter(!is.na(viraemic_at_switch)),
  viral_suppressed_in_window ~ viraemic_at_switch +
    regimen_anchor + nrti_backbone + pdc_cat +
    who_stage + baseline_cd4 + age_5yr_band + gender
)
rr_viraemic <- extract_rr(fit_viraemic)

write_csv_safe(rr_u2, file.path(dataout_dir, "Objective2_RR_unadjusted_DTG_vs_PI.csv"))
write_csv_safe(rr_a2, file.path(dataout_dir, "Objective2_RR_adjusted_DTG_vs_PI.csv"))
write_csv_safe(rr_viraemic, file.path(dataout_dir, "Objective2_RR_viraemic_at_switch.csv"))

# --------------------------------------------
# 8) Objective 3: NRTI backbone models (TDF ref)
# --------------------------------------------
cat("Objective 3: NRTI backbone models...\n")

model_df3 <- df_study %>%
  filter(
    nrti_backbone %in% c("TDF", "AZT", "ABC"),
    !is.na(viral_suppressed_in_window),
    !is.na(pdc_in_window)
  ) %>%
  mutate(
    age_second_line = as.numeric(second_line_start_date - birthdate) / 365.25,
    baseline_cd4 = suppressWarnings(as.numeric(baseline_cd4)),
    advanced_hiv_disease = as.character(advanced_hiv_disease),
    years_since_hiv_diagnosis = suppressWarnings(as.numeric(years_since_hiv_diagnosis)),
    who_stage = as.character(who_stage),
    viraemic_at_switch = factor(viraemic_at_switch, levels = c("No", "Yes")),
    baseline_vl_at_switch = suppressWarnings(as.numeric(baseline_vl_at_switch)),
    baseline_vl_at_switch_log10 = log10(pmax(0, baseline_vl_at_switch) + 1),
    pdc_cat = factor(pdc_cat, levels = c("<0.80", "0.80-0.94", ">=0.95")),
    age_5yr_band = cut(
      age_second_line,
      breaks = seq(15, 85, by = 5),
      right = FALSE,
      include.lowest = TRUE
    ),
    age_5yr_band = relevel(age_5yr_band, ref = "[30,35)")
  )

model_df3$nrti_backbone <- factor(model_df3$nrti_backbone, levels = c("TDF", "AZT", "ABC"))

fit_u3 <- run_log_binomial(model_df3, viral_suppressed_in_window ~ nrti_backbone)
fit_a3 <- run_log_binomial(
  model_df3,
  viral_suppressed_in_window ~ nrti_backbone +
    regimen_anchor +
    who_stage + baseline_cd4 + baseline_vl_at_switch_log10 +
    viraemic_at_switch +
    years_since_hiv_diagnosis +
    age_5yr_band + gender + pdc_cat
)

rr_u3 <- extract_rr(fit_u3)
rr_a3 <- extract_rr(fit_a3)

write_csv_safe(rr_u3, file.path(dataout_dir, "Objective3_RR_unadjusted_NRTI_backbone.csv"))
write_csv_safe(rr_a3, file.path(dataout_dir, "Objective3_RR_adjusted_NRTI_backbone.csv"))

# Forest plot (adjusted RR)
forest_df <- bind_rows(
  rr_a2 %>% mutate(objective = "Obj 2: DTG vs PI"),
  rr_a3 %>% mutate(objective = "Obj 3: NRTI backbone")
) %>%
  filter(term %in% c(
    "regimen_anchorPI",
    "nrti_backboneAZT",
    "nrti_backboneABC",
    "pdc_cat0.80-0.94",
    "pdc_cat>=0.95",
    "viraemic_at_switchYes",
    "genderMale"
  )) %>%
  mutate(
    term = case_when(
      term == "regimen_anchorPI" ~ "PI (vs DTG)",
      term == "nrti_backboneAZT" ~ "AZT (vs TDF)",
      term == "nrti_backboneABC" ~ "ABC (vs TDF)",
      term == "viraemic_at_switchYes" ~ "Viraemic at switch (Yes vs No)",
      term == "genderMale" ~ "Male (vs Female)",
      str_starts(term, "pdc_cat") ~ str_replace(term, "^pdc_cat", "PDC "),
      TRUE ~ term
    )
  )

p_forest <- ggplot(
  forest_df,
  aes(x = RR, y = fct_rev(term), xmin = lower, xmax = upper, colour = objective)
) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "grey50") +
  geom_point(size = 2) +
  geom_errorbar(width = 0.2, orientation = "y") +
  scale_x_log10() +
  theme_minimal() +
  labs(title = "Adjusted relative risks (robust SE)", x = "RR (log scale)", y = NULL, colour = NULL)

ggsave(
  file.path(dataout_dir, "ForestPlot_adjusted_RR.png"),
  p_forest,
  width = 10,
  height = 6,
  dpi = 200
)

# -----------------------------------------------------
# 9) Objective 4: OI burden in virological failures
# -----------------------------------------------------
cat("Objective 4: OI burden in virological failures...\n")

df_study <- df_study %>%
  mutate(
    vf_group = case_when(
      vf_confirmed ~ "Confirmed VF (2x VL>1000, >=90d apart)",
      vf_pending ~ "Pending confirmation (1x VL>1000)",
      TRUE ~ "Not confirmed VF"
    )
  )

vf_counts <- df_study %>%
  count(vf_group, name = "n") %>%
  mutate(pct = round(100 * n / sum(n), 1))

write_csv(vf_counts, file.path(dataout_dir, "Objective4_VF_group_counts.csv"))

fail_df <- df_study %>% filter(vf_confirmed)
pending_df <- df_study %>% filter(vf_pending)

cat("Failures:", nrow(fail_df), "\n")

oi_summary <- fail_df %>%
  summarise(
    n_fail = n(),
    n_any_oi = sum(opportunistic_infections == "Yes", na.rm = TRUE),
    n_any_oi_total = sum(!is.na(opportunistic_infections))
  )
write_csv(oi_summary, file.path(dataout_dir, "Objective4_OI_summary_overall.csv"))

oi_by_anchor <- fail_df %>%
  filter(regimen_anchor %in% c("DTG", "PI")) %>%
  count(regimen_anchor, opportunistic_infections, name = "n") %>%
  group_by(regimen_anchor) %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  ungroup()

write_csv(oi_by_anchor, file.path(dataout_dir, "Objective4_OI_by_anchor_DTG_vs_PI.csv"))

# OI documentation completeness (overall + by VF group)
oi_vars <- c(
  "opportunistic_infections",
  "date_of_oi_diagnosis",
  "oii_condition_specify",
  "oii_treatment_started",
  "confirmed_tb_after_switch",
  "tb_treatment_start_date",
  "tb_treatment_started"
)

oi_missing_overall <- df_study %>%
  summarise(across(
    all_of(oi_vars),
    ~ mean(is.na(.x)) * 100,
    .names = "pct_missing_{.col}"
  )) %>%
  pivot_longer(everything(), names_to = "metric", values_to = "pct_missing") %>%
  mutate(
    variable = str_replace(metric, "^pct_missing_", ""),
    pct_missing = round(pct_missing, 1)
  ) %>%
  select(variable, pct_missing)

write_csv(oi_missing_overall, file.path(dataout_dir, "Objective4_OI_missingness_overall.csv"))

oi_missing_by_vf <- df_study %>%
  group_by(vf_group) %>%
  summarise(
    n = n(),
    across(
      all_of(oi_vars),
      ~ round(mean(is.na(.x)) * 100, 1),
      .names = "pct_missing_{.col}"
    ),
    .groups = "drop"
  ) %>%
  pivot_longer(
    cols = starts_with("pct_missing_"),
    names_to = "metric",
    values_to = "pct_missing"
  ) %>%
  mutate(variable = str_replace(metric, "^pct_missing_", "")) %>%
  select(vf_group, n, variable, pct_missing)

write_csv(oi_missing_by_vf, file.path(dataout_dir, "Objective4_OI_missingness_by_vf_group.csv"))

cat("Pending confirmation:", nrow(pending_df), "\n")
oi_summary_pending <- pending_df %>%
  summarise(
    n_pending = n(),
    n_any_oi = sum(opportunistic_infections == "Yes", na.rm = TRUE),
    n_any_oi_total = sum(!is.na(opportunistic_infections))
  )
write_csv(oi_summary_pending, file.path(dataout_dir, "Objective4_OI_summary_pending_confirmation.csv"))

# Sensitivity: treat pending confirmation as virological failure
df_study_sens <- df_study %>%
  mutate(virological_failure_sens = vf_confirmed | vf_pending)

vf_counts_sens <- df_study_sens %>%
  mutate(vf_group_sens = if_else(virological_failure_sens, "VF (confirmed+pending)", "Not VF")) %>%
  count(vf_group_sens, name = "n") %>%
  mutate(pct = round(100 * n / sum(n), 1))
write_csv_safe(vf_counts_sens, file.path(dataout_dir, "Objective4_VF_group_counts_sensitivity_confirmed_plus_pending.csv"))

model_df2_sens <- df_study_sens %>%
  filter(regimen_anchor %in% c("DTG", "PI"), !is.na(pdc_in_window)) %>%
  mutate(
    age_second_line = as.numeric(second_line_start_date - birthdate) / 365.25,
    baseline_vl_at_switch_log10 = log10(pmax(0, baseline_vl_at_switch) + 1),
    viraemic_at_switch = factor(viraemic_at_switch, levels = c("No", "Yes")),
    age_5yr_band = cut(
      age_second_line,
      breaks = seq(15, 85, by = 5),
      right = FALSE,
      include.lowest = TRUE
    ),
    age_5yr_band = relevel(age_5yr_band, ref = "[30,35)")
  )

fit_sens <- run_log_binomial(
  model_df2_sens,
  virological_failure_sens ~ regimen_anchor +
    nrti_backbone + who_stage + baseline_cd4 +
    baseline_vl_at_switch_log10 + viraemic_at_switch +
    age_5yr_band + gender + pdc_cat
)
rr_sens <- extract_rr(fit_sens)
write_csv_safe(
  rr_sens,
  file.path(dataout_dir, "Objective4_Sensitivity_RR_confirmed_plus_pending_VF.csv")
)

# Placeholder for resistance mutation frequencies
# -------------------------------------------------
# You said genotype results are hardcopy uploads in AMRS.
# To compute mutation frequencies, you need a merged genotype dataset with columns such as:
#   de_identified, mutation_name (or gene + mutation), test_date (optional)
# When you digitize and merge it, you can add:
#   - Load genotype file
#   - Restrict to failing patients
#   - Summarise mutation frequencies (overall and by regimen group)
#   - Optionally restrict to "before/at second-line" mutations.
cat("\nDone. Outputs written to:", dataout_dir, "\n")

