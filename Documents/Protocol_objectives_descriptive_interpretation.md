# Protocol objectives: descriptive interpretation

**Source:** Virological Outcomes of Dolutegravir Proposal_April_2025  
**Purpose:** Clarify that all objectives are scientifically coherent as **descriptive** when the full protocol is read in context.

---

## How the protocol frames the study

- **Overarching aim (Abstract and Study Objectives):**  
  *"Our aim is to **describe** the clinical and virological outcomes of all PLWH who were on second-line ART between October 2018 and September 2024 across Western Kenya."*

- **Study design:** Retrospective analysis of programmatic EMR data — no randomisation, no intervention. Observational.

- **Stated purpose:** *"This study will provide **critical programmatic data** on 2nd line DTG and PI outcomes... that will **inform local and national policy and guidelines**."*

- **Statistical analysis (current protocol text):**  
  - *"**Descriptive statistics** will summarize demographic and clinical characteristics **by** ART regimen backbone."*  
  - *"Log-binomial models will be used to compare the risk..."* (see below — **team comments recommend not using log-binomial**.)

So the study is framed as: (1) describe outcomes, (2) describe outcomes **by** regimen (and NRTI backbone). The original log-binomial / RR / CI part should be dropped or replaced (see **Comments** section below).

---

## Why all objectives can be read as descriptive

1. **No randomised comparison**  
   Regimen (DTG vs PI, TDF vs AZT vs ABC) is determined by programmatic and clinical reasons, not random assignment. The aim is to describe what happened in the program, not to test a single pre-specified null hypothesis.

2. **“Compare” = describe in each group**  
   In this context, “compare” means: describe virological and clinical outcomes in the DTG group, describe them in the PI group (and similarly for TDF/AZT/ABC). This is **describing** the observed pattern in the data. The team has agreed **not** to use log-binomial regression (see Comments below); analysis remains **descriptive** (tables, proportions by group).

3. **Stated “hypotheses” function as rationale, not formal nulls**  
   The lines *"Patients on DTG have better virological and clinical outcomes..."* and *"Patients on TDF based regimens have better... outcomes..."* align with trial evidence (e.g. NADIA, DAWNING) and explain **why** DTG vs PI and TDF vs AZT vs ABC are of interest. They do not require the study to be a formal test of superiority; the study can still be framed as describing real-world outcomes and estimating RR with CI.

4. **Consistency with Obj 1 and Obj 4**  
   Objective 1 and 4 are explicitly descriptive and “do not require a hypothesis.” Objectives 2 and 3 are consistent with the same logic if interpreted as: describe outcomes by regimen (and NRTI backbone) using **descriptive statistics only** (no log-binomial; see Comments below).

---

## Reframing all four objectives as descriptive

| Objective | Current wording | Descriptive reframe (scientifically equivalent) |
|-----------|-----------------|---------------------------------------------------|
| **1** | To describe virological and clinical outcomes among children and adults on second-line ART across Western Kenya. | Unchanged. **Describe** virological and clinical outcomes in the cohort. |
| **2** | To compare virological and clinical outcomes of patients on DTG vs PI-based second-line ART. | **Describe** virological and clinical outcomes **in patients on DTG-based second-line ART** and **in patients on PI-based second-line ART** (e.g. proportions, counts, tables). No log-binomial; descriptive only. |
| **3** | To compare virological outcomes of patients on TDF vs AZT vs ABC-based second-line ART. | **Describe** virological outcomes **in patients on TDF-, AZT-, and ABC-based second-line ART** (e.g. proportions, counts, tables). No log-binomial; descriptive only. |
| **4** | To describe drug resistance patterns among patients failing DTG or PI-based ART. | Unchanged. **Describe** drug resistance patterns among those failing DTG- or PI-based ART. |

So scientifically: **all four objectives are descriptive** — they describe outcomes overall and by subgroup (regimen / NRTI backbone) using **descriptive statistics only** (no log-binomial regression; see Comments below).

---

## Suggested wording for the protocol (optional)

If you want the protocol text to state clearly that all objectives are descriptive:

- **Overall aim:**  
  *"Our aim is to describe the clinical and virological outcomes of all PLWH who were on second-line ART between October 2018 and September 2024 across Western Kenya."*  
  (Already descriptive.)

- **Objective 1:**  
  Keep as is.  
  *"This is descriptive and does not require a hypothesis."*

- **Objective 2:**  
  *"To describe virological and clinical outcomes in patients on DTG-based second-line ART and in patients on PI-based second-line ART (using descriptive statistics: proportions, counts, and tables by regimen)."*  
  *"Rationale: Trial data (e.g. NADIA, DAWNING) suggest better outcomes with DTG; we describe whether similar patterns are observed in this programmatic cohort."*

- **Objective 3:**  
  *"To describe virological outcomes in patients on TDF-, AZT-, and ABC-based second-line ART (using descriptive statistics: proportions, counts, and tables by NRTI backbone)."*  
  *"Rationale: Trial data (e.g. NADIA) suggest TDF may perform better than AZT in second line; we describe patterns in this cohort."*

- **Objective 4:**  
  Keep as is.  
  *"This is descriptive and does not require a hypothesis."*

---

## Comments on the document: do not use log-binomial

Comments in the 2025 proposal (see *Proposal_2025_comments_summary.md*) make the following clear:

- **Nelly Maina:** The protocol plans to use **log-binomial regression only**, but virological failure and death are **time-dependent outcomes**; consider instead **Cox proportional hazards** or **Poisson regression with person-time** for time to VF and time to death.
- **Douglas Gaitho** and **Edmon O. Obat:** **In agreement.**

**Conclusion:**  
- **Do not use log-binomial regression** for this study.  
- **We are not doing Cox or Poisson** — this is an **initial analysis**.  
- **Recommended analysis:** **Descriptive and comparison only** — descriptive statistics summarising demographic and clinical characteristics and outcomes **overall** and **by** ART regimen (DTG/PI) and **by** NRTI backbone (TDF/AZT/ABC): counts, proportions, tables. **Comparison** = presenting outcomes in each group side by side. No regression models (no log-binomial, Cox, or Poisson). See *Initial_analysis_plan.md*.

---

## Suggested Statistical Analysis wording for the protocol

Replace the current “Log-binomial models…” sentence with something like:

*"This is an initial analysis. Descriptive statistics will summarise demographic and clinical characteristics and outcomes (e.g. viral suppression, clinical status) **overall** and **by** ART regimen (DTG vs PI) and **by** NRTI backbone (TDF, AZT, ABC). Results will be presented as counts and proportions (and, where relevant, medians and IQR for continuous variables). **Comparison** between groups will be done by presenting outcomes in each group side by side. **No regression models** (no log-binomial, Cox, or Poisson) will be used in this initial analysis. Follow-up starts at the date of second-line ART initiation (T0). Patients who switch regimen after second-line start will be censored at switch for regimen-specific analyses."*

---

## Summary

- When the **entire protocol** is read together, the study is **observational and programmatic**, with the aim to **describe** real-world outcomes and **inform policy**.
- The analysis plan is **initial analysis: descriptive and comparison only** (tables, proportions, counts overall and by regimen and NRTI backbone; comparison = side-by-side by group). **No log-binomial, Cox, or Poisson** (per team decision; this is initial analysis).
- The stated “hypotheses” for Obj 2 and 3 act as **rationale/expectations**, not as formal statistical null hypotheses.
- Therefore **all four objectives are descriptive**; the “compare” in Obj 2 and 3 means “describe outcomes in each group” using descriptive statistics only.
