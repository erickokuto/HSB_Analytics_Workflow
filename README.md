# High School and Beyond (HSB) | R Shiny dashboard

## Purpose and audience

This is a **teaching and research demonstration** using the High School and Beyond (HSB) data sample: 200 students and 11 columns. It is not a production early-warning system, a diagnostic instrument, an intervention allocation engine or a substitute for qualified educational judgement.

**Unit of observation:** a student record. Each uploaded CSV replaces the sample dataset for that session; data are not appended or automatically saved.

## Upload once, split within the app

1. Launch the app. It starts with `hsb.csv` (200 students) bundled in this folder.
2. Optionally upload **one** CSV with columns `id,female,race,ses,schtyp,prog,read,write,math,science,socst`.
3. Select the modelling target and predictors. Target-derived columns are excluded from predictors.
4. Set **training 70% / validation 15% / testing 15%** (defaults). Testing is the remainder of 100% and must be at least 10%.
5. Click **Train and compare**. The model is fitted only to training rows; feature imputation parameters are estimated only on training rows.
6. Inspect validation metrics for model ranking and independent test metrics for final reporting. Export results as CSV.
7. In the clustering tab, choose **K-means**, **hierarchical Ward clustering**, **PAM/K-medoids** or **DBSCAN**. Press **Run clustering and compare** (or **Run segmentation and compare**) to draw colour-coded PCA points and compare silhouette widths.
8. Use each section's explicit **Update** button after changing inputs. The dashboard uses its bundled HSB sample for initial displays and displays helpful instructions for sections awaiting a model fit.

### Data dictionary

| Column | Interpretation |
| --- | --- |
| id | student identifier (never a model predictor) |
| female | 0 = male; 1 = female |
| race | 1 = Hispanic; 2 = Asian; 3 = African American; 4 = White |
| ses | 1 = low; 2 = middle; 3 = high |
| schtyp | 1 = public; 2 = private |
| prog | 1 = general; 2 = academic; 3 = vocational |
| read, write, math, science, socst | standardised test scores for the respective subjects |

**Derived demonstration targets:** `high_math` = math ≥55; `high_write` = write ≥55; `low_read` = read <45; `high_subject_count` = number of subject scores ≥50 when all five are present. These are not observed interventions or validated support-need indicators.

**Model choice and measurement:** Predictive regression outcomes use RMSE and MAE (also test R²). Binary outcomes use AUC, accuracy, precision, recall, F1 and Brier score. Poisson/count outcomes use Poisson deviance, MAE and RMSE. Classification thresholds are 0.50 for standard reported classification metrics; the decision-support evidence tab permits exploratory threshold changes.

**Available model families:** linear / logistic / Poisson GLM; decision tree; random forest; gradient boosting (GBM); XGBoost; support vector machine where appropriate. Optional models may be unavailable if their R package cannot be installed; the application reports failed engines instead of claiming they ran.

**Interactive run buttons:** In Analytics Workflow, data quality, EDA, inference, supervised models and clustering each have explicit Run/Update buttons. In Decision Support, command overview, cohort exploration, model training, predictive evidence review, segmentation, review queue and threshold scenarios have their own controls. This prevents unnoticed re-computation when changing sliders. Updated score-based flags remain *illustrative* and do not constitute validated student risk predictions.

**Clustering comparison:** K-means and hierarchical Ward clustering are available via base R; PAM and silhouette use the `cluster` package. DBSCAN requires the optional `dbscan` package; if unavailable, the comparison table explains why. All methods use the same imputed, standardised score features. Silhouette width is an internal compactness/separation measure, **not supervised accuracy**. DBSCAN can identify noise and chooses its own number of groups.

**Missing data:** mandatory named fields are required. Invalid categorical codes or out-of-range scores (outside 0–100) become missing. Duplicate IDs may be removed. Numerical predictors are median-imputed using training data; categorical predictors use training mode. Outcome-missing students are not used for supervised training, validation or testing. K-means uses median imputation and score standardisation.

**Limitations:** The 200-record historical teaching dataset is small and does not contain future educational outcomes, programme costs, exposure to interventions, learner wellbeing or formal needs assessments. Small validation/test partitions give uncertain metrics. A random hold-out split supports teaching, not longitudinal forecasting or causal conclusions. Where scores appear as predictors for other scores, relationships can be strong but are not causal explanations. Race/ethnicity and other group variables should never be used as grounds for automated high-stakes decisions. Review bias, privacy and local law before using real records.

## Running locally in RStudio

1. Extract the full ZIP. Keep `app.R`, `R/`, `hsb.csv` together.
2. Open RStudio. Install Git only if you intend to use GitHub; Git is not required for Shiny.
3. With this folder set as your working directory, run `source('install_packages.R')` once.
4. Run `shiny::runApp('.')`. The Shiny interface should open.
5. The model training controls require an explicit click and can take some time, especially XGBoost.

## Deploying to shinyapps.io

1. Create/sign into your [shinyapps.io account](https://www.shinyapps.io/).
2. In RStudio, install `rsconnect`, then visit **shinyapps.io → Account → Tokens** to generate a deployment token. **Do not paste token/secret values into a file committed to GitHub.** Follow the account-specific `rsconnect::setAccountInfo(...)` command provided by shinyapps.io **in the interactive R Console only**, or use RStudio's publish wizard.
3. Source `deploy_to_shinyapps.R`, then call `deploy_hsb_app()` with your desired app name (see its comments). It asks before deployment. Alternatively use the RStudio **Publish** button.
4. After deployment, open the generated `https://ACCOUNT.shinyapps.io/APPNAME/` address and smoke-test upload, split and model comparison.
5. Hosting can require more memory or package compilation resources for XGBoost. If compilation fails, run the other algorithms first; review the deployment logs. The code does not need Python.

**Security:** Uploaded student data are processed in the active Shiny R session, but data transit and server logs remain subject to the hosting provider's controls. Do not upload identifiable educational records to a publicly accessible application without authorisation, appropriate safeguards and privacy assessment. Public Shiny access and public GitHub repository visibility are different settings.

## Source documentation

- OpenIntro / UCLA, HSB2 sample: https://www.openintro.org/data/index.php?data=hsb2
- UCLA OARC, statistical methods examples: https://stats.oarc.ucla.edu/spss/whatstat/what-statistical-analysis-should-i-usestatistical-analyses-using-spss/
- R Shiny: https://shiny.posit.co/
- shinyapps.io deployment: https://docs.posit.co/shinyapps.io/

## Reproducibility and verification

- All source files are plain R and human-readable.
- Run `source('tests/smoke_test.R')` locally to verify data schemas, leakage guards, splitting, evaluation and multiple clustering methods. Run `source('tests/check_app_structure.R')` to confirm that the Run buttons and comparison outputs are present. Also perform the UI tests listed in `QA_CHECKLIST.md`.
- RStudio validation is necessary before production use. No claim is made that code was executed on shinyapps.io during package preparation.


## Connected Analytics → Decision Support hand-off (2026 update)

These are **two separately deployed Shiny applications**. They cannot directly
share reactive memory on shinyapps.io. For an explicit connection, fit the
models in Analytics Workflow, then download **Analytics → Decision Support
evidence CSV**. Open Decision Support on the **Analytics connection** tab,
upload that CSV and press **Validate and connect evidence**. A matching active
HSB dataset with the same student IDs and observed target values is required.
Then open **Predictive evidence review**, select **Imported Analytics snapshot**
and press **Update predictive evidence**. Alternatively select **Locally trained
model** after fitting in Model laboratory. This is a results snapshot, NOT an
automatically synchronised model or API. It contains student-level data; do
not publicly share downloaded exports derived from identifiable student data.

### Additional graphics
Analytics now includes density by group, a subject-pair scatter plot, score
violin plots, programme means, a direct Plotly correlation matrix in inference,
and a horizontal permutation-importance plot for the validation-selected best
model. Press the relevant section's Run/Update button to refresh.

### Deployment verification
Run `source('install_packages.R')`, `source('tests/smoke_test.R')`, and
`shiny::runApp('.')` in the application folder. Then test the CSV hand-off
end-to-end with the bundled dataset. RStudio and shinyapps.io execution have
not been verified by the generator; check each section locally before
production deployment.


## Publish the source on GitHub (separate from shinyapps.io)

The included `Publish_HSB_to_GitHub.R` provides an explicit, beginner-oriented
workflow for creating and maintaining a **private** GitHub repository under
`erickokuto/HSB_Analytics_Workflow`. Start with `GITHUB_SETUP_GUIDE.md`.
Sourcing the script does **not** automatically publish anything.

`deploy_to_shinyapps.R` remains the separate helper for running the live app on
shinyapps.io. GitHub source-code visibility does not change live Shiny access.
