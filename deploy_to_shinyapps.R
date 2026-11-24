# SAFE SHINYAPPS.IO DEPLOYMENT HELPER
# This file contains NO deployment credentials. Do not add token or secret strings.
# BEFORE CALLING THIS FUNCTION:
#  1. Install rsconnect: install.packages('rsconnect')
#  2. In the shinyapps.io account settings obtain its setAccountInfo command.
#  3. Paste that command into YOUR PRIVATE INTERACTIVE RStudio Console only.
#  4. Open the app folder in RStudio; ensure app.R and R/core.R exist.
#  5. Source this script, then use deploy_hsb_app('your_unique_app_name').
#  GitHub publication is optional and separate from hosting a live Shiny app.
deploy_hsb_app <- function(app_name, account = NULL) {
  if (!interactive()) stop('Deployment must be initiated interactively from RStudio.')
  if (!requireNamespace('rsconnect',quietly=TRUE)) stop("Install 'rsconnect' first.")
  path <- normalizePath(getwd(),mustWork=TRUE)
  if (!file.exists(file.path(path,'app.R')) || !file.exists(file.path(path,'R','core.R'))) {
    stop('Open the specific HSB application folder (not its parent), then try again.')
  }
  if (!grepl('^[A-Za-z][A-Za-z0-9_-]{2,62}$',app_name)) stop('Choose a valid, 3–63-character shinyapps.io app name.')
  cat('Project folder:',path,'\nApplication:',app_name,'\n')
  cat('Note: Uploaded student data will be processed on the hosting platform.\n')
  answer <- readline('Type DEPLOY to publish this application to shinyapps.io: ')
  if (!identical(trimws(answer),'DEPLOY')) return(invisible(FALSE))
  args <- list(appDir=path,appName=app_name,launch.browser=FALSE)
  if (!is.null(account)) args$account <- account
  do.call(rsconnect::deployApp,args)
}
