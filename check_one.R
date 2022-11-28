cargs <- commandArgs(trailingOnly=TRUE)
if(length(cargs)==0){
  cargs <- c(
    "/scratch/th798/data.table-revdeps/2022-11-23/deps.csv",
    ##iemisc="517",
    ##mlr3="671",
    ##MicroMoB="655",
    mlr3fairness="675",
    ##mlr3tuning="687",
    "/scratch/th798/data.table-revdeps/2022-11-23/data.table_release_1.14.6.tar.gz", 
    "/scratch/th798/data.table-revdeps/2022-11-23/data.table_master_1.14.7.cb8aeff9453acec878e5ab8515cda0d302c943eb.tar.gz"
)
}
names(cargs) <- c("deps.csv", "task.str", "release", "master")
dput(cargs)
task.id <- as.integer(cargs[["task.str"]])
deps.df <- read.csv(cargs[["deps.csv"]])
(rev.dep <- deps.df$Package[task.id])
job.dir <- file.path(dirname(cargs[["deps.csv"]]), "tasks", task.id)
setwd(job.dir)
.libPaths()
options(repos=c(CRAN="http://cloud.r-project.org"))

if(TRUE){  
  install.packages(rev.dep, dep=TRUE)#should we do this for each R version?
  ##pak::pkg_install(rev.dep)
  ##rev.dep.dl.row <- download.packages(rev.dep, destdir=".")
  downloaded_packages <- file.path(
    tempdir(),
    "downloaded_packages")
  dl.glob <- file.path(
    downloaded_packages,
    paste0(rev.dep,"_*.tar.gz"))
  rev.dep.dl.row <- cbind(rev.dep, Sys.glob(dl.glob))
}else{
  rev.dep.dl.row <- character()
  options(warn=2)
  while(length(rev.dep.dl.row)==0){
    rev.dep.dl.row <- tryCatch({
      install.packages(rev.dep, dep=TRUE)#should we do this for each R version?
      download.packages(rev.dep, destdir=".")
    }, error=function(e){
      character()
    })
  }
  options(warn=0)
}
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
  install.packages(dt.tar.gz, repos=NULL)
  check.cmd <- get_check_cmd(rev.dep.release.tar.gz)
  system(check.cmd)
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
  dt.git <- file.path(dirname(.libPaths()[1]), "data.table.git")
  system(paste("git clone ~/R/data.table", dt.git))
  release.tag <- gsub(".tar.gz|.*_", "", cargs[["release"]])
  merge.base.cmd <- paste(
    "cd", dt.git, "&& git merge-base master", release.tag)
  merge.base.sha <- system(merge.base.cmd, intern=TRUE)
  ##old.sha <- release.tag##need buy in from devs?
  ##system('cd ~/R/data.table && git rev-list -n1 --before="2021-01-01" master')
  ##old.sha <- "eed712ef45fd9198de6aa1ac1b672a7347253d18"
  ##system('cd ~/R/data.table && git rev-list -n1 --before="2020-07-24" master')
  ##old.sha <- "aa608710cf0ec03c3c6cc3d7c03c96f2034ac856"
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
    }else{
      parent.msg
    }
    sig.diff.dt[diff.i, comments := this.comment]
    ##display as https://github.com/Rdatatable/data.table/commit/c344cee0e7459a43696c49d63bf79d39acf31c55
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
  diffs.csv <- file.path(Rvers, "significant_differences.csv")
  data.table::fwrite(sig.diff.dt, diffs.csv)
  print(sig.diff.dt)
}
