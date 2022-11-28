cargs <- commandArgs(trailingOnly=TRUE)
if(length(cargs)==0){
  cargs <- c("examples", "OK", "/tmp/th798/56828791/Rtmp8bOMKk/downloaded_packages/mlr3tuning_0.17.0.tar.gz", "1.14.6")
}
names(cargs) <- c("checking","expected","rev_dep_tar_gz","dt_release_version")
cargs

## First edit version.
desc.row <- read.dcf("DESCRIPTION")
find.vers <- desc.row[,"Version"]
repl.vers <- cargs[["dt_release_version"]]
files.to.edit <- "DESCRIPTION src/init.c"
sed.cmd <- sprintf(
  "sed -i 's/%s/%s/' %s",
  find.vers,
  repl.vers,
  files.to.edit)
system(sed.cmd)
##install edited package:
install.packages('.',repos=NULL)
##un-edit.
system(paste("git checkout --", files.to.edit))
source('~/genomic-ml/data.table-revdeps/myStatus.R')
check.cmd <- get_check_cmd(cargs[["rev_dep_tar_gz"]])
system(check.cmd)
pkg <- sub("_.*", "", basename(cargs[['rev_dep_tar_gz']]))
check.log <- file.path(
  paste0(pkg, ".Rcheck"),
  "00check.log")
print(status.dt <- myStatus(check.log))
print(status.row <- status.dt[ checking==cargs[['checking']] ])
q(status=if(identical(status.row$msg,cargs[['expected']]))0 else 1)
