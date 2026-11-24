# HSB ANALYTICS - SHARED ANALYTICAL ENGINE
# Source this file from app.R; all data transformation and model fitting is server-side.
# No data are transmitted to external endpoints by this R code.
options(stringsAsFactors = FALSE)
SCORE_COLS <- c('read','write','math','science','socst')
CAT_COLS <- c('female','race','ses','schtyp','prog')
HSB_LABELS <- list(
  female = c('0'='Male','1'='Female'),
  race = c('1'='Hispanic','2'='Asian','3'='African American','4'='White'),
  ses = c('1'='Low','2'='Middle','3'='High'),
  schtyp = c('1'='Public','2'='Private'),
  prog = c('1'='General','2'='Academic','3'='Vocational')
)
fmt_num <- function(x, n=1) if(length(x)<1 || !is.finite(x[1])) '—' else format(round(x[1],n),nsmall=n,big.mark=',')
clamp <- function(x,a,b) pmax(a,pmin(b,x))
read_hsb <- function(path) {
  d <- utils::read.csv(path,na.strings=c('', 'NA','N/A','null'),check.names=FALSE,fileEncoding='UTF-8-BOM')
  names(d) <- trimws(tolower(names(d)))
  needed <- c('id',CAT_COLS,SCORE_COLS)
  absent <- setdiff(needed,names(d))
  if(length(absent)) stop('CSV is missing required HSB columns: ',paste(absent,collapse=', '))
  if(nrow(d)<30) stop('At least 30 student records are needed to demonstrate model validation.')
  d <- d[,needed,drop=FALSE]
  for(v in c(CAT_COLS,SCORE_COLS)) d[[v]] <- suppressWarnings(as.numeric(as.character(d[[v]])))
  for(v in CAT_COLS) {
    valid <- names(HSB_LABELS[[v]])
    d[[v]][!is.na(d[[v]]) & !as.character(d[[v]]) %in% valid] <- NA_real_
  }
  for(v in SCORE_COLS) d[[v]][!is.na(d[[v]]) & (d[[v]]<0 | d[[v]]>100)] <- NA_real_
  d$id <- as.character(d$id)
  d$id[is.na(d$id) | !nzchar(trimws(d$id))] <- paste0('missing_',which(is.na(d$id) | !nzchar(trimws(d$id))))
  d
}
clean_hsb <- function(d, deduplicate=TRUE) {
  if(deduplicate) d <- d[!duplicated(d$id),,drop=FALSE]
  rownames(d) <- NULL
  d
}
labelled_hsb <- function(d) {
  for(v in CAT_COLS) d[[v]] <- factor(as.character(d[[v]]),levels=names(HSB_LABELS[[v]]),labels=unname(HSB_LABELS[[v]]))
  d$average_score <- rowMeans(d[,SCORE_COLS,drop=FALSE],na.rm=TRUE)
  d$average_score[!is.finite(d$average_score)] <- NA_real_
  d$high_subject_count <- rowSums(as.data.frame(lapply(d[,SCORE_COLS,drop=FALSE],function(z) ifelse(is.na(z),NA_real_,as.numeric(z>=50)))),na.rm=FALSE)
  d$high_math <- ifelse(is.na(d$math),NA_integer_,as.integer(d$math>=55))
  d$high_write <- ifelse(is.na(d$write),NA_integer_,as.integer(d$write>=55))
  d$low_read <- ifelse(is.na(d$read),NA_integer_,as.integer(d$read<45))
  d
}
quality_table <- function(d) data.frame(variable=names(d), type=vapply(d,function(x)class(x)[1],character(1)),
  missing=vapply(d,function(x)sum(is.na(x)),numeric(1)),missing_pct=round(vapply(d,function(x)mean(is.na(x))*100,numeric(1)),1),
  unique=vapply(d,function(x)length(unique(x[!is.na(x)])),numeric(1)))
summary_scores <- function(d) do.call(rbind,lapply(intersect(SCORE_COLS,names(d)),function(v) {
  x <- d[[v]]; data.frame(subject=v,n=sum(!is.na(x)),mean=round(mean(x,na.rm=TRUE),2),sd=round(stats::sd(x,na.rm=TRUE),2),
    median=round(stats::median(x,na.rm=TRUE),2),min=suppressWarnings(min(x,na.rm=TRUE)),max=suppressWarnings(max(x,na.rm=TRUE)))
}))
get_problem <- function(y) {
 if(y %in% SCORE_COLS) return('regression')
 if(y %in% c('high_math','high_write','low_read')) return('classification')
 if(y=='high_subject_count') return('count')
 stop('Unsupported outcome.')
}
allowed_predictors <- function(target) {
  # Prevent direct target leakage. Count is computed from all five subject scores.
  if(target=='high_subject_count') return(CAT_COLS)
  excluded <- switch(target,high_math='math',high_write='write',low_read='read',target)
  setdiff(c(CAT_COLS,SCORE_COLS),excluded)
}
# Each training run has one reproducible partition. Validation selects a model;
# test provides a final hold-out check. The test set is never used to choose a model.
split_indices <- function(d, target, train_pct=70, validation_pct=15, seed=2026) {
  n <- nrow(d); stopifnot(train_pct>=40, train_pct<=85, validation_pct>=5, validation_pct<=35)
  if(train_pct+validation_pct>90) stop('Reserve at least 10% for testing.')
  good <- which(!is.na(d[[target]]))
  if(length(good)<35) stop('At least 35 labelled records are needed for the chosen outcome.')
  set.seed(seed)
  if(get_problem(target)=='classification') {
    lab <- d[[target]][good]
    if(length(unique(lab))<2) stop('Binary target has only one class. Choose another outcome.')
    bins <- split(good,lab)
    # Stratified partition for a more stable small-sample evaluation.
    groups <- lapply(bins,sample)
    tr <- unlist(lapply(groups,function(x)head(x,floor(length(x)*train_pct/100))))
    va <- unlist(lapply(groups,function(x) {a<-floor(length(x)*train_pct/100);b<-floor(length(x)*validation_pct/100);if(b) x[seq.int(a+1,a+b)] else integer()}))
    te <- setdiff(good,c(tr,va))
  } else {
    ix <- sample(good)
    a <- floor(length(ix)*train_pct/100); b <- floor(length(ix)*validation_pct/100)
    tr <- ix[seq_len(a)];va <- ix[seq.int(a+1,a+b)];te <- setdiff(good,c(tr,va))
  }
  if(min(length(tr),length(va),length(te))<5) stop('Too few rows in a split. Increase the dataset size or revise the percentages.')
  list(train=tr,validation=va,test=te,unlabelled=setdiff(seq_len(n),good))
}
# Fit preprocessing parameters using TRAINING rows only. Avoid leakage by never
# estimating medians/level replacements from validation or test observations.
fit_preprocessor <- function(train,predictors) {
  dat <- train[,predictors,drop=FALSE]; med <- list();mode <- list();levels_by_cat <- list()
  for(v in predictors) {
    if(v %in% CAT_COLS) {
      xx <- as.character(dat[[v]]);xx <- xx[!is.na(xx)]
      mode[[v]] <- if(length(xx)) names(sort(table(xx),decreasing=TRUE))[1] else levels(train[[v]])[1]
      levels_by_cat[[v]] <- if(is.factor(train[[v]])) levels(train[[v]]) else sort(unique(xx))
    } else {
      med[[v]] <- if(all(is.na(dat[[v]]))) 0 else stats::median(dat[[v]],na.rm=TRUE)
    }
  }
  list(predictors=predictors, med=med,mode=mode,levels=levels_by_cat)
}
apply_preprocessor <- function(d, pp) {
  x <- d[,pp$predictors,drop=FALSE]
  for(v in pp$predictors) {
    if(v %in% CAT_COLS) {
      zz <- as.character(x[[v]]); zz[is.na(zz) | !(zz %in% pp$levels[[v]])] <- pp$mode[[v]]
      x[[v]] <- factor(zz,levels=pp$levels[[v]])
    } else { zz <- suppressWarnings(as.numeric(x[[v]]));zz[!is.finite(zz)] <- pp$med[[v]];x[[v]] <- zz }
  }
  x
}
# Evaluation metrics are computed on the validation/test predictions, not training.
model_metrics <- function(y,pred,kind,cutoff=.5) {
 ok <- is.finite(y) & is.finite(pred);y<-y[ok];pred<-pred[ok]
 if(!length(y)) return(data.frame(metric='No valid observations',value=NA_real_))
 if(kind=='classification') {
   q<-as.integer(pred>=cutoff);tp<-sum(y==1&q==1);tn<-sum(y==0&q==0);fp<-sum(y==0&q==1);fn<-sum(y==1&q==0)
   auc <- if(length(unique(y))==2) { pos<-pred[y==1]; neg<-pred[y==0];mean(outer(pos,neg,'>')+.5*outer(pos,neg,'==')) } else NA_real_
   return(data.frame(metric=c('AUC','Accuracy','Precision','Recall','F1','Brier'),value=c(auc,mean(q==y),if(tp+fp) tp/(tp+fp) else NA_real_,if(tp+fn) tp/(tp+fn) else NA_real_,if(2*tp+fp+fn) 2*tp/(2*tp+fp+fn) else NA_real_,mean((y-pred)^2))))
 }
 if(kind=='count') return(data.frame(metric=c('MAE','RMSE','Poisson deviance'),value=c(mean(abs(y-pred)),sqrt(mean((y-pred)^2)),mean(2*(ifelse(y==0,0,y*log(pmax(y,1e-12)/pmax(pred,1e-9)))-(y-pred))))))
 data.frame(metric=c('RMSE','MAE','R-squared'),value=c(sqrt(mean((y-pred)^2)),mean(abs(y-pred)),if(sum((y-mean(y))^2)>0)1-sum((y-pred)^2)/sum((y-mean(y))^2) else NA_real_))
}
model_names <- function(kind) {
 if(kind=='classification') c('Logistic regression','Decision tree','Random forest','Gradient boosting','XGBoost','Support vector machine')
 else if(kind=='count') c('Poisson regression','Decision tree','Random forest','Gradient boosting','XGBoost')
 else c('Linear regression','Decision tree','Random forest','Gradient boosting','XGBoost','Support vector machine')
}
# Constant numeric matrix encoding: training-based categorical levels only.
make_matrix <- function(x,columns=NULL) {
 if(!ncol(x)) stop('Choose at least one predictor.')
 mm <- stats::model.matrix(~ . - 1,data=x)
 if(is.null(columns)) return(mm)
 z<-matrix(0,nrow(mm),length(columns),dimnames=list(NULL,columns));shared<-intersect(colnames(mm),columns)
 if(length(shared)) z[,shared]<-mm[,shared,drop=FALSE]
 z
}
fit_model <- function(name,kind,x,y) {
  form <- stats::reformulate(names(x),response='outcome')
  df <- data.frame(outcome=y,x,check.names=TRUE)
  # All predictor names are safe HSB names; only previously preprocessed data used.
  if(name=='Linear regression') return(list(fit=stats::lm(form,data=df),engine='lm'))
  if(name=='Logistic regression') return(list(fit=stats::glm(form,data=df,family=stats::binomial()),engine='glm_binomial'))
  if(name=='Poisson regression') return(list(fit=stats::glm(form,data=df,family=stats::poisson()),engine='glm_poisson'))
  if(name=='Decision tree') { if(kind=='classification') df$outcome <- factor(y, levels=c(0,1)); return(list(fit=rpart::rpart(form,data=df,method=if(kind=='classification')'class' else if(kind=='count')'poisson' else 'anova',control=rpart::rpart.control(cp=.005,minsplit=8,maxdepth=6)),engine='rpart')) }
  if(name=='Random forest') {
    if(!requireNamespace('randomForest',quietly=TRUE)) stop('Package randomForest not installed.')
    df$outcome <- if(kind=='classification') factor(y,levels=c(0,1)) else y
    return(list(fit=randomForest::randomForest(form,data=df,ntree=150,importance=TRUE),engine='rf'))
  }
  if(name=='Gradient boosting') {
    if(!requireNamespace('gbm',quietly=TRUE)) stop('Package gbm not installed.')
    dist <- if(kind=='classification') 'bernoulli' else if(kind=='count') 'poisson' else 'gaussian'
    return(list(fit=gbm::gbm(form,data=df,distribution=dist,n.trees=120,interaction.depth=2,shrinkage=.04,n.minobsinnode=5,bag.fraction=.8,verbose=FALSE),engine='gbm'))
  }
  if(name=='XGBoost') {
    if(!requireNamespace('xgboost',quietly=TRUE)) stop('Package xgboost not installed.')
    mm<-make_matrix(x)
    obj<-if(kind=='classification') 'binary:logistic' else if(kind=='count') 'count:poisson' else 'reg:squarederror'
    model<-xgboost::xgb.train(params=list(objective=obj,max_depth=2,eta=.08,subsample=.85,colsample_bytree=.9,nthread=1),data=xgboost::xgb.DMatrix(mm,label=y),nrounds=80,verbose=0)
    return(list(fit=model,engine='xgb',columns=colnames(mm)))
  }
  if(name=='Support vector machine') {
    if(!requireNamespace('e1071',quietly=TRUE)) stop('Package e1071 not installed.')
    df$outcome <- if(kind=='classification') factor(y,levels=c(0,1)) else y
    return(list(fit=e1071::svm(form,data=df,type=if(kind=='classification')'C-classification' else 'eps-regression',kernel='radial',probability=(kind=='classification'),scale=TRUE),engine='svm'))
  }
  stop('Unrecognised model engine.')
}
predict_model <- function(object,x,kind) {
  eng<-object$engine; fit<-object$fit
  if(eng=='lm') p<-stats::predict(fit,newdata=x)
  else if(eng=='glm_binomial') p<-stats::predict(fit,newdata=x,type='response')
  else if(eng=='glm_poisson') p<-stats::predict(fit,newdata=x,type='response')
  else if(eng=='rpart') {
    if(kind=='classification') { z<-stats::predict(fit,newdata=x,type='prob');p<-if('1'%in%colnames(z))z[,'1'] else rep(0,nrow(x)) }
    else p<-stats::predict(fit,newdata=x,type='vector')
  } else if(eng=='rf') {
    if(kind=='classification') {z<-stats::predict(fit,newdata=x,type='prob');p<-z[,'1']}
    else p<-stats::predict(fit,newdata=x)
  } else if(eng=='gbm') p<-stats::predict(fit,newdata=x,n.trees=120,type='response')
  else if(eng=='xgb') p<-stats::predict(fit,make_matrix(x,object$columns))
  else if(eng=='svm') {
    z<-stats::predict(fit,newdata=x,probability=(kind=='classification'))
    if(kind=='classification') {q<-attr(z,'probabilities');p<-if(!is.null(q) && '1'%in%colnames(q)) q[,'1'] else as.numeric(as.character(z))} else p<-as.numeric(z)
  } else stop('Unknown fitted model.')
  p<-as.numeric(p)
  if(kind=='classification') p<-clamp(p,0,1)
  if(kind=='count') p<-pmax(0,p)
  p
}
# We do not auto-install packages during a live session on shinyapps.io.
run_comparison <- function(d,target,predictors,train_pct=70,valid_pct=15,seed=2026,chosen=NULL) {
 kind<-get_problem(target)
 preds<-intersect(predictors,allowed_predictors(target))
 if(!length(preds)) stop('Choose at least one non-leaking predictor.')
 ix<-split_indices(d,target,train_pct,valid_pct,seed)
 pp<-fit_preprocessor(d[ix$train,,drop=FALSE],preds)
 xt<-apply_preprocessor(d[ix$train,,drop=FALSE],pp)
 xv<-apply_preprocessor(d[ix$validation,,drop=FALSE],pp)
 xs<-apply_preprocessor(d[ix$test,,drop=FALSE],pp)
 ytr<-d[[target]][ix$train];yv<-d[[target]][ix$validation];ys<-d[[target]][ix$test]
 candidates<-model_names(kind);if(!is.null(chosen)) candidates<-intersect(candidates,chosen)
 if(!length(candidates)) stop('No compatible models selected.')
 out<-list();issues<-character();vals<-list();fits<-list()
 set.seed(seed)
 for(m in candidates) {
   tryCatch({
     f<-fit_model(m,kind,xt,ytr)
     pv<-predict_model(f,xv,kind);pt<-predict_model(f,xs,kind)
     mv<-model_metrics(yv,pv,kind);mt<-model_metrics(ys,pt,kind)
     # Compare on validation only. Test statistics are reported descriptively.
     key<-if(kind=='classification')'AUC' else if(kind=='regression')'RMSE' else 'Poisson deviance'
     score<-mv$value[match(key,mv$metric)]
     out[[m]]<-data.frame(model=m,validation_metric=key,validation_score=score,
       test_metric=key,test_score=mt$value[match(key,mt$metric)],stringsAsFactors=FALSE)
     vals[[m]]<-list(validation=data.frame(id=d$id[ix$validation],observed=yv,predicted=pv),test=data.frame(id=d$id[ix$test],observed=ys,predicted=pt),
        full_metrics=rbind(transform(mv,partition='Validation'),transform(mt,partition='Test')))
     fits[[m]]<-f
   },error=function(e){issues<<-c(issues,paste(m,':',conditionMessage(e)))})
 }
 if(!length(out)) stop('No model fitted successfully. ',paste(issues,collapse='; '))
 scores<-do.call(rbind,out);scores<-scores[order(scores$validation_score,decreasing=(kind=='classification'),na.last=TRUE),,drop=FALSE]
 best<-as.character(scores$model[1]); rownames(scores)<-NULL
 list(kind=kind,target=target,predictors=preds,split=ix,pp=pp,metrics=scores,detail=vals,models=fits,best=best,issues=issues,
      counts=c(train=length(ix$train),validation=length(ix$validation),test=length(ix$test),unlabelled=length(ix$unlabelled)))
}
score_model <- function(result, d, name=NULL) {
 if(is.null(name)) name<-result$best
 if(!(name %in% names(result$models))) stop('The selected model was not successfully trained.')
 x<-apply_preprocessor(d,result$pp)
 predict_model(result$models[[name]],x,result$kind)
}
# Four exploratory clustering choices on the SAME standardised score matrix.
# K-means optimises compactness around centroids; Ward hierarchical merges
# similar students; PAM uses actual medoids; DBSCAN finds density-based groups
# and may label unusual students as noise (0). None denotes academic merit.
prepare_cluster_data <- function(d, features) {
  features <- intersect(features, SCORE_COLS)
  if(length(features)<2) stop('Select at least two subject scores.')
  x <- d[,features,drop=FALSE]
  for(v in features) {
    x[[v]] <- suppressWarnings(as.numeric(x[[v]]))
    if(all(!is.finite(x[[v]]))) stop('Subject ',v,' has no valid values.')
    x[[v]][!is.finite(x[[v]])] <- stats::median(x[[v]][is.finite(x[[v]])])
  }
  s <- scale(as.matrix(x))
  # Constant score columns have zero standard deviation: set to zero safely.
  s[!is.finite(s)] <- 0
  if(ncol(s)<2 || nrow(unique(s))<2) stop('Insufficient distinct score profiles for clustering.')
  list(raw=x, scaled=s, features=features)
}
cluster_quality <- function(s, assignments) {
  ids <- sort(unique(assignments[assignments>0]))
  if(length(ids)<2) return(NA_real_)
  # Average silhouette, excluding DBSCAN noise. Only compare with caution:
  # density-based noise points alter the effective population being evaluated.
  good <- which(assignments>0)
  if(length(good)>1500) return(NA_real_)  # avoid large pairwise matrices
  if(!requireNamespace('cluster',quietly=TRUE)) return(NA_real_)
  si <- tryCatch(cluster::silhouette(as.integer(factor(assignments[good])),
                                     stats::dist(s[good,,drop=FALSE])),
                 error=function(e)NULL)
  if(is.null(si)) NA_real_ else mean(si[,'sil_width'])
}
run_clusters <- function(d, features, k=3, seed=2026, method='K-means',
                         eps=1.0, min_pts=5) {
  prep <- prepare_cluster_data(d,features)
  s<-prep$scaled
  if(k<2 || k>nrow(unique(s))) stop('Choose k between 2 and the distinct profile count.')
  set.seed(seed)
  labels <- switch(method,
    'K-means'=stats::kmeans(s,centers=k,nstart=25,iter.max=150)$cluster,
    'Hierarchical (Ward)'=stats::cutree(stats::hclust(stats::dist(s),method='ward.D2'),k=k),
    'K-medoids (PAM)'={
      if(!requireNamespace('cluster',quietly=TRUE)) stop('Install package cluster for PAM.')
      cluster::pam(s,k=k,cluster.only=TRUE)
    },
    'DBSCAN'={
      if(!requireNamespace('dbscan',quietly=TRUE)) stop('Install package dbscan for density clustering.')
      dbscan::dbscan(s,eps=eps,minPts=min_pts)$cluster
    },
    stop('Unknown clustering method.')
  )
  labels<-as.integer(labels)
  # PCA is a projection for DISPLAY, not a second clustering fit.
  pc<-stats::prcomp(s,center=FALSE,scale.=FALSE)
  pc1<-pc$x[,1]
  pc2<-if(ncol(pc$x)>=2) pc$x[,2] else rep(0,nrow(s))
  ev<-pc$sdev^2; share<-if(sum(ev)>0) ev/sum(ev) else rep(0,length(ev))
  variance<-c(share[1],if(length(share)>=2)share[2] else 0)
  labels_for_plot<-ifelse(labels==0,'Noise',paste0('Cluster ',labels))
  levels_plot<-unique(c(paste0('Cluster ',sort(unique(labels[labels>0]))),if(any(labels==0))'Noise'))
  pts<-data.frame(id=d$id,PC1=as.numeric(pc1),PC2=as.numeric(pc2),
                  cluster=factor(labels_for_plot,levels=levels_plot),cluster_id=labels)
  profile<-do.call(rbind,lapply(sort(unique(labels)),function(z){
    idx<-which(labels==z)
    data.frame(cluster=if(z==0)'Noise' else paste0('Cluster ',z),n=length(idx),
               as.list(vapply(prep$raw[idx,,drop=FALSE],mean,numeric(1))),
               check.names=FALSE)
  }))
  rownames(profile)<-NULL
  list(points=pts,profile=profile,features=features,method=method,
       share_variance=variance,labels=labels,quality=cluster_quality(s,labels),
       n_groups=length(unique(labels[labels>0])),noise=sum(labels==0),
       scaled=s)
}
# Compare alternatives on IDENTICAL input features and selected k.
# Silhouette is internal structure, not predictive accuracy or evidence of
# genuine learning differences. DBSCAN chooses its own number of clusters.
compare_cluster_methods <- function(d,features,k=3,seed=2026,eps=1.0,min_pts=5) {
  methods<-c('K-means','Hierarchical (Ward)','K-medoids (PAM)','DBSCAN')
  result<-lapply(methods,function(m){
    tryCatch({z<-run_clusters(d,features,k,seed,m,eps,min_pts)
      data.frame(method=m,clusters=z$n_groups,noise=z$noise,
                 silhouette=round(z$quality,3),note=if(m=='DBSCAN')'Density; k not used' else 'Fixed k',
                 stringsAsFactors=FALSE)
    },error=function(e)data.frame(method=m,clusters=NA_integer_,noise=NA_integer_,
                                  silhouette=NA_real_,note=conditionMessage(e),stringsAsFactors=FALSE))
  })
  do.call(rbind,result)
}

# Model-agnostic permutation importance on the VALIDATION partition (not test).
# Higher values mean that disrupting the feature worsened validation performance.
# Importance is predictive, not causal. Small validation sets make it unstable.
permutation_importance <- function(result,d,model_name=NULL,seed=2026) {
  if(is.null(model_name)) model_name <- result$best
  ix <- result$split$validation
  base <- d[ix,,drop=FALSE]
  actual <- base[[result$target]]
  pred <- score_model(result,base,model_name)
  kind <- result$kind
  key <- if(kind=='classification') 'AUC' else if(kind=='regression') 'RMSE' else 'Poisson deviance'
  get_score <- function(p) {
    z<-model_metrics(actual,p,kind)
    z$value[match(key,z$metric)]
  }
  original <- get_score(pred)
  set.seed(seed)
  items <- lapply(result$predictors,function(v){
    mutated<-base
    mutated[[v]]<-sample(mutated[[v]])
    after<-get_score(score_model(result,mutated,model_name))
    data.frame(predictor=v,impact=if(kind=='classification') original-after else after-original)
  })
  z<-do.call(rbind,items)
  z[order(z$impact,decreasing=TRUE),,drop=FALSE]
}

# ----------------------------------------------------------------------------
# Robust correlation heatmap: direct plotly avoids ggplotly tile-label conversion
# errors ("subscript out of bounds") on some versions of Plotly/ggplot2.
# The same function is used by EDA, inference and Decision Support.
# ----------------------------------------------------------------------------
hsb_corr_plot <- function(d, vars=SCORE_COLS, title='Subject-score correlations') {
  v <- intersect(vars, names(d))
  if (length(v) < 2L) stop('Choose at least two available numerical scores.')
  x <- d[, v, drop=FALSE]
  x[] <- lapply(x, function(z) suppressWarnings(as.numeric(z)))
  cm <- suppressWarnings(stats::cor(x, use='pairwise.complete.obs'))
  cm[!is.finite(cm)] <- NA_real_
  # plot_ly expects matrix of z values; x and y are explicit, not lookup expressions
  plotly::plot_ly(x=colnames(cm), y=rownames(cm), z=cm,
    type='heatmap', zmin=-1, zmax=1, colorscale='RdBu', reversescale=TRUE,
    hovertemplate='%{y} vs %{x}: %{z:.2f}<extra></extra>') |>
    plotly::layout(title=title, xaxis=list(title=''), yaxis=list(title=''))
}

# ----------------------------------------------------------------------------
# Validated, portable results exchange (CSV, NEVER an uploaded RDS/RData object).
# Analytics exports a model-specific evidence snapshot; Decision Support imports
# it as an *external snapshot*, not a live connection or a deployable model.
# This keeps user data separate from model code and avoids R deserialisation risk.
# ----------------------------------------------------------------------------
hsb_evidence_export <- function(result, d) {
  if (is.null(result$best) || !(result$best %in% names(result$models)))
    stop('Train a successful model before exporting evidence.')
  prediction <- score_model(result, d, result$best)
  p <- rep('Not labelled',nrow(d))
  p[result$split$train] <- 'Training (in-sample)'
  p[result$split$validation] <- 'Validation'
  p[result$split$test] <- 'Held-out test'
  best_row <- result$metrics[result$metrics$model==result$best,,drop=FALSE]
  data.frame(
    student_id=as.character(d$id),
    observed=as.numeric(d[[result$target]]),
    predicted=as.numeric(prediction),
    partition=p,
    target=result$target,
    outcome_family=result$kind,
    model=result$best,
    validation_metric=best_row$validation_metric[1],
    validation_score=as.numeric(best_row$validation_score[1]),
    test_score=as.numeric(best_row$test_score[1]),
    female=as.character(d$female),
    ses=as.character(d$ses),
    prog=as.character(d$prog),
    stringsAsFactors=FALSE
  )
}
hsb_evidence_import <- function(path, active_data) {
  z <- utils::read.csv(path, stringsAsFactors=FALSE, check.names=FALSE,
    na.strings=c('', 'NA','N/A'))
  expected <- c('student_id','observed','predicted','partition','target',
                'outcome_family','model','validation_metric','validation_score',
                'test_score','female','ses','prog')
  absent <- setdiff(expected,names(z))
  if(length(absent)) stop('Evidence CSV is missing: ',paste(absent,collapse=', '))
  if(nrow(z)!=nrow(active_data) || anyDuplicated(z$student_id) ||
     !setequal(as.character(z$student_id),as.character(active_data$id)))
    stop('Evidence student IDs do not match the current dataset. Upload the SAME CSV dataset to both applications before importing.')
  z <- z[match(as.character(active_data$id), z$student_id),,drop=FALSE]
  if(anyNA(z$student_id)) stop('Student ID matching failed.')
  for(nm in c('observed','predicted','validation_score','test_score'))
    z[[nm]] <- suppressWarnings(as.numeric(z[[nm]]))
  if(any(!is.finite(z$predicted))) stop('Evidence contains invalid predictions.')
  for(nm in c('target','outcome_family','model','validation_metric')) {
    if(length(unique(z[[nm]]))!=1L || is.na(z[[nm]][1]))
      stop('Evidence must contain exactly one fitted model and outcome: ',nm)
  }
  if(!z$target[1] %in% c(SCORE_COLS,'high_math','high_write','low_read','high_subject_count'))
    stop('Unsupported target in evidence file.')
  valid_parts <- c('Training (in-sample)','Validation','Held-out test','Not labelled')
  if(anyNA(z$partition) || any(!z$partition %in% valid_parts)) stop('Invalid partition labels.')
  if(sum(z$partition=='Held-out test')<5L) stop('Evidence contains too few test records.')
  # Check record identity and observed outcomes independently of uploaded evidence.
  d <- labelled_hsb(clean_hsb(active_data,FALSE))
  truth <- suppressWarnings(as.numeric(d[[z$target[1]]]))
  if(any(abs(z$observed - truth)>1e-6, na.rm=TRUE) ||
     any(xor(is.na(z$observed),is.na(truth))))
    stop('Observed outcomes do not match the active HSB dataset.')
  z
}
