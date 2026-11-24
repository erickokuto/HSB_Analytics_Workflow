###############################################################################
# HSB ANALYTICS WORKFLOW — BEGINNER'S GITHUB PUBLISHING GUIDE
# User: erickokuto | Project: HSB_Analytics_Workflow
#
# WHAT THIS SCRIPT DOES
#   Guides you through preparing the local Git repository, reviewing changes,
#   creating a PRIVATE GitHub repository and pushing subsequent updates.
#   Nothing is uploaded simply because you open or Source this script.
#
# WHAT IT DOES NOT DO
#   It does not deploy a running Shiny dashboard. That is done separately
#   through deploy_to_shinyapps.R and shinyapps.io.
#
# QUICK START IN RSTUDIO (run ONE command at a time in the CONSOLE)
#   1. Open the HSB_Analytics_Workflow RStudio project (.Rproj file).
#   2. Open THIS script and click Source ONCE.
#   3. hsb_github_check()          # Check paths, Git, credentials and files
#   4. hsb_github_prepare()        # Initialise Git locally (if necessary)
#   5. Use the RStudio Git tab to review, Stage and Commit approved files.
#   6. hsb_github_publish()        # Create PRIVATE repository and first push
#   7. Later: stage/commit changes, then hsb_github_push().
#
# FIRST-TIME GITHUB AUTHENTICATION (DO THIS BEFORE STEP 3 IF NECESSARY)
#   Run hsb_github_setup_token() to open token-creation guidance.
#   The token must be pasted into the INTERACTIVE RStudio Console, never into
#   this script, app.R, Git history or a screenshot. Previously exposed tokens
#   must be revoked via GitHub settings. Prefer a classic PAT with repo scope
#   for this beginner workflow, with minimum feasible duration/permissions.
#
# NOTE: Only source this script ONCE. It never sources itself or file.choose().
###############################################################################

# SECTION A — SETTINGS: adjust only if you moved the folder.
HSB_GITHUB_USER <- "erickokuto"
HSB_GITHUB_REPO <- "HSB_Analytics_Workflow"
HSB_GITHUB_DIR <- "D:/WAB 2209 StatisticalComputing 2026/HSB_Analytics_and_Decision_Support/HSB_Analytics_Workflow"

# Fallback for a freshly extracted ZIP on another computer: use the RStudio
# project working directory if it includes app.R and R/core.R.
hsb_project_dir <- function() {
  p <- HSB_GITHUB_DIR
  if (!dir.exists(p) && file.exists(file.path(getwd(), "app.R")) &&
      file.exists(file.path(getwd(), "R", "core.R"))) p <- getwd()
  if (!dir.exists(p)) stop("Cannot find the project folder. Set HSB_GITHUB_DIR to its actual path.", call. = FALSE)
  p <- normalizePath(p, winslash = "/", mustWork = TRUE)
  if (basename(p) != HSB_GITHUB_REPO ||
      !file.exists(file.path(p, "app.R")) ||
      !file.exists(file.path(p, "R", "core.R"))) {
    stop("Expected the HSB_Analytics_Workflow folder containing app.R and R/core.R.\n",
         "Detected: ", p, call. = FALSE)
  }
  p
}

# Helper runs Git in this exact project without needing setwd() or file dialogs.
# Each argument is passed as a separate token; paths are quoted for Windows.
hsb_git <- function(args, quiet = FALSE) {
  git <- Sys.which("git")
  if (!nzchar(git)) stop("Git for Windows is not detected. Install Git, restart RStudio, and retry.", call. = FALSE)
  p <- hsb_project_dir()
  result <- suppressWarnings(system2(git, args = c("-C", shQuote(p), args),
                                      stdout = TRUE, stderr = TRUE))
  rc <- attr(result, "status")
  code <- if (is.null(rc)) 0L else as.integer(rc)
  if (!quiet && length(result)) cat(paste(result, collapse = "\n"), "\n")
  list(code = code, lines = result)
}

# Check whether a local Git repository is present in the project itself.
hsb_has_git <- function() {
  file.exists(file.path(hsb_project_dir(), ".git"))
}

# SECTION B — GITHUB CREDENTIALS AND ONE-TIME INSTALLATION.
hsb_github_install <- function() {
  packages <- c("usethis", "gh", "gitcreds")
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
  still_missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(still_missing)) stop("Unable to install: ", paste(still_missing, collapse = ", "), call. = FALSE)
  cat("PASS: GitHub integration packages are installed.\n")
  invisible(TRUE)
}

hsb_github_setup_token <- function() {
  hsb_github_install()
  cat("\nCREATE AND SAVE YOUR PERSONAL ACCESS TOKEN (PAT)\n")
  cat("1. Sign in as ", HSB_GITHUB_USER, " at github.com.\n", sep = "")
  cat("2. Create a Personal Access Token: token name 'RStudio HSB workflow'.\n")
  cat("3. For the classic-token method, select the 'repo' scope.\n")
  cat("4. Generate the token, copy it once, and return to RStudio.\n")
  cat("5. Run: gitcreds::gitcreds_set() and paste the token on request.\n")
  cat("6. Verify with: usethis::git_sitrep()\n")
  cat("Never paste the token into this script or upload it to GitHub.\n")
  # This opens GitHub's token page; NO token is included in the URL.
  utils::browseURL("https://github.com/settings/tokens")
  invisible(TRUE)
}

# SECTION C — PRE-PUBLISH CHECKS.
# Important: This check cannot guarantee that data are de-identified or that
# every possible secret is absent. ALWAYS review staged files before commit.
hsb_github_check <- function() {
  p <- hsb_project_dir()
  cat("\n=== HSB GITHUB PRE-FLIGHT ===\nProject: ", p, "\n", sep = "")
  expected <- c("app.R", "R/core.R", "R/theme.R", "hsb.csv",
                "README.md", "deploy_to_shinyapps.R")
  missing <- expected[!file.exists(file.path(p, expected))]
  if (length(missing)) stop("Missing project files: ", paste(missing, collapse = ", "), call. = FALSE)
  cat("PASS: Main Shiny application files are present.\n")
  if (!nzchar(Sys.which("git"))) stop("Git executable not found. Install Git for Windows.", call. = FALSE)
  cat("PASS: Git for Windows detected.\n")
  if (hsb_has_git()) {
    cat("PASS: Local .git repository exists.\n")
    cat("Git status (?? = untracked, M = modified, A = staged):\n")
    hsb_git(c("status", "--short"))
  } else cat("INFO: Local repository not yet initialised. Run hsb_github_prepare().\n")
  if (requireNamespace("gh", quietly = TRUE)) {
    name <- tryCatch(gh::gh_whoami()$login, error = function(e) NA_character_)
    if (is.na(name)) cat("INFO: Cannot confirm GitHub sign-in. Run hsb_github_setup_token().\n")
    else if (!identical(tolower(name), tolower(HSB_GITHUB_USER)))
      stop("Wrong authenticated account: ", name, ". Expected ", HSB_GITHUB_USER, call. = FALSE)
    else cat("PASS: Authenticated as ", name, ".\n", sep = "")
  }
  cat("Reminder: Verify that student data, source and history are approved for sharing.\n")
  invisible(TRUE)
}

# Check the exact files Git intends to publish, including the first commit.
# .gitignore only excludes UNTRACKED files; it does NOT erase historical secrets.
hsb_check_tracked <- function() {
  files <- hsb_git(c("ls-files", "--cached", "--full-name"), quiet = TRUE)
  if (files$code != 0L) stop("Cannot read the staged/tracked file list.", call. = FALSE)
  unsafe <- files$lines[grepl("(^|/)(\\.env([./]|$)|\\.Renviron$|rsconnect/|\\.git/|\\.Rhistory$)",
                              files$lines, perl = TRUE)]
  unsafe <- unique(c(unsafe, files$lines[grepl("(?i)(token|secret|password|credential|Connect_To_Shiny_io)",
                                              files$lines, perl = TRUE)]))
  if (length(unsafe)) stop("Potentially sensitive tracked/staged files:\n  ",
                           paste(unsafe, collapse = "\n  "),
                           "\nRemove them from the staging area/history before publishing.", call. = FALSE)
  if (!length(files$lines)) stop("No files are staged or tracked. Review and Commit in RStudio first.", call. = FALSE)
  # Inspect likely source text for literal credential prefixes without printing them.
  p <- hsb_project_dir()
  txt <- files$lines[grepl("\\.(R|r|py|md|json|ya?ml|ini|txt|cfg)$", files$lines, ignore.case = TRUE)]
  txt <- txt[file.exists(file.path(p, txt))]
  txt <- txt[file.info(file.path(p, txt))$size <= 1e6]
  bad <- vapply(txt, function(f) {
    x <- tryCatch(readLines(file.path(p, f), warn = FALSE), error = function(e) character())
    any(grepl("gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}", x, perl = TRUE))
  }, logical(1))
  if (any(bad)) stop("Possible embedded GitHub access tokens in: ",
                     paste(txt[bad], collapse = ", "), ". Revoke and remove before publishing.", call. = FALSE)
  cat("PASS: No obvious sensitive filenames or GitHub token prefixes detected.\n")
  cat("This is a limited check: manually inspect datasets, model files and Git history.\n")
  invisible(TRUE)
}

# SECTION D — INITIALISE A LOCAL REPOSITORY (NO UPLOAD).
hsb_github_prepare <- function() {
  p <- hsb_project_dir()
  cat("\nPREPARING LOCAL GIT: ", p, "\n", sep = "")
  if (!file.exists(file.path(p, ".gitignore"))) {
    stop("The project .gitignore is missing; use the revised ZIP before proceeding.", call. = FALSE)
  }
  # Prevent accidental creation inside an already-tracked parent directory.
  parent <- dirname(p)
  while (parent != dirname(parent)) {
    if (file.exists(file.path(parent, ".git"))) {
      stop("A parent Git repository already exists at: ", parent,
           ". Review the project layout before continuing.", call. = FALSE)
    }
    parent <- dirname(parent)
  }
  if (!hsb_has_git()) {
    result <- hsb_git(c("init", "-b", "main"))
    if (result$code != 0L) stop("Git initialisation failed.", call. = FALSE)
    cat("PASS: Local Git repository created. Nothing has been uploaded.\n")
  } else cat("PASS: Existing local Git repository preserved.\n")
  cat("\nNEXT (in the RStudio Git tab):\n")
  cat("  1. Inspect all new/modified files, particularly hsb.csv.\n")
  cat("  2. Tick STAGED for files approved for publication.\n")
  cat("  3. Click COMMIT and enter a message, such as:\n")
  cat("     Initial commit: HSB Analytics Workflow Shiny dashboard\n")
  cat("  4. After committing, run hsb_github_publish().\n")
  invisible(TRUE)
}

# SECTION E — CREATE THE INITIAL PRIVATE GITHUB REPOSITORY.
# This step is deliberately separate from Source() and local setup.
hsb_github_publish <- function() {
  if (!interactive()) stop("Run this function interactively in the RStudio Console.", call. = FALSE)
  hsb_github_install()
  hsb_github_check()
  if (!hsb_has_git()) stop("Run hsb_github_prepare() first.", call. = FALSE)
  st <- hsb_git(c("status", "--porcelain"), quiet = TRUE)
  if (st$code != 0L || length(st$lines)) {
    cat("\nFiles not yet committed:\n", paste(st$lines, collapse = "\n"), "\n")
    stop("Review, Stage and Commit changes in the Git tab first.", call. = FALSE)
  }
  head <- hsb_git(c("rev-parse", "--verify", "HEAD"), quiet = TRUE)
  if (head$code != 0L) stop("No local commit found. Stage and Commit in RStudio first.", call. = FALSE)
  hsb_check_tracked()
  login <- tryCatch(gh::gh_whoami()$login, error = function(e) NA_character_)
  if (is.na(login) || tolower(login) != tolower(HSB_GITHUB_USER)) {
    stop("GitHub authentication not confirmed as erickokuto. Use hsb_github_setup_token().", call. = FALSE)
  }
  remote <- hsb_git(c("remote", "get-url", "origin"), quiet = TRUE)
  if (remote$code == 0L && length(remote$lines)) {
    cat("This project already has a remote; it will NOT create another repository.\n")
    cat("If it is the intended repository, use hsb_github_push() for updates.\n")
    return(invisible(FALSE))
  }
  # Existing online repo may have content; don't overwrite or force-push it.
  existing <- tryCatch(gh::gh("GET /repos/{owner}/{repo}",
                              owner = HSB_GITHUB_USER, repo = HSB_GITHUB_REPO),
                       error = function(e) NULL)
  if (!is.null(existing)) {
    stop("A repository with this name ALREADY EXISTS on GitHub.\n",
         "Do not create a duplicate. Clone/connect the existing repository and merge changes safely.", call. = FALSE)
  }
  cat("\nReady to create PRIVATE GitHub repository:\n")
  cat("https://github.com/", HSB_GITHUB_USER, "/", HSB_GITHUB_REPO, "\n", sep = "")
  cat("All committed files and commit history will be uploaded.\n")
  answer <- readline("Type PUBLISH to create and upload (anything else cancels): ")
  if (!identical(trimws(answer), "PUBLISH")) {
    cat("Cancelled. Nothing uploaded.\n")
    return(invisible(FALSE))
  }
  # usethis uses the project location specified explicitly, avoiding a wrong
  # RStudio working directory. Its workflow creates and pushes the new repo.
  usethis::proj_set(hsb_project_dir(), force = TRUE)
  usethis::use_github(private = TRUE)
  cat("\nVerify the files at: https://github.com/", HSB_GITHUB_USER,
      "/", HSB_GITHUB_REPO, "\n", sep = "")
  invisible(TRUE)
}

# SECTION F — PUSH LATER UPDATES TO AN ALREADY-CONNECTED GITHUB REPOSITORY.
hsb_github_push <- function() {
  if (!interactive()) stop("Run this function from RStudio Console.", call. = FALSE)
  hsb_github_check()
  if (!hsb_has_git()) stop("No local Git repository; run hsb_github_prepare().", call. = FALSE)
  st <- hsb_git(c("status", "--porcelain"), quiet = TRUE)
  if (st$code != 0L || length(st$lines))
    stop("Uncommitted changes exist: review, stage and commit them before pushing.", call. = FALSE)
  hsb_check_tracked()
  remote <- hsb_git(c("remote", "get-url", "origin"), quiet = TRUE)
  if (remote$code != 0L || !length(remote$lines))
    stop("No origin configured. Publish first or connect to an existing repo manually.", call. = FALSE)
  # Restrict pushes to the expected GitHub repository only; don't print URLs
  # which could potentially contain embedded credentials.
  expected <- paste0(HSB_GITHUB_USER, "/", HSB_GITHUB_REPO)
  allowed <- c(paste0("https://github.com/", expected),
               paste0("git@github.com:", expected),
               paste0("ssh://git@github.com/", expected))
  actual <- sub("\\.git$", "", remote$lines[[1L]])
  if (!actual %in% allowed) stop("Unexpected Git remote. Check it locally; no upload performed.", call. = FALSE)
  branch <- hsb_git(c("branch", "--show-current"), quiet = TRUE)
  if (branch$code != 0L || !length(branch$lines) || !nzchar(branch$lines[1L]))
    stop("Cannot determine current branch. Check Git status.", call. = FALSE)
  cat("\nAbout to push branch '", branch$lines[1L], "' to ", expected, ".\n", sep = "")
  cat("If Git refuses a push, fetch/pull and reconcile remote changes; NEVER force-push.\n")
  if (!identical(trimws(readline("Type PUSH to continue: ")), "PUSH")) {
    cat("Cancelled. Nothing uploaded.\n")
    return(invisible(FALSE))
  }
  result <- hsb_git(c("push", "-u", "origin", branch$lines[1L]))
  if (result$code != 0L) stop("Git push failed. Read the Git output above.", call. = FALSE)
  cat("PASS: Git push completed. Check https://github.com/", expected, "\n", sep = "")
  invisible(TRUE)
}

# ONLY PRINT HELP WHEN SOURCED. NO UPLOAD, CREDENTIAL PROMPT OR RECURSION.
cat("\nHSB GitHub helper loaded. No files have been uploaded.\n")
cat("Begin with: hsb_github_check() then hsb_github_prepare().\n")
cat("After reviewing and committing: hsb_github_publish().\n")
cat("For later committed updates: hsb_github_push().\n")
