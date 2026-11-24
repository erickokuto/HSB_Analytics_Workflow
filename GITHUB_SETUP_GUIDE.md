# GitHub publishing guide — HSB Analytics Workflow

This project is an **R Shiny analytical application**, not a static website. GitHub hosts its code; shinyapps.io hosts its running dashboard. The included `Publish_HSB_to_GitHub.R` is separate from `deploy_to_shinyapps.R`.

## First publication (RStudio)

1. Extract this complete folder to `D:/WAB 2209 StatisticalComputing 2026/HSB_Analytics_and_Decision_Support/HSB_Analytics_Workflow`. If you use another location, edit `HSB_GITHUB_DIR` in the R script.
2. Open `HSB_Analytics_Workflow.Rproj` in RStudio.
3. Open `Publish_HSB_to_GitHub.R` and click **Source once**. Sourcing only loads functions.
4. If Git for Windows is missing, install it and restart RStudio. Run `hsb_github_install()` to install R integration packages.
5. If not already authorised, run `hsb_github_setup_token()`. Sign into `erickokuto` on GitHub, create a scoped token, then run `gitcreds::gitcreds_set()` **directly in the Console**. Never place a token in a file.
6. Run `hsb_github_check()` and `hsb_github_prepare()`.
7. In the RStudio Git tab, inspect changes. Check `hsb.csv` and all other source files for release suitability, **stage approved files**, then **Commit** with a meaningful description.
8. Run `hsb_github_publish()`; type `PUBLISH` only once you approve creation of a **private** repository.
9. Verify `https://github.com/erickokuto/HSB_Analytics_Workflow`. This is the **intended** location, not a guarantee it currently exists.

### Future updates

1. Modify the code and test it locally (`shiny::runApp('.')`).
2. In RStudio Git tab: review changes → stage → Commit.
3. Run `hsb_github_push()` and confirm `PUSH`. The helper will refuse a mismatched remote or uncommitted files and never force-push.

### Making the repository public

Once you have reviewed confidentiality, permissions and Git history, GitHub → repository → **Settings → General → Danger Zone → Change repository visibility → Public**. Changing visibility is done manually; this R script does not make repositories public.

### What to upload

Application source: `app.R`, `R/`, `README.md`, tests, deployment helper, the approved demonstration `hsb.csv` and this guide. **Do not upload** secret tokens, student-level private records, deployment credentials, temporary outputs or local RStudio state. `.gitignore` does not remove previously committed secrets from Git history.

### Common problems

- **`could not find function`**: source `Publish_HSB_to_GitHub.R` once after an R restart.
- **`Uncommitted changes`**: complete the Git review and Commit first.
- **No Git tab**: open the `.Rproj` file and enable Tools → Global Options → Git/SVN.
- **`Browse[1]>`**: enter `Q` to leave debug mode.
- **GitHub repository already exists**: do not try to create it a second time. Clone or explicitly connect the existing repository, then reconcile local and remote history before pushing.
- **`source(file.choose())` repeatedly opens windows**: do not put `source()` inside a script pointing to itself. The supplied script has neither `file.choose()` nor self-sourcing.
- **GitHub repository is not an interactive app**: use the independent shinyapps.io helper to deploy the Shiny UI.

Note: The original `hsb.csv` is a teaching dataset. Review licensing and record-level confidentiality before any public release. The source model is a teaching demonstration and should not be presented as a validated student-intervention system.
