# Offline model-engine unit checks for use inside the app directory.
source('R/core.R')
d <- labelled_hsb(clean_hsb(read_hsb('hsb.csv')))
stopifnot(nrow(d)==200, length(SCORE_COLS)==5,
          !('math' %in% allowed_predictors('high_math')),
          identical(allowed_predictors('high_subject_count'),CAT_COLS))
s <- split_indices(d,'math',70,15,2026)
stopifnot(length(intersect(s$train,s$test))==0,
          length(intersect(s$validation,s$test))==0,
          sum(vapply(s[c('train','validation','test')],length,integer(1)))==nrow(d))
a <- run_comparison(d,'math',c('read','write','ses','prog'),70,15,2026,chosen=c('Linear regression','Decision tree'))
stopifnot(nrow(a$metrics)>=1,nrow(a$detail[[a$best]]$test)>0)
b <- run_comparison(d,'high_math',c('read','science','ses'),70,15,2026,chosen=c('Logistic regression','Decision tree'))
stopifnot(nrow(b$metrics)>=1)
c <- run_comparison(d,'high_subject_count',c('ses','prog'),70,15,2026,chosen='Poisson regression')
stopifnot(nrow(c$metrics)>=1)
k <- run_clusters(d,SCORE_COLS,k=3,seed=2026)
stopifnot(nrow(k$points)==200,length(unique(k$points$cluster))==3)
# Check the new side-by-side clustering approaches using identical profiles.
ward <- run_clusters(d,SCORE_COLS,k=3,method='Hierarchical (Ward)')
stopifnot(nrow(ward$points)==nrow(d),ward$n_groups==3)
if(requireNamespace('cluster',quietly=TRUE)) {
  pam <- run_clusters(d,SCORE_COLS,k=3,method='K-medoids (PAM)')
  stopifnot(pam$n_groups==3,nrow(pam$profile)==3)
}
comparison <- compare_cluster_methods(d,SCORE_COLS,k=3)
stopifnot(nrow(comparison)==4,all(c('method','clusters','silhouette','note')%in%names(comparison)))
if(requireNamespace('dbscan',quietly=TRUE)) {
  db <- run_clusters(d,SCORE_COLS,k=3,method='DBSCAN',eps=1,min_pts=5)
  stopifnot(nrow(db$points)==nrow(d))
}
cat('PASS: CSV, splits, supervised models, K-means, Ward, PAM and clustering comparison.\n')
