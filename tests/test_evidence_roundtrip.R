# HSB ANALYTICS → DECISION SUPPORT: CSV evidence contract smoke test.
# Run from either application folder: source('tests/test_evidence_roundtrip.R')
source('R/core.R')
x <- labelled_hsb(clean_hsb(read_hsb('hsb.csv')))
fit <- run_comparison(x, 'math', c('read','write','science','socst','ses'),
                      train_pct=70,valid_pct=15,seed=2026,
                      chosen=c('Linear regression'))
stopifnot(fit$best=='Linear regression')
e <- hsb_evidence_export(fit,x)
f <- tempfile(fileext='.csv')
write.csv(e,f,row.names=FALSE,na='')
y <- hsb_evidence_import(f,read_hsb('hsb.csv'))
stopifnot(nrow(y)==nrow(x), identical(y$student_id,as.character(x$id)),
          sum(y$partition=='Held-out test')>4,
          all(is.finite(y$predicted)))
# A different student ID is rejected; this guards against accidental
# transfer of predictions to a different uploaded class/dataset.
other <- read_hsb('hsb.csv')
other$id[1] <- 'unmatched-id'
refused <- inherits(try(hsb_evidence_import(f,other),silent=TRUE),'try-error')
stopifnot(refused)
unlink(f)
message('PASS: model export/import, matched IDs, partitions and mismatch rejection.')
