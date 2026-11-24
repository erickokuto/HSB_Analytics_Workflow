# ONE-TIME LOCAL SETUP - run this in RStudio Console with the app folder active.
# R >= 4.3 recommended. This script DOES NOT publish or upload any files.
# If XGBoost fails to install on your system, the other supported models remain available.
required <- c('shiny','ggplot2','plotly','DT','rpart','randomForest','gbm','e1071')
optional <- c('xgboost','rsconnect','dbscan')
# The cluster package provides PAM and silhouette plots. It is an R recommended package.
required <- unique(c(required,'cluster'))
for (p in c(required, optional)) {
  if (!requireNamespace(p,quietly=TRUE)) {
    message('Installing: ',p)
    tryCatch(install.packages(p,repos='https://cloud.r-project.org'),
             error=function(e)message('Could not install ',p,': ',conditionMessage(e)))
  }
}
missing <- required[!vapply(required,requireNamespace,logical(1),quietly=TRUE)]
if (length(missing)) message('Missing required packages: ',paste(missing,collapse=', ')) else message('Core dependencies installed. Run shiny::runApp(".")')
