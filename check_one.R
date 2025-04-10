cargs <- commandArgs(trailingOnly=TRUE)
if(length(cargs)==0){
  ## before running interactively, make sure to start emacs/R with
  ## environment defined in /scratch/...check_one.sh, particularly
  ## R_LIBS_USER=/tmp/... otherwise we get error when installing
  ## data.table.
  base <- "/scratch/th798/data.table-revdeps/*"
  cargs <- c(
    Sys.glob(file.path(base,"deps.csv")),
    "349",
    Sys.glob(file.path(base, "data.table_release_*tar.gz")),
    Sys.glob(file.path(base, "data.table_master_*tar.gz"))
  )
}
names(cargs) <- c("deps.csv", "task.str", "release", "master")
dput(cargs)
(task.dir <- dirname(.libPaths()[1]))#should be /tmp/th798/slurmid/R-vers
if(requireNamespace("R.cache"))R.cache::getCachePath()
task.id <- as.integer(cargs[["task.str"]])
deps.df <- read.csv(cargs[["deps.csv"]])
(rev.dep <- deps.df$Package[task.id])
job.dir <- file.path(dirname(cargs[["deps.csv"]]), "tasks", task.id)
setwd(task.dir)
.libPaths()
options(repos=c(#this should be in ~/.Rprofile too.
  CRAN="http://cloud.r-project.org"))
print(Sys.time())
install.time <- system.time({
  install.packages(rev.dep, dep=TRUE)
})
cat("Time to install revdep:\n")
print(install.time)
print(Sys.time())
downloaded_packages <- file.path(
  tempdir(),
  "downloaded_packages")
dl.glob <- file.path(
  downloaded_packages,
  paste0(rev.dep,"_*.tar.gz"))
rev.dep.dl.row <- cbind(rev.dep, Sys.glob(dl.glob))
colnames(rev.dep.dl.row) <- c("pkg","path")
rev.dep.release.tar.gz <- normalizePath(rev.dep.dl.row[,"path"], mustWork=TRUE)
pkg.Rcheck <- paste0(rev.dep, ".Rcheck")

proj.dir <- "~/genomic-ml/data.table-revdeps"
source(file.path(proj.dir, "myStatus.R"))
Rvers <- gsub("[()]", "", gsub(" ", "_", R.version[["version.string"]]))
dir.create(Rvers, showWarnings=FALSE)
Rcheck.list <- list()
for(dt.version.short in c("release", "master")){
  dt.tar.gz <- cargs[[dt.version.short]]
  dt.version <- gsub(".tar.gz|/.*?_", "", dt.tar.gz)
  print(Sys.time())
  install.packages(dt.tar.gz, repos=NULL)
  print(Sys.time())
  check.cmd <- get_check_cmd(rev.dep.release.tar.gz)
  system(check.cmd)
  print(Sys.time())
  dest.Rcheck <- file.path(
    Rvers,
    paste0(dt.version, ".Rcheck"))
  unlink(dest.Rcheck, recursive=TRUE)
  file.rename(pkg.Rcheck, dest.Rcheck)
  Rcheck.list[[dt.version]] <- file.path(dest.Rcheck, "00check.log")
}
system(paste(c("diff -u", Rcheck.list), collapse=" "))
library(data.table, lib.loc=R.home("library"))
(sig.diff.dt <- myDiff(Rvers))

## If there are significant differences, use git bisect to find when
## they started.
if(nrow(sig.diff.dt)){
  dt.git <- file.path(task.dir, "data.table.git")
  system(paste("cd ~/R/data.table && git fetch --tags"))
  system(paste("git clone ~/R/data.table", dt.git))
  release.tag <- gsub(".tar.gz|.*_", "", cargs[["release"]])
  rev.parse.cmd <- paste(
    "cd", dt.git, "&& git rev-parse master")
  master.sha <- system(rev.parse.cmd, intern=TRUE)
  merge.base.cmd <- paste(
    "cd", dt.git, "&& git merge-base master", release.tag)
  merge.base.sha <- system(merge.base.cmd, intern=TRUE)
  old.sha <- merge.base.sha
  run_R <- file.path(proj.dir, "install_dt_then_check_dep.R")
  sig.diff.dt[, first.bad.commit := NA_character_]
  sig.diff.dt[, comments := NA_character_]
  for(diff.i in 1:nrow(sig.diff.dt)){
    sig.diff.row <- sig.diff.dt[diff.i]
    bisect.cmd <- paste(
      "cd", dt.git, "&&",
      "git bisect start &&",
      "git bisect old", old.sha, "&&",
      "git bisect new master &&",
      "git bisect run",
      R.home('bin/Rscript'),
      run_R,
      shQuote(sig.diff.row$checking),
      sig.diff.row$release,
      rev.dep.release.tar.gz,
      release.tag)
    print(bisect.cmd)
    bisect.out <- system(bisect.cmd, intern=TRUE)
    cat(bisect.out,sep="\n")
    if(is.null(attr(bisect.out,"status"))){
      first.bad.sha <- nc::capture_all_str(
        bisect.out,
        sha="[0-9a-f]+",
        " is the first new commit")$sha
      parent.cmd <- paste(
        "cd ~/R/data.table && git log --pretty=%P -n 1",
        first.bad.sha)
      parent.sha <- system(parent.cmd, intern=TRUE)
      sig.diff.dt[diff.i, first.bad.commit := first.bad.sha]
      parent.msg <- paste0("parent=", parent.sha)
      this.comment <- if(parent.sha==old.sha){
        paste(parent.msg, "same as git bisect old")
      }else if(first.bad.sha==master.sha){
        paste("same as git bisect new=master,", parent.msg)
      }else{
        parent.msg
      }
      sig.diff.dt[diff.i, comments := this.comment]
    }
  }
  ## add CRAN column.
  sig.diff.dt[, CRAN := {
    flavor <- get_flavor(Rvers)
    details <- data.table(flavor=unique(flavor))[, {
      base <- "https://www.r-project.org/nosvn/R.check/"
      u <- paste0(base, flavor, "/", rev.dep, "-00check.txt")
      check.txt <- tempfile()
      tryCatch({
        download.file(u, check.txt, quiet=TRUE)
      }, error=function(e){
        NULL
      })
      check.lines <- if(file.exists(check.txt)){
        readLines(check.txt,encoding="UTF-8")
      }else{
        ""
      }
      repl.lines <- gsub("[\u2018\u2019]", "'", check.lines)
      ##gsub("[‘’]", "'", check.lines) does not work with LC_ALL=C.
      myStatus(line.vec=repl.lines)
    }, by=flavor]
    select.dt <- data.table(flavor, checking)
    details[select.dt, msg, on=.(flavor, checking)]
  }]
  dir.create(file.path(job.dir, Rvers))
  diffs.csv <- file.path(job.dir, Rvers, "significant_differences.csv")
  data.table::fwrite(sig.diff.dt, diffs.csv)
  print(sig.diff.dt)
}
