# Proposal April 2025 — Comments summary

**Source:** Word comments in *Virological Outcomes of Dolutegravir Proposal_April_2025.docx*  
**Authors:** Nelly Maina, Douglas Gaitho, Edmon O. Obat

---

## Comments relevant to analysis plan

### 1. Log-binomial regression (Nelly → Douglas & Edmon agreed)

**Nelly Maina (28):**  
*"The protocol plans to use log-binomial regression only, despite virological failure and death being time-dependent outcomes. Should we consider Including Cox proportional hazards models or Poisson regression with person-time offsets to Estimate time to VF and Model time to death or clinical failure"*

**Douglas Gaitho (29):** *"In agreement"*  
**Edmon O. Obat (30):** *"In agreement too"*

**Implication:** The team agreed that **log-binomial only is not appropriate** because:
- Virological failure and death are **time-dependent** (time to event).
- Log-binomial treats the outcome as a single proportion and ignores follow-up time.
- Alternatives raised: **Cox proportional hazards** or **Poisson regression with person-time** for time-to-VF and time-to-death.

---

### 2. Follow-up start (T0) and immortal time bias (Nelly → Douglas & Edmon agreed)

**Nelly Maina (25):**  
*"The protocol doesn't clarify if follow-up begins on the actual date of second-line ART initiation (T0) or if there is any delay. Risk: Misclassifying exposure start could introduce immortal time bias, where participants contribute unexposed time to the exposed group"*

**Douglas Gaitho (26):** *"I propose from the time of 2nd line ART initiation, this is well documented in the EMR"*  
**Edmon O. Obat (27):** *"Echo"*

**Implication:** Follow-up (T0) = **date of second-line ART initiation**; document this clearly in the protocol.

---

### 3. Regimen switch / censoring (Nelly → Douglas agreed)

**Nelly Maina (21):** *"if patients switch between regimens after beginning second line we will censor them right?"*  
**Douglas Gaitho (22):** *"Correct"*

**Implication:** Patients who switch regimen after second-line start should be **censored** at switch (for regimen-specific analyses).

---

### 4. Data variables and abstraction (Nelly)

**Nelly Maina (24):**  
*"we need to provide details of how the data variables and how they will be abstracted / collected with the most details to ensure transparency."*

**Implication:** Protocol should specify variable definitions and abstraction rules (e.g. data dictionary, coding).

---

### 5. Subgroup analyses (Nelly → Douglas)

**Nelly Maina (31):** *"Subgroup analyses: children vs. adults, baseline CD4 strata, TB status?"*  
**Douglas Gaitho (32):** *"We could discuss this further during our call - in addition regimen, CD4 and TB stats could be part of advanced HIV disease"*

**Implication:** Consider descriptive subgroups (age, CD4, TB/advanced HIV); can be part of advanced HIV disease definition.

---

### 6. Clustering by facility (Nelly → Edmon)

**Nelly Maina (33):**  
*"The analysis plan does not mention accounting for clustering by facility (which influences care quality and outcomes). is it something that would be of importance ? if so, should we consider using robust standard errors clustered at the facility level, or mixed-effects models to adjust for within-facility correlation"*  
*(Assigned to lydiaodero@gmail.com)*

**Edmon O. Obat (34):**  
*"We can discuss further, but wouldn't that open a pandora's box given the expectation that care is standardised? The subject aspect would be the quality of adherence counselling."*

**Implication:** Facility-level clustering was raised; team to discuss (standardised care vs. clustering).

---

## Summary for analysis plan (updated per team decision)

- **Initial analysis only:** **Descriptive and comparison** — no Cox, no log-binomial, no Poisson.
- **Do not use log-binomial regression** (or Cox or Poisson) in this initial analysis.
- **Descriptive:** Counts, proportions, tables overall and by regimen (DTG/PI) and by NRTI backbone (TDF/AZT/ABC).
- **Comparison:** Present outcomes in each group side by side; no regression-based comparison.
- **T0:** Second-line ART initiation date.
- **Censoring:** At regimen switch when comparing by regimen.
- **Document:** Variable definitions and abstraction clearly; consider subgroup descriptions (age, CD4, advanced HIV/TB).  
See *Initial_analysis_plan.md* for full wording.
