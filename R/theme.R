# Shared user-interface helpers. Kept in R for transparent deployment.
HSB_CSS <- "
body {background:#f4f7fb;color:#1d3548;font-family:'Segoe UI',Arial,sans-serif;}
.navbar-default {background:#163b55;border:0;border-radius:0;}
.navbar-default .navbar-brand,.navbar-default .navbar-nav>li>a {color:#f4f8fa!important;}
.navbar-default .navbar-nav>.active>a {color:#173850!important;background:#eaf1f6!important;}
.card {background:white;border-radius:12px;padding:18px;border:1px solid #e1eaf1;box-shadow:0 1px 4px rgba(20,45,68,.045);margin-bottom:16px;}
.hero {background:linear-gradient(120deg,#153a55,#226b78);color:white;padding:20px 25px;border-radius:12px;margin:14px 0 20px;}
.hero h2 {margin:5px 0 8px;font-weight:700;color:white;}
.hero p {color:#e2eef2;}
.kpis {display:flex;gap:12px;flex-wrap:wrap;margin-bottom:12px;}
.kpi {background:white;border:1px solid #dfe8ef;border-top:4px solid #168879;border-radius:9px;min-width:160px;flex:1;padding:12px 18px;}
.kpi small {display:block;color:#60768a;}.kpi b {font-size:26px;color:#143d55;}
.softnote {background:#eaf4f7;border-left:4px solid #1b8a87;padding:12px 14px;margin:10px 0 16px;border-radius:4px;}
.warnnote {background:#fff3e4;border-left:4px solid #ce9146;padding:12px 14px;margin:10px 0 16px;border-radius:4px;}
.btn-primary {background:#187e78;border-color:#187e78;} h3 {font-weight:650;color:#183d54;} .dataTables_wrapper {font-size:12px;}
"
card <- function(...) shiny::div(class='card',...)
hero <- function(title, subtitle) shiny::div(class='hero',shiny::h2(title),shiny::p(subtitle))
note <- function(...) shiny::div(class='softnote',...)
warn <- function(...) shiny::div(class='warnnote',...)
kpi <- function(label,value) shiny::div(class='kpi',shiny::tags$small(label),shiny::tags$b(value))
dt <- function(x,page=10) DT::datatable(x,rownames=FALSE,extensions='Buttons',options=list(pageLength=page,scrollX=TRUE,dom='Bfrtip',buttons=c('copy','csv','excel')),filter='none')
plot_theme <- function() ggplot2::theme_minimal(base_size=13)+ggplot2::theme(plot.title=ggplot2::element_text(face='bold'),panel.grid.minor=ggplot2::element_blank())
