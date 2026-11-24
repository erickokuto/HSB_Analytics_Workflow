# HSB dashboard release checklist (interactive verification in RStudio)

This document distinguishes source/static checks from tests that must be run with a local R installation.

## Preparation
1. From the exact app directory in RStudio, run `source("install_packages.R")`.
2. Run `source("tests/smoke_test.R")`; an error means the release is not ready.
3. Start `shiny::runApp(".")`; watch the RStudio Console for any traceback.
4. Confirm the **bundled HSB CSV** loads; then upload the sample CSV once and verify it replaces the active dataset.
5. After modifying data, press the relevant **Update** button; inspect the output changes.

## Analytics Workflow
- Data & cleaning: check quality, duplicate-ID option, preview and download after pressing Update.
- EDA: change score and grouping, press Update, inspect histogram, boxplot, mean score bars, correlation heatmap and descriptive table.
- Inference: run t-test, ANOVA, correlation and Chi-square with valid combinations; check plots and messages.
- Supervised: choose target/predictors; 70%/15%/15% default; click Train. Verify non-empty leaderboard, validation metric bar chart, selected model diagnostics and held-out test table. Repeat using binary and count targets.
- Clustering: choose K-means, Ward, PAM, DBSCAN; click Run. Verify PCA points have multiple colours, profile, cluster sizes, silhouette comparison and exports. DBSCAN needs `dbscan`; selecting a very small eps can result in all noise, which is an analytical outcome, not a crash.

## Decision Support
- Overview: change threshold, press Update overview; check all figures and KPIs.
- Cohort: change SES/programme/gender/subject, press Update cohort; verify non-empty graphs where students are present.
- Model laboratory: click Train and evaluate; verify comparison and diagnostic panels.
- Predictive evidence: after training, press Update predictive evidence and check held-out plot, partition labels and group audit (binary only).
- Segments: choose alternative method, press Run segmentation; check coloured PCA view and silhouette method comparison.
- Review priorities: change threshold/filter, press Update review queue; check register and explanatory text.
- Scenario: change minimum subjects and press Update scenario; check sensitivity curve.
- Data privacy: use de-identified teaching datasets only; do not enter identifiable records in a public demonstration.

## Deployment
- Deploy each application folder separately, not their common parent.
- Inspect `rsconnect` logs and the live URL after deployment; a successful upload does not establish that every output rendered successfully.
- Start with K-means/Ward and GLM/tree models if optional packages have server compilation/resource issues.

## 2026 connected edition: mandatory checks

- [ ] `source('tests/test_evidence_roundtrip.R')` passes (requires only bundled data and core R model libraries).
- [ ] Analytics Workflow: EDA → Update, then check histogram, groups, means, correlations, density, scatter, violin and programme chart.
- [ ] Statistical inference → Run statistical test; inspect the correlation matrix and test summary.
- [ ] Analytics Workflow → Train (70/15/15), then Update best-model feature importance; inspect horizontal bars.
- [ ] Download Analytics evidence CSV from the successful best model.
- [ ] Decision Support → Analytics connection: upload that CSV and Validate and connect evidence; check test plot and import table.
- [ ] Decision Support → Predictive evidence review: choose Imported Analytics snapshot, press Update, inspect KPI/plot/export.
- [ ] Change the data and verify an old evidence CSV is rejected; train an independent local model as a fallback.
- [ ] Decision Support → Model laboratory: fit a model and choose Locally trained model in Predictive evidence review.
- [ ] Confirm every Run/Update button responds and guidance appears if a prerequisite is missing.
