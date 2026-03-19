# Statistical Analysis Plan (SAP): Pharmacoepidemiologic Framework  
## Second-line ART outcomes, Western Kenya (2018–2024)

**Version:** 1.0  
**Scope:** Initial analysis — descriptive and comparison only.  
**Reference:** Virological Outcomes of Dolutegravir Proposal_April_2025; ART Evolution over time (Kenya).

---

## 0. Study aims and objectives

### 0.1 Overall aim

To describe virological and clinical outcomes among people living with HIV who initiate second-line ART in AMPATH (Western Kenya) between 1 October 2018 and 30 September 2024, and to compare these outcomes by second-line regimen.

### 0.2 Specific objectives

1. **Describe the cohort at switch to second-line ART.**  
   - Baseline demographic and clinical characteristics (age, sex, age group, WHO stage, CD4, advanced HIV disease, prior ART duration, regimen, calendar year of switch) overall and by second-line regimen anchor (DTG vs PI) and by NRTI backbone (TDF vs AZT vs ABC).

2. **Describe virological and clinical outcomes after second-line ART initiation.**  
   - Proportion suppressed and failing (per protocol definition), overall and by regimen anchor and NRTI backbone.  
   - Clinical status at end of follow-up (active in care, transferred out, died, LTFU/other, other) and follow-up time.

3. **Compare outcomes by second-line regimen in a descriptive (non-causal) manner.**  
   - Compare virological and clinical outcomes between DTG-based and PI-based second-line regimens.  
   - Compare outcomes between NRTI backbones (TDF vs AZT vs ABC) within second-line regimens.  
   - Present key comparisons overall, and by age group and calendar period, to aid interpretation of channeling and confounding by indication.

*Note:* All objectives are addressed descriptively (counts, proportions, medians/IQRs, tables and figures by group). No regression or causal effect estimation is planned in this initial SAP.

---

## 1. Pharmacoepidemiologic design

### 1.1 Study design

- **Design:** Retrospective cohort study using programmatic EMR data (AMRS).  
- **Population:** People living with HIV (PLWH) on **second-line ART** in AMPATH catchment, Western Kenya.  
- **Exposure:** Second-line regimen **anchor** (DTG vs PI) and **NRTI backbone** (TDF vs AZT vs ABC) **at cohort entry**.  
- **Outcomes:** Virological (suppression &lt;200 copies/mL; failure) and clinical (status: active, LTFU, died, transferred out).  
- **Analysis:** Initial phase = **descriptive and comparison** (counts, proportions, tables by exposure group).

### 1.2 Role of Kenya ART evolution (confounding by indication and channeling)

Kenya’s guidelines evolved over the study period (see *ART Evolution over time.pdf*):

- **Before/early 2018:** Second-line = mainly **PIs** (LPV/r, ATV/r).  
- **Aug 2018:** DTG in national guidelines as preferred **first-line**; rollout of DTG.  
- **2022:** DTG recommended as preferred **second-line** for adults.  
- **During 2018–2024:** Second-line options = **PI-based** (LPV/r, ATV/r; LPV/r later phased out) or **DTG-based**. Those failing PI or TLE → DTG; those failing DTG → DRV/r.

**Implications:**

- **Confounding by indication:** Who receives DTG vs PI at second-line switch depends on **calendar time**, **site**, **prior regimen**, **VL at failure**, **toxicity**, and **comorbidities** (e.g. TB/rifampicin). These factors also affect outcomes.  
- **Channeling bias:** DTG was rolled out over time and by site; earlier years/sites had more PI, later more DTG. “Healthier” or more engaged patients/sites may have switched to DTG earlier.  
- **Healthy user / engagement bias:** Patients who remain in care and get a regimen switch may differ from those lost before switch.  
- **Protopathic bias:** Early symptoms or early treatment failure may prompt switch (e.g. to DTG); outcome (e.g. VF) may have started before the switch.  

The cohort definition, **time zero (T0)**, and **exposure definition** below are chosen to reduce **immortal time** and **time-related selection**, and to make **confounding by indication** and **channeling** explicit and describable.

---

## 2. Time zero (T0)

### 2.1 Definition

**Time zero (T0) = date of second-line ART initiation.**

- **Operational:** First date the patient is documented to have started a **second-line** regimen (DTG-based or PI-based), as recorded in AMRS.  
- **No delay:** Follow-up and person-time start at T0. No period between “eligibility” and “start” is counted as follow-up, to avoid immortal time bias.  
- **Exposure:** Regimen at T0 (the regimen started on that date) defines the exposure group for the initial analysis (intention-to-treat at T0).  

### 2.2 Why T0 = second-line start (immortal time bias)

- If T0 were defined later (e.g. first VL after switch, or 6 months after switch), the time between second-line start and that later T0 would be “immortal” (no events), but would still be counted as person-time. That **inflates** apparent survival/suppression in the exposed group.  
- **Decision:** T0 = second-line ART initiation date. All follow-up starts at T0; no person-time before T0 is included in the analysis cohort.  

### 2.3 Alignment with data

- In the cleaning script, **second_line_start_date** is the anchor for cohort entry and for **fu_years** (follow-up from second_line_start_date to latest VL or censoring).  
- **T0** in this SAP = **second_line_start_date** in the dataset.

---

## 3. Cohort definition and construction

### 3.1 Target population

- PLWH in AMPATH care who **initiated** second-line ART (DTG-based or PI-based) between **1 October 2018** and **30 September 2024** (both dates inclusive).  
- Second-line = confirmed first-line virological failure per 2018 Kenya guidelines (≥2 VL &gt;1000 copies/mL, ≥3 months apart, with good adherence), or equivalent programmatic definition used in AMRS.

### 3.2 Inclusion criteria (all required at T0)

1. **HIV-positive**, enrolled in AMPATH care.  
2. **Second-line start date (T0)** in [2018-10-01, 2024-09-30].  
3. **Regimen at T0** is DTG-based or PI-based (anchor: DTG vs PI); for NRTI objectives, regimen contains TDF, AZT, or ABC as backbone.  
4. **At least 6 months** on ART by T0 (first-line duration ≥6 months).  
5. **At least two VL measurements** ever (before or after T0) to allow assessment of virological outcome.  
6. **Non-missing** patient identifier and T0 (second_line_start_date).

### 3.3 Exclusion criteria

1. **First-line regimen only:** On DTG or PI as part of **first-line** ART only (never started second-line in the window).  
2. **Second-line start outside window:** T0 before 2018-10-01 or after 2024-09-30.  
3. **Missing T0 or ID:** No second_line_start_date or missing de_identified.  
4. (Optional, for sensitivity) **No regimen information** at T0 (cannot assign DTG/PI or NRTI backbone).

### 3.4 Single row per patient (cohort entry)

- **One cohort entry per patient:** For patients with multiple second-line episodes or multiple records, **cohort entry** = first eligible second-line start in the window (first T0 in [2018-10-01, 2024-09-30]).  
- All baseline covariates and exposure are defined **at that T0**.  
- This avoids counting the same person twice and keeps a clear “cohort entry at T0” for time bias and follow-up.

### 3.5 Exposure definition at T0

- **Regimen anchor:** DTG vs PI vs Other, based on **regimen at T0** (arv_regimen_2nd_line_start / second_line_regimen at start date).  
- **NRTI backbone:** TDF vs AZT vs ABC vs Other, based on **regimen at T0**.  
- For **regimen-specific** summaries (Obj 2 & 3): patients who **switch** anchor or backbone **after T0** are **censored at the date of switch** (person-time and outcomes up to switch attributed to the initial regimen).  

This avoids immortal time (no follow-up before T0) and limits bias from “switchers” being mixed with “stayers.”

---

## 4. Follow-up and censoring

### 4.1 Start of follow-up

- **Start:** T0 (second_line_start_date).  
- **No** person-time before T0.

### 4.2 End of follow-up (administrative and clinical)

- **Administrative end:** 2024-09-30 (study end) or last available data export date, whichever is used for the analysis.  
- **Clinical end (censoring):**  
  - **Regimen switch:** For DTG vs PI (or TDF vs AZT vs ABC) analyses, censor at date of **first change** of anchor or NRTI backbone after T0.  
  - **Transfer out:** Censor at transfer-out date if recorded.  
  - **Death:** Outcome (not censoring for survival); for virological outcomes, no person-time after death.  
  - **Loss to follow-up (LTFU):** Censor at last contact date (e.g. last visit or last VL date) when defining follow-up for outcomes that require observation.

### 4.3 Outcome assessment window

- **Virological outcomes:** Based on VL **after T0** (e.g. latest VL in follow-up; suppression &lt;200 copies/mL; failure as per protocol).  
- **Clinical status:** As of end of follow-up or database closure (e.g. 2024-09-30): active, LTFU, died, transferred out, other.  
- No outcome that occurs **before T0** is attributed to “exposure” (avoids protopathic bias in definition).

---

## 5. Bias: identification and mitigation

### 5.1 Immortal time bias

- **Risk:** If T0 were defined after second-line start (e.g. “first VL after switch”), the period from second-line start to that date would be immortal and would bias results.  
- **Mitigation:** T0 = **second-line ART initiation**. Follow-up starts at T0; no person-time before T0. Script uses **second_line_start_date** and **fu_years** from that date.

### 5.2 Confounding by indication

- **Risk:** DTG vs PI (and TDF vs AZT vs ABC) is not randomised. Indication for regimen (calendar period, prior failure, TB, toxicity, site) is associated with both regimen and outcome.  
- **Mitigation (initial analysis):**  
  - **Describe** baseline characteristics **by exposure group** (age, sex, calendar year of T0, baseline CD4, WHO stage, VL at/before switch, prior first-line regimen, site/facility if available).  
  - **Stratify** descriptive and comparison **by calendar period** (e.g. 2018–2020 vs 2021–2024) and, if feasible, by facility, to make channeling and confounding by indication visible.  
  - **No causal claim** in initial analysis; comparison is descriptive (e.g. “outcomes in DTG vs PI in this programmatic cohort”).

### 5.3 Channeling bias (temporal and by site)

- **Risk:** DTG availability increased over 2018–2024; sites and patients channeled to DTG vs PI by time and location.  
- **Mitigation:**  
  - Report **distribution of regimen by year of T0** and by facility.  
  - Present outcomes **by exposure** and **by calendar period** (and site if possible) so readers can see whether patterns differ over time.  
  - Acknowledge in limitations that channeling is expected and not fully adjustable in descriptive analysis.

### 5.4 Healthy user / engagement bias

- **Risk:** Patients who remain in care long enough to get a second-line regimen and follow-up may be “healthier” or more engaged than those lost earlier.  
- **Mitigation:**  
  - Clearly define **inclusion** (e.g. ≥6 months on ART, ≥2 VLs).  
  - Report **number of patients** who had first-line failure but **did not** have a second-line start in the window (if available) to characterise selection into the cohort.  
  - Interpret results as pertaining to **patients who started second-line in AMPATH** in the window, not all first-line failures.

### 5.5 Selection bias (general)

- **Risk:** Only AMRS sites included; paper-based or non-AMRS sites excluded.  
- **Mitigation:** State inclusion clearly (AMPATH, AMRS, window, eligibility). Report number of facilities/sites and any exclusions. Discuss in limitations.

### 5.6 Information bias

**Misclassification:**

- **Exposure:** Regimen at T0 from EMR may be wrong or missing.  
  - **Mitigation:** Use **actual regimen at T0** (not “intended”); document missing regimen; sensitivity: exclude missing regimen or classify as “Other.”  
- **Outcome:** VL suppression/failure depends on assay and threshold; clinical status (LTFU, death) may be incomplete.  
  - **Mitigation:** Use protocol definitions (e.g. &lt;200 copies/mL); state source of death/transfer; report missingness for outcomes.

**Protopathic bias:**

- **Risk:** Early symptoms or early failure might lead to switch (e.g. to DTG); the “outcome” may have started before T0.  
- **Mitigation:** Define outcomes using events **after T0** (e.g. VL after T0; status at end of follow-up). Do not use “VL at switch” as the outcome for regimen comparison; use **post-T0** virological and clinical outcomes.

### 5.7 Design-related issues summary

| Issue | Mitigation in this SAP |
|-------|-------------------------|
| Immortal time | T0 = second-line start; no follow-up before T0. |
| Confounding by indication | Describe baseline by group; stratify by period (and site); no causal claim. |
| Channeling | Report regimen by year and site; acknowledge in limitations. |
| Healthy user / selection | Define inclusion; describe selection into cohort where possible. |
| Exposure misclassification | Use regimen at T0; document and handle missing. |
| Outcome misclassification | Use clear definitions; report missingness. |
| Protopathic bias | Outcomes defined after T0 only. |
| Switchers | Censor at regimen switch for regimen-specific analyses. |

---

## 6. Variables and definitions (for cohort and analysis)

### 6.1 Time and identifiers

- **T0:** second_line_start_date.  
- **Patient ID:** de_identified.  
- **Facility/site:** facility_name (if available) for stratification.

### 6.2 Exposure (at T0)

- **Regimen anchor:** DTG vs PI vs Other (from regimen at T0).  
- **NRTI backbone:** TDF vs AZT vs ABC vs Other (from regimen at T0).  
- **Calendar year of T0** (and optionally period: 2018–2020 vs 2021–2024).

### 6.3 Baseline covariates (at or before T0)

- Demographics: birthdate, age at T0, gender.  
- First-line: first_line_start_date, duration on first line, first-line regimen (if available).  
- At second-line start: WHO stage, baseline CD4, VL at/before switch, advanced HIV disease (CD4 &lt;200 or WHO III/IV).  
- Adherence (if available at T0 or prior): Morisky score (MMAS-8 and/or MMAS-4 where available), adherence_rating.  
- TB/rifampicin, pregnancy (if relevant for channeling).  
- **Date of HIV diagnosis** (if available) for duration of HIV at T0.

All baseline variables must be defined using information **at or before T0** only (no future information).

### 6.4 Outcomes (after T0)

- **Virological:** Viral suppression (latest VL &lt;200 copies/mL), virological failure (per protocol), vl_status (Suppressed/Unsuppressed).  
- **Clinical:** Status at end of follow-up: active, LTFU, died, transferred out, other (reason_for_exit / status / cause_of_death as implemented in script).  
- **Follow-up time:** From T0 to last VL date or censoring (fu_years in script).

### 6.5 Censoring variables

- **Regimen switch:** Date of first change of anchor or NRTI backbone after T0 (if available).  
- **Transfer, LTFU:** As per status and dates in EMR.

### 6.6 Variable list for the study cohort (`df_analysis`)

The cleaned cohort used by the analysis scripts is `df_analysis` (one row per patient) produced by `Scripts/read_clean_01.R`. The lists below match what is required/checked for the initial descriptive and comparison analyses.

#### Virological outcomes only (minimum)
- `de_identified`
- `second_line_start_date` (T0)
- `first_line_start_date` (for the >=6 months ART criterion)
- `arv_regimen_2nd_line_start` (raw regimen string)
- `regimen_anchor` (DTG vs PI vs Other)
- `nrti_backbone` (TDF vs AZT vs ABC)
- `birthdate` (to derive `age_second_line`)
- `gender`
- `who_stage`
- `baseline_cd4`
- `advanced_hiv_disease`
- `adherence_rating` (if available)
- `morisky_mmas8` (if available)
- `morisky_mmas4` (if available)
- `date_hiv_diagnosis` (to derive `years_since_hiv_diagnosis`, if available)
- `vl_status` (Suppressed/Unsuppressed)
- `viral_suppressed` (derived from `vl_status`)
- `latest_vl_date` (to derive `fu_years`)
- `fu_years`

#### Virological + clinical outcomes (add the clinical variables)
- `reason_for_exit`
- `cause_of_death`
- `status` (derived in the cleaning script)
- `clinical_status` (alias of `status`)

Note: in the current implementation, `reason_for_exit` is also used as part of the censoring/clinical-status definition logic.

---

## 7. Analysis plan (initial — descriptive and comparison)

### 7.1 Cohort flow

- **Figure/table:** Number of patients in AMRS with second-line start in window → after exclusions (missing T0/ID, first-line only, outside window, &lt;6 months ART, &lt;2 VLs) → analysis cohort (N). By exposure: N in DTG, PI, Other; N in TDF, AZT, ABC, Other.

### 7.2 Baseline (Table 1)

- **Overall** and **by regimen anchor** (DTG vs PI) and **by NRTI backbone** (TDF vs AZT vs ABC): N, demographics, calendar year of T0, baseline CD4, WHO stage, advanced HIV, VL at switch (if available), first-line duration, adherence (if available), facility (if available).  
- **By calendar period** (e.g. 2018–2020 vs 2021–2024) to show channeling.

### 7.3 Outcomes — descriptive and comparison

- **Virological:** Proportions (and counts) with viral suppression, and with failure, **overall** and **by** regimen anchor and **by** NRTI backbone. Present side-by-side for comparison.  
- **Clinical:** Proportions (and counts) in each status (active, LTFU, died, transferred out, other) **overall** and **by** regimen and NRTI backbone.  
- **Follow-up:** Median (IQR) follow-up time from T0, overall and by group.  
- **Stratified:** Repeat key outcomes **by calendar period** (and site if feasible) to aid interpretation of confounding by indication and channeling.

### 7.4 Regimen switch and censoring

- For regimen-specific tables: state that follow-up is **censored at regimen switch**. Report number (and %) who switched anchor or backbone after T0 and were censored.  
- Sensitivity (optional): present outcomes **without** censoring at switch (as-treated or intent-to-treat from T0) for comparison.

### 7.5 Missing data

- Report **missingness** for key variables (regimen, VL, status, baseline CD4, WHO stage).  
- **No imputation** in initial analysis; complete-case or “available” counts for each table with a note on missingness.

### 7.6 Software and reproducibility

- Analysis in **R**; script **read_clean_01.R** produces cohort (df_analysis) with T0 = second_line_start_date, fu_years, regimen_anchor, nrti_backbone, viral_suppressed, status.  
- SAP and cohort definition (T0, inclusion/exclusion, censoring) documented in this document and in code comments.

---

## 8. Limitations (to state in report)

- **Confounding by indication** and **channeling** (DTG vs PI by time and site) are expected; initial analysis is descriptive and does not adjust for them.  
- **Selection:** Cohort includes only those who started second-line in AMPATH in the window; excludes those lost before switch or in non-AMRS sites.  
- **Information bias:** Regimen and outcomes from EMR; death/transfer may be under-ascertained.  
- **Protopathic bias:** Minimised by defining outcomes after T0; residual possible if switch was triggered by early failure.  
- **Single entry per patient** at first T0; later second-line episodes (e.g. after third-line) not included.

---

## 9. Summary: T0 and cohort for sound results

| Element | Definition |
|--------|------------|
| **T0** | Date of second-line ART initiation (second_line_start_date). |
| **Cohort entry** | First eligible second-line start in [2018-10-01, 2024-09-30]; one row per patient. |
| **Follow-up start** | T0 (no person-time before T0). |
| **Exposure** | Regimen at T0 (anchor: DTG/PI; backbone: TDF/AZT/ABC). |
| **Censoring** | At regimen switch (for regimen-specific); at transfer/LTFU/end of study as appropriate. |
| **Outcomes** | Virological and clinical events **after T0** only. |
| **Bias** | Addressed by design (T0, single entry, censoring) and by transparent description and stratification (period, site); limitations stated. |

---

---

## 10. Fitness of data: alignment with actual dataset

The SAP should be checked against the **actual variables and completeness** in the analysis dataset. Below is a mapping of SAP requirements to what the current extract typically provides (from read_clean_01.R and missingness audits). **Run the fitness-of-data check script** (see below) each time the dataset is updated.

### 10.1 Required for cohort and T0

| SAP requirement | Variable in data | Typical completeness | Fitness |
|-----------------|------------------|----------------------|---------|
| T0 (second-line start) | second_line_start_date | 100% (after exclusions) | ✓ |
| Patient ID | de_identified | 100% | ✓ |
| First-line start (for ≥6 months ART) | first_line_start_date | 100% | ✓ |
| Window [2018-10-01, 2024-09-30] | second_line_start_date | Applied in script | ✓ |

### 10.2 Exposure (at T0)

| SAP requirement | Variable in data | Typical completeness | Fitness |
|-----------------|------------------|----------------------|---------|
| Regimen at T0 | arv_regimen_2nd_line_start → regimen_anchor, nrti_backbone | ~96% non-missing regimen | ✓ (report ~4% missing) |
| Calendar year of T0 | Derived from second_line_start_date | 100% | ✓ |

### 10.3 Baseline covariates (descriptive Table 1)

| SAP requirement | Variable in data | Typical completeness | Fitness |
|-----------------|------------------|----------------------|---------|
| Age at T0 | birthdate → age_second_line | 100% | ✓ |
| Sex | gender | 100% | ✓ |
| Facility | facility_name | 100% | ✓ |
| WHO stage at/before T0 | who_stage | ~78% | ⚠ Partial |
| Baseline CD4 | baseline_cd4 | ~71% | ⚠ Partial |
| Advanced HIV | advanced_hiv_disease | 100% | ✓ |
| First-line duration | first_line_start_date, second_line_start_date | 100% | ✓ |
| Adherence (Morisky / rating) | morisky_mmas8, adherence_rating | ~41% / ~18% | ⚠ Weak |
| Date of HIV diagnosis | date_hiv_diagnosis | ~31% | ⚠ Weak |
| VL at switch | baseline VL in dictionary; in extract may be latest_vl or separate | Check in data | ? |

### 10.4 Outcomes

| SAP requirement | Variable in data | Typical completeness | Fitness |
|-----------------|------------------|----------------------|---------|
| Virological (suppression/failure) | vl_status → viral_suppressed | 100% | ✓ |
| Clinical status | reason_for_exit, cause_of_death → status | ~18% have reason_for_exit; ~5% cause_of_death | ⚠ Weak (most coded "Active") |
| Follow-up time | fu_years (from second_line_start_date to latest_vl_date or today) | 100% | ✓ |

### 10.5 Censoring

| SAP requirement | Variable in data | Typical completeness | Fitness |
|-----------------|------------------|----------------------|---------|
| Regimen switch date | Not in standard one-row extract; dictionary has regimen_start_date, current_regimen_at_visit | Unknown / may need long-format data | ⚠ Check; if absent, state "no censoring at switch" in analysis |
| Transfer out / LTFU | reason_for_exit, status | ~18% non-missing reason_for_exit | ⚠ Partial |

### 10.6 Conclusion for fitness

- **T0, exposure, virological outcomes, follow-up:** Data are **fit** for the initial descriptive and comparison analysis (Obj 1–3 for virological; Obj 2–3 for regimen comparison).
- **Clinical outcome (status):** **Limited** — most patients have missing reason_for_exit and cause_of_death, so status is often "Active" by default. Report proportions with non-missing status; interpret clinical comparisons with caution.
- **Baseline covariates:** **Partial** — WHO stage, baseline CD4, and adherence useful for description but have non-trivial missingness; describe by "has value" and report missingness.
- **Regimen switch:** **Unclear** — confirm whether regimen change after T0 can be identified; if not, do not censor at switch and state in methods.

**Recommendation:** Run the **fitness-of-data check** script (Scripts/fitness_of_data_check.R) after each data update and before analysis. Use the output to update this section and to document limitations in the report.

### 10.7 How to run the fitness check and use the output

**When to run:** After every data refresh (new extract or updated Excel) and before running any analysis scripts.

**Steps:**

1. **Update and clean the data**  
   In R or RStudio, run the cleaning script so the analysis cohort is rebuilt:
   ```r
   source("Scripts/read_clean_01.R")
   ```
   This writes `Dataout/df_analysis.rds` (and other outputs).

2. **Run the fitness-of-data check**  
   Then run:
   ```r
   source("Scripts/fitness_of_data_check.R")
   ```
   Or from the project root in a terminal:
   ```bash
   Rscript Scripts/fitness_of_data_check.R
   ```

3. **Check the outputs**  
   - **Console:** Read the printed verdict (e.g. "Data are FIT for initial descriptive and comparison analysis" or "Review required").  
   - **Dataout/fitness_of_data_report.csv:** Variable-level presence and completeness (use this to see if any variable has slipped to Limited or Missing).  
   - **Dataout/fitness_inclusion_checks.csv:** Counts for inclusion criteria (e.g. % meeting ≥6 months ART by T0).

4. **Update this section (Section 10) if needed**  
   If completeness or variable names change (e.g. after a new extract), update the tables in 10.1–10.5 with the latest percentages from `fitness_of_data_report.csv` and adjust the conclusion in 10.6.

5. **Document limitations in your analysis report**  
   Use the fitness verdict and the "Conclusion for fitness" (10.6) when writing the Methods/Limitations:
   - State that a fitness-of-data check was run and that virological outcomes and T0/exposure are fit for the planned analysis.
   - Explicitly note: clinical status is limited by missing reason_for_exit and cause_of_death; baseline covariates (WHO stage, CD4, adherence) have non-trivial missingness; and whether censoring at regimen switch was possible (if not, state that it was not applied).
