# HSB ANALYTICS WORKFLOW - standalone shinyapps.io application.
# One upload -> validation -> user-selected training/validation/test split.
# The application contains no dependency on Python or the reference projects.
# Models fit ONLY when the user presses 'Train and compare models'.
library(shiny)
library(ggplot2)
library(plotly)
library(DT)
source('R/core.R',local=TRUE)
source('R/theme.R',local=TRUE)
options(shiny.maxRequestSize=25*1024^2)

ui <- navbarPage('HSB | ANALYTICS WORKFLOW',id='page',header=tags$head(tags$style(HTML(HSB_CSS))),
 tabPanel('1 · Data & cleaning',
  hero('High School & Beyond | Analytical Workflow','From one uploaded student CSV to reproducible data quality, EDA, inference, model development and evaluation.'),
  fluidRow(column(4,card(h3('Dataset source'),fileInput('upload','Upload a single HSB-format CSV',accept='.csv'),
     actionButton('reset_data','Restore bundled HSB dataset'),downloadButton('template','Download HSB sample CSV'),
     checkboxInput('dedup','Remove duplicate student IDs (keep first)',TRUE),
     actionButton('data_run','Update data quality and cleaning results',class='btn-primary'),
     p('The default 200-row dataset loads automatically. Uploading a replacement CSV clears previous fitted models. No train/test CSV files are needed.'),
     tags$small('Required: id, female, race, ses, schtyp, prog, read, write, math, science, socst.'))),
   column(8,uiOutput('data_kpis'),card(h3('Raw-data quality and missingness'),DTOutput('quality')))),
  card(h3('Cleaned data preview'),DTOutput('preview'),downloadButton('clean_export','Download cleaned CSV')),
  card(h3('Variable dictionary'),DTOutput('dictionary'))),
 tabPanel('2 · Exploratory analysis',
  hero('Explore student attainment','Distributional patterns, programme differences and correlations are descriptive, not causal.'),
  fluidRow(column(3,card(selectInput('eda_score','Subject',SCORE_COLS,selected='math'),
                      selectInput('eda_group','Stratify by',c('None',CAT_COLS),selected='ses'),
                      actionButton('eda_run','Update exploratory analysis',class='btn-primary'))),
           column(9,uiOutput('eda_kpis'))),
  fluidRow(column(6,card(h3('Score distribution'),plotlyOutput('hist',height=350))),
           column(6,card(h3('Score by student group'),plotlyOutput('box',height=350)))),
  fluidRow(column(6,card(h3('Mean scores by subject'),plotlyOutput('bars',height=350))),
           column(6,card(h3('Subject-score correlations'),plotlyOutput('corr',height=350)))),
  fluidRow(column(6,card(h3('Score density by group'),plotlyOutput('eda_density',height=340))),
           column(6,card(h3('Subject-to-subject scatterplot'),plotlyOutput('eda_scatter',height=340)))),
  fluidRow(column(6,card(h3('Score variability by subject'),plotlyOutput('eda_violin',height=340))),
           column(6,card(h3('Subject means by programme'),plotlyOutput('eda_programme',height=340)))),
  card(h3('Descriptive statistics'),DTOutput('descriptives'))),
 tabPanel('3 · Statistical inference',
  hero('Statistical inference','Choose a test and inspect evidence, sample sizes and key assumptions.'),
  fluidRow(column(4,card(selectInput('test_kind','Statistical test',c('Independent samples t-test','One-way ANOVA','Pearson correlation','Chi-square association')),
     uiOutput('inference_controls'),actionButton('infer_run','Run statistical test',class='btn-primary'),
     warn('P-values quantify evidence under a statistical model; they do not establish causality. Check assumptions and group sizes.'))),
     column(8,card(h3('Test results'),verbatimTextOutput('infer_result'),plotlyOutput('infer_plot',height=350)))),
  card(h3('Correlation matrix · all five standardised subject scores'),
    p('Press Run statistical test to refresh the matrix; it describes linear association, not causality.'),
    plotlyOutput('infer_corr',height=410))),
 tabPanel('4 · Supervised machine learning',
  hero('Predictive models and comparison','Single-upload partitioning, training-only imputation, validation-based model choice, and untouched test-set reporting.'),
  fluidRow(column(4,
     card(selectInput('target','Outcome',choices=c('Math score'='math','Writing score'='write','Reading score'='read','Science score'='science','Social studies score'='socst',
       'Math ≥55 (binary)'='high_math','Writing ≥55 (binary)'='high_write','Reading <45 (binary)'='low_read','Number of subjects ≥50 (count)'='high_subject_count'),selected='math'),
       uiOutput('predictor_ui'),uiOutput('model_ui')),
     card(h3('Data splitting (one dataset)'),sliderInput('train_pct','Training (%)',min=40,max=85,value=70,step=5),
       sliderInput('valid_pct','Validation (%)',min=5,max=35,value=15,step=5),uiOutput('split_pct'),
       numericInput('seed','Random seed',2026,min=1,max=999999,step=1),
       actionButton('fit','Train and compare selected models',class='btn-primary'),
       p('Changing settings does not reuse earlier metrics: press Train again. All partitions are created from the same uploaded CSV.'))),
    column(8,card(h3('Evaluation status'),uiOutput('train_status')),uiOutput('model_kpis'),
      card(h3('Model leaderboard · validation selected'),DTOutput('leaderboard')),card(h3('Validation metric comparison'),plotlyOutput('leader_chart',height=340)))),
  fluidRow(column(6,card(h3('Individual model diagnostics'),uiOutput('pick_model'),DTOutput('detail_metrics'))),
           column(6,card(h3('Held-out test diagnostics'),plotlyOutput('diagnostic',height=350)))),
  card(h3('Best-model feature importance · validation partition'),
    p('Based on the model ranked first using validation results; changes in validation performance after shuffling a predictor. Positive values indicate stronger predictive contribution.'),
    actionButton('best_imp_run','Update best-model feature importance',class='btn-primary'),
    plotlyOutput('best_importance',height=345)),
  card(h3('Transfer analytical evidence to Decision Support'),
    p('Download the selected best model’s student-level evidence snapshot (CSV). In the separate Decision Support app, upload this file under “Analytics connection”. This is a deliberate snapshot, not live synchronisation or a portable trained model.'),
    downloadButton('handoff_export','Download Analytics → Decision Support evidence CSV')),
  card(h3('Permutation feature importance · validation partition'),p('Change in validation performance after shuffling a predictor. Higher positive values suggest greater predictive contribution; not a causal effect.'),plotlyOutput('importance',height=310)),
  card(h3('Test-set predictions'),DTOutput('test_predictions'),downloadButton('model_export','Download comparison metrics CSV'),
    downloadButton('pred_export','Download test predictions CSV'),
    warn('Prediction does not imply educational causation. Avoid deploying student-level classifications as automated high-stakes decisions.'))),
 tabPanel('5 · Unsupervised clustering',
   hero('Student learning-profile segmentation','K-means groups students by similarities across standardised subject scores, not by demographic identity.'),
   fluidRow(column(4,card(checkboxGroupInput('cluster_features','Subject scores',choices=SCORE_COLS,selected=SCORE_COLS),
    selectInput('cluster_method','Clustering algorithm',c('K-means','Hierarchical (Ward)','K-medoids (PAM)','DBSCAN')),
    sliderInput('k','Number of clusters (k; not used by DBSCAN)',min=2,max=7,value=3,step=1),
    conditionalPanel("input.cluster_method == 'DBSCAN'",sliderInput('eps','DBSCAN neighbourhood distance (eps)',min=.2,max=4,value=1,step=.1),
      sliderInput('min_pts','DBSCAN minimum neighbours',min=3,max=15,value=5,step=1)),
    numericInput('cluster_seed','Clustering random seed',2026,min=1),
    actionButton('cluster_run','Run clustering and compare methods',class='btn-primary'),
    p('One uploaded dataset; median imputation and standardisation. Colour-coded clusters are descriptive. The PCA plot is a two-axis projection.'))),
    column(8,card(h3('PCA projection · clusters by colour'),plotlyOutput('clusters',height=460)))),
   fluidRow(column(6,card(h3('Cluster profiles'),DTOutput('cluster_profile'))),
     column(6,card(h3('Cluster sizes'),plotlyOutput('cluster_size',height=320)))),
   card(h3('Clustering method comparison'),p('Silhouette compares within-cluster cohesion and between-cluster separation. Higher is preferable, but it is an internal descriptive criterion.'),
     DTOutput('cluster_compare'),plotlyOutput('cluster_compare_plot',height=310)),
   card(h3('Cluster-labelled student records'),DTOutput('cluster_rows'),downloadButton('cluster_export','Download cluster assignments'))),
 tabPanel('6 · Interpretation & guidance',
  hero('Responsible interpretation','Explain limitations before drawing programme or educational decisions.'),
  card(h3('What this dashboard supports'),tags$ul(tags$li('Transparent data intake, quality checks, score distributions and group comparisons.'),
   tags$li('Independent inference with assumptions and visual evidence.'),
   tags$li('Reproducible train/validation/test splits and multiple model comparisons.'),
   tags$li('Exploratory clustering for student-score profiles.'))),
  card(h3('Analytical limitations'),p('The bundled High School and Beyond extract is a historical educational sample (n=200). The variables do not contain attendance, outcomes after school, intervention exposure or programme costs.'),
   p('Count outcomes and binary outcomes in this demonstration are derived from examination scores. They are useful for teaching model families, not as validated risk or benefit labels.'),
   p('A new upload replaces the active dataset; it does not accumulate records or persist model versions. Training is performed in the active Shiny session.'),
   p('Validation selects the best model within the chosen family; hold-out test results describe performance only and should not drive model selection.'),
   tags$a(href='https://stats.oarc.ucla.edu/spss/whatstat/what-statistical-analysis-should-i-usestatistical-analyses-using-spss/',target='_blank','UCLA HSB teaching and statistical reference')))
)

server <- function(input,output,session){
 default_data <- read_hsb('hsb.csv')
 source_data <- reactiveVal(default_data)
 data_label <- reactiveVal('Bundled 200-student HSB sample')
 model_state <- reactiveVal(NULL);cluster_state<-reactiveVal(NULL)
 observeEvent(input$upload,{
   tryCatch({z<-read_hsb(input$upload$datapath);source_data(z);data_label(paste('Uploaded:',input$upload$name));model_state(NULL);cluster_state(NULL);
     showNotification('One CSV loaded. Press Update data quality and cleaning results, then rerun analysis and modelling.',type='message',duration=7)},
   error=function(e)showNotification(conditionMessage(e),type='error',duration=12))
 })
 observeEvent(input$reset_data,{source_data(default_data);data_label('Bundled 200-student HSB sample');model_state(NULL);cluster_state(NULL)})
 d<-eventReactive(input$data_run,{labelled_hsb(clean_hsb(source_data(),isTRUE(input$dedup)))},ignoreNULL=FALSE)
 observeEvent(input$dedup,{model_state(NULL);cluster_state(NULL)})
 # A changed modelling setting invalidates previous results; the learner must refit.
 observeEvent(list(input$target,input$predictors,input$models,input$train_pct,input$valid_pct,input$seed),{model_state(NULL)},ignoreInit=TRUE)
 # Clustering is calculated on demand, with a clear run button.
 cluster_compare_state<-reactiveVal(NULL)
 output$template<-downloadHandler(filename=function()'hsb_example.csv',content=function(file)write.csv(default_data,file,row.names=FALSE,na=''))
 output$clean_export<-downloadHandler(filename=function()'hsb_cleaned.csv',content=function(file)write.csv(d(),file,row.names=FALSE,na=''))
 output$data_kpis<-renderUI({x<-d();div(class='kpis',kpi('Active dataset',data_label()),kpi('Students',nrow(x)),kpi('Missing cells',sum(is.na(x[,c(CAT_COLS,SCORE_COLS)]))),kpi('Duplicate IDs in raw',sum(duplicated(source_data()$id))))})
 output$quality<-renderDT(dt(quality_table(source_data())))
 output$preview<-renderDT(dt(utils::head(d(),200)))
 output$dictionary<-renderDT(dt(data.frame(variable=c('id',CAT_COLS,SCORE_COLS),meaning=c('Student identifier','Gender: 0 male, 1 female','Race/ethnicity: 1 Hispanic, 2 Asian, 3 African American, 4 White','Socio-economic status: 1 low, 2 middle, 3 high','School type: 1 public, 2 private','Programme: 1 general, 2 academic, 3 vocational','Reading standardised score','Writing standardised score','Mathematics standardised score','Science standardised score','Social studies standardised score'))))
 eda<-eventReactive(input$eda_run,{list(data=d(),score=input$eda_score,group=input$eda_group)},ignoreNULL=FALSE)
 output$eda_kpis<-renderUI({e<-eda();x<-e$data[[e$score]];div(class='kpis',kpi('Valid n',sum(is.finite(x))),kpi('Mean',fmt_num(mean(x,na.rm=TRUE))),kpi('SD',fmt_num(sd(x,na.rm=TRUE))),kpi('Median',fmt_num(median(x,na.rm=TRUE))))})
 output$hist<-renderPlotly({e<-eda();x<-e$data
   q<-data.frame(score=as.numeric(x[[e$score]]));q<-q[is.finite(q$score),,drop=FALSE]
   validate(need(nrow(q)>1,'At least two observed scores are required.'))
   plotly::plot_ly(q,x=~score,type='histogram',nbinsx=16,
                   marker=list(color='#1b8b82',line=list(color='white',width=1))) |>
     plotly::layout(xaxis=list(title=e$score),yaxis=list(title='Number of students'),
       shapes=list(list(type='line',x0=mean(q$score),x1=mean(q$score),
                    y0=0,y1=1,yref='paper',line=list(color='#e4953f',dash='dash'))))
 })
 output$box<-renderPlotly({e<-eda();x<-e$data
   q<-data.frame(score=as.numeric(x[[e$score]]),group=if(e$group=='None')
     'All students' else as.character(x[[e$group]]))
   q<-q[is.finite(q$score)&!is.na(q$group),,drop=FALSE]
   validate(need(nrow(q)>1,'No valid observations for this score/group combination.'))
   q$group<-factor(q$group)
   plotly::plot_ly(q,x=~group,y=~score,color=~group,type='box',
                   boxpoints='outliers',showlegend=FALSE) |>
     plotly::layout(xaxis=list(title='Student group'),yaxis=list(title='Score'))
 })
 output$bars<-renderPlotly({z<-summary_scores(eda()$data)
   z<-z[is.finite(z$mean),,drop=FALSE]
   validate(need(nrow(z)>0,'No mean scores to display.'))
   plotly::plot_ly(z,x=~mean,y=~subject,type='bar',orientation='h',
     marker=list(color='#19877c')) |>
     plotly::layout(xaxis=list(title='Mean score'),yaxis=list(title='Subject'))
 })
 output$corr<-renderPlotly({hsb_corr_plot(eda()$data,title='Subject-score correlations')})
 output$eda_density<-renderPlotly({e<-eda();x<-e$data
   q<-data.frame(score=as.numeric(x[[e$score]]),group=if(e$group=='None') 'All students' else as.character(x[[e$group]]))
   q<-q[is.finite(q$score) & !is.na(q$group),,drop=FALSE]
   validate(need(nrow(q)>3,'Insufficient scores to estimate a density.'))
   p<-ggplot(q,aes(x=score,colour=group,fill=group))+geom_density(alpha=.12,na.rm=TRUE)+
      labs(x=e$score,y='Estimated density',colour='Group',fill='Group')+plot_theme()
   plotly::ggplotly(p)
 })
 output$eda_scatter<-renderPlotly({e<-eda();x<-e$data
   second<-setdiff(SCORE_COLS,e$score)[1]
   q<-data.frame(primary=x[[e$score]],secondary=x[[second]],
     group=if(e$group=='None')'All students' else as.character(x[[e$group]]))
   q<-q[is.finite(q$primary)&is.finite(q$secondary)&!is.na(q$group),,drop=FALSE]
   validate(need(nrow(q)>2,'Not enough complete score pairs.'))
   plotly::plot_ly(q,x=~primary,y=~secondary,color=~group,type='scatter',mode='markers',
        marker=list(size=8,opacity=.75)) |>
      plotly::layout(xaxis=list(title=e$score),yaxis=list(title=second))
 })
 output$eda_violin<-renderPlotly({e<-eda();x<-e$data
   q<-data.frame(subject=rep(SCORE_COLS,each=nrow(x)),
     score=unlist(x[,SCORE_COLS,drop=FALSE],use.names=FALSE))
   q<-q[is.finite(q$score),,drop=FALSE]
   validate(need(nrow(q)>4,'Not enough subject scores.'))
   plotly::plot_ly(q,x=~subject,y=~score,color=~subject,type='violin',
     box=list(visible=TRUE),meanline=list(visible=TRUE),showlegend=FALSE) |>
     plotly::layout(yaxis=list(title='Standardised score'),xaxis=list(title='Subject'))
 })
 output$eda_programme<-renderPlotly({x<-eda()$data
   z<-do.call(rbind,lapply(SCORE_COLS,function(v){
     zz<-stats::aggregate(x[[v]],by=list(programme=x$prog),FUN=function(y)mean(y,na.rm=TRUE))
     data.frame(subject=v,programme=as.character(zz$programme),mean=zz$x)
   }))
   z<-z[is.finite(z$mean) & !is.na(z$programme),,drop=FALSE]
   validate(need(nrow(z)>0,'No usable programme means.'))
   plotly::plot_ly(z,x=~subject,y=~mean,color=~programme,type='bar') |>
      plotly::layout(barmode='group',xaxis=list(title='Subject'),yaxis=list(title='Mean score'))
 })
 output$infer_corr<-renderPlotly({req(inference());hsb_corr_plot(d(),title='All-subject correlation matrix')})
 output$descriptives<-renderDT(dt(summary_scores(eda()$data)))
 output$inference_controls<-renderUI({k<-input$test_kind
   if(k=='Pearson correlation')return(tagList(selectInput('ivar','First score',SCORE_COLS,'math'),selectInput('jvar','Second score',SCORE_COLS,'read')))
   if(k=='Chi-square association')return(tagList(selectInput('ivar','First categorical variable',CAT_COLS,'ses'),selectInput('jvar','Second categorical variable',CAT_COLS,'prog')))
   tagList(selectInput('ivar','Score outcome',SCORE_COLS,'math'),selectInput('jvar','Grouping variable',if(k=='Independent samples t-test')c('female','schtyp') else c('race','ses','prog'),selected=if(k=='Independent samples t-test')'female' else 'ses'))
 })
 inference<-eventReactive(input$infer_run,{tryCatch({x<-d();k<-input$test_kind;a<-input$ivar;b<-input$jvar
   if(identical(a,b)) stop('Select two different variables.')
   z<-x[,c(a,b),drop=FALSE];z<-z[stats::complete.cases(z),,drop=FALSE]
   if(nrow(z)<10) stop('Too few complete records for reliable comparison.')
   if(k=='Independent samples t-test') {if(length(unique(z[[b]]))!=2)stop('The group must have two observed levels.');o<-t.test(z[[a]]~z[[b]])}
   else if(k=='One-way ANOVA') {if(length(unique(z[[b]]))<2)stop('At least two groups required.');o<-summary(aov(stats::reformulate(b,response=a),data=z))}
   else if(k=='Pearson correlation')o<-cor.test(z[[a]],z[[b]])
   else {tab<-table(z[[a]],z[[b]]);o<-suppressWarnings(chisq.test(tab));if(any(o$expected<5))attr(o,'warning')<-'Some expected cells are <5; consider an exact test or merging justified categories.'}
   list(data=z,result=o,k=k,a=a,b=b)},error=function(e)list(error=conditionMessage(e)))})
 output$infer_result<-renderPrint({req(inference());z<-inference();if(!is.null(z$error)){cat(z$error);return()};cat('Complete records:',nrow(z$data),'\n');print(z$result);if(!is.null(attr(z$result,'warning')))cat('\nCAUTION:',attr(z$result,'warning'))})
 output$infer_plot<-renderPlotly({z<-inference();req(is.null(z$error));x<-z$data
  p<-if(z$k=='Pearson correlation')ggplot(transform(x,plot_a=x[[z$a]],plot_b=x[[z$b]]),aes(x=plot_a,y=plot_b))+geom_point(alpha=.7,colour='#178178')+geom_smooth(method='lm',se=TRUE,colour='#b68238')
  else if(z$k=='Chi-square association')ggplot(transform(x,plot_a=x[[z$a]],plot_b=x[[z$b]]),aes(x=plot_a,fill=plot_b))+geom_bar(position='fill')+labs(y='Proportion')
  else ggplot(transform(x,plot_a=x[[z$a]],plot_b=x[[z$b]]),aes(x=plot_b,y=plot_a,fill=plot_b))+geom_boxplot()+labs(x=NULL,y=z$a)
  ggplotly(p+plot_theme()+theme(legend.position='bottom'))})
 observeEvent(input$target,{updateCheckboxGroupInput(session,'predictors',choices=allowed_predictors(input$target),selected=intersect(c('read','write','science','socst','ses','prog'),allowed_predictors(input$target)))})
 output$predictor_ui<-renderUI({checkboxGroupInput('predictors','Predictors (exclude the outcome)',choices=allowed_predictors(input$target),selected=intersect(c('read','write','science','socst','ses','prog'),allowed_predictors(input$target)))})
 output$model_ui<-renderUI({checkboxGroupInput('models','Models to compare',choices=model_names(get_problem(input$target)),selected=model_names(get_problem(input$target)))})
 output$split_pct<-renderUI({test<-100-input$train_pct-input$valid_pct;if(test<10)div(class='warnnote','Test must be ≥10%. Adjust sliders.') else note(strong(paste0(input$train_pct,'% training  |  ',input$valid_pct,'% validation  |  ',test,'% testing')),' · stratified when classifying')})
 observeEvent(input$fit,{model_state(NULL);tryCatch({if(input$train_pct+input$valid_pct>90) stop('Reserve at least 10% for test.');
   withProgress(message='Training and evaluating HSB models',value=0.2,{
     res<-run_comparison(d(),input$target,input$predictors,input$train_pct,input$valid_pct,input$seed,input$models)
     incProgress(.8);model_state(res)
   })},error=function(e){model_state(list(error=conditionMessage(e)));showNotification(conditionMessage(e),type='error',duration=12)})})
 output$train_status<-renderUI({x<-model_state();if(is.null(x))return(note('Select an outcome, predictors and data percentages, then press Train and compare.'));
  if(!is.null(x$error))return(warn(x$error));tagList(note(paste('Models fitted:',nrow(x$metrics),'| Outcome:',x$target,'| Evaluation:',x$kind)),
    if(length(x$issues))warn(paste('Unavailable models:',paste(x$issues,collapse='; '))))})
 good_result<-reactive({x<-model_state();req(x);validate(need(is.null(x$error),x$error));x})
 output$model_kpis<-renderUI({x<-good_result();div(class='kpis',kpi('Train',x$counts['train']),kpi('Validation',x$counts['validation']),kpi('Test',x$counts['test']),kpi('Best by validation',x$best))})
 output$leaderboard<-renderDT({x<-good_result();dt(x$metrics)})
 output$leader_chart<-renderPlotly({z<-good_result()$metrics
    validate(need(nrow(z)>0,'Run Train and compare selected models first.'))
    z$model<-factor(z$model,levels=rev(z$model))
    plotly::plot_ly(z,x=~validation_score,y=~model,
                    type='bar',orientation='h',marker=list(color='#18847e'),
                    hovertemplate='%{y}: %{x:.3f}<extra></extra>') |>
      plotly::layout(xaxis=list(title=paste('Validation',z$validation_metric[1])),
                     yaxis=list(title='Model'))})
 output$pick_model<-renderUI({x<-good_result();selectInput('chosen_model','Inspect model',choices=x$metrics$model,selected=x$best)})
 selected_detail<-reactive({x<-good_result();req(input$chosen_model);req(input$chosen_model %in% names(x$detail));x$detail[[input$chosen_model]]})
 output$detail_metrics<-renderDT({dt(selected_detail()$full_metrics)})
 output$diagnostic<-renderPlotly({x<-good_result();z<-selected_detail()$test
   if(x$kind=='classification') {
     z$observed_group<-as.character(z$observed)
     plotly::plot_ly(z,x=~predicted,color=~observed_group,type='histogram',
       opacity=.6,nbinsx=14) |>
       plotly::layout(barmode='overlay',xaxis=list(title='Predicted probability'),
                      yaxis=list(title='Students'))
   } else {
     plotly::plot_ly(z,x=~observed,y=~predicted,type='scatter',mode='markers',
       text=~paste('Student:',id),hoverinfo='text',marker=list(color='#167e78',size=8)) |>
       plotly::layout(xaxis=list(title='Observed'),yaxis=list(title='Predicted'))
   }
 })
 output$test_predictions<-renderDT(dt(selected_detail()$test))
 output$importance<-renderPlotly({z<-good_result();req(input$chosen_model);v<-permutation_importance(z,d(),input$chosen_model,input$seed);
   v<-v[order(v$impact),,drop=FALSE];plotly::plot_ly(v,x=~impact,y=~predictor,type='bar',orientation='h')})
 best_imp <- eventReactive(input$best_imp_run,{
   z<-good_result()
   tryCatch(permutation_importance(z,d(),z$best,input$seed),
     error=function(e)data.frame(predictor='Unavailable',impact=NA_real_))
 })
 output$best_importance<-renderPlotly({v<-best_imp()
   validate(need(nrow(v)>0 && any(is.finite(v$impact)),
     'Importance could not be estimated. Train models and check the validation partition.'))
   v<-v[is.finite(v$impact),,drop=FALSE]
   v<-v[order(v$impact),,drop=FALSE]
   plotly::plot_ly(v,x=~impact,y=~predictor,type='bar',orientation='h',
     marker=list(color='#17877c')) |>
      plotly::layout(xaxis=list(title='Validation performance degradation'),yaxis=list(title='Predictor'))
 })
 output$handoff_export<-downloadHandler(filename=function()'hsb_analytics_evidence.csv',
   content=function(file)write.csv(hsb_evidence_export(good_result(),d()),file,row.names=FALSE,na=''))
 output$model_export<-downloadHandler(filename=function()'hsb_model_comparison.csv',content=function(file)write.csv(good_result()$metrics,file,row.names=FALSE))
 output$pred_export<-downloadHandler(filename=function()'hsb_test_predictions.csv',content=function(file)write.csv(selected_detail()$test,file,row.names=FALSE))
 observeEvent(input$cluster_run,{
   cluster_state(NULL);cluster_compare_state(NULL)
   tryCatch({
     withProgress(message='Computing cluster assignments and diagnostics',value=.1,{
       z<-run_clusters(d(),input$cluster_features,input$k,input$cluster_seed,
                       input$cluster_method,input$eps,input$min_pts)
       incProgress(.4)
       comparison<-compare_cluster_methods(d(),input$cluster_features,input$k,
                          input$cluster_seed,input$eps,input$min_pts)
       incProgress(.5)
       cluster_state(z);cluster_compare_state(comparison)
     })
   },error=function(e){showNotification(conditionMessage(e),type='error',duration=12)})
 })
 cluster_result<-reactive({z<-cluster_state();validate(need(!is.null(z),
   'Press Run clustering and compare methods to display results.'));z})
 output$clusters<-renderPlotly({z<-cluster_result();pts<-z$points
   plotly::plot_ly(pts,x=~PC1,y=~PC2,color=~cluster,type='scatter',mode='markers',
        text=~paste('Student:',id,'|',as.character(cluster)),hoverinfo='text',
        marker=list(size=9,opacity=.83)) |>
      plotly::layout(title=paste(z$method,'clusters in PCA space'),
        xaxis=list(title=paste0('PC1 (',round(z$share_variance[1]*100,1),'% variance)')),
        yaxis=list(title=paste0('PC2 (',round(z$share_variance[2]*100,1),'% variance)')))
 })
 output$cluster_profile<-renderDT(dt(cluster_result()$profile))
 output$cluster_size<-renderPlotly({z<-cluster_result()
   q<-as.data.frame(table(z$points$cluster));names(q)<-c('cluster','students')
   plotly::plot_ly(q,x=~cluster,y=~students,type='bar',marker=list(color='#17877c')) |>
     plotly::layout(xaxis=list(title='Cluster'),yaxis=list(title='Students'))
 })
 output$cluster_compare<-renderDT({z<-cluster_compare_state();validate(need(!is.null(z),'Press Run clustering to compare algorithms.'));dt(z)})
 output$cluster_compare_plot<-renderPlotly({z<-cluster_compare_state()
   validate(need(!is.null(z),'Press Run clustering first.'))
   q<-z[is.finite(z$silhouette),,drop=FALSE]
   validate(need(nrow(q)>0,'No valid silhouette values; check packages and parameters.'))
   plotly::plot_ly(q,x=~silhouette,y=~method,type='bar',orientation='h',
     marker=list(color='#19857c')) |>
     plotly::layout(xaxis=list(title='Average silhouette width'),yaxis=list(title='Method'))
 })
 output$cluster_rows<-renderDT({z<-cluster_result();dt(cbind(d(),cluster=z$points$cluster))})
 output$cluster_export<-downloadHandler(filename=function()'hsb_clusters.csv',
   content=function(file)write.csv(cbind(d(),cluster=cluster_result()$points$cluster),file,row.names=FALSE))
}
shinyApp(ui,server)
