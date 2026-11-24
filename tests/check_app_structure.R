# Structural validation (R only; does not launch Shiny or deploy).
# Run from the application directory: source('tests/check_app_structure.R')
file <- readLines('app.R',warn=FALSE)
required <- if(grepl('Analytics_Workflow',normalizePath(getwd(),winslash='/'))) {
  c('data_run','eda_run','infer_run','fit','cluster_run','cluster_compare','clusters','leader_chart')
} else {
  c('data_update','overview_run','cohort_run','fit','score_run','segment',
    'segment_compare','review_run','scenario_run','model_chart','segments')
}
missing <- required[!vapply(required,function(n)any(grepl(paste0("'",n,"'"),file,fixed=TRUE)),logical(1))]
if(length(missing)) stop('Missing UI/output elements: ',paste(missing,collapse=', '))
core <- paste(readLines('R/core.R',warn=FALSE),collapse='\n')
stopifnot(grepl('compare_cluster_methods <- function',core,fixed=TRUE),
          grepl('Hierarchical (Ward)',core,fixed=TRUE),
          grepl('K-medoids (PAM)',core,fixed=TRUE),
          grepl('DBSCAN',core,fixed=TRUE))
cat('PASS: Dashboard actions, plots and clustering alternatives detected.\n')
