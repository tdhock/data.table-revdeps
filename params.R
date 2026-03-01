if(!requireNamespace("data.table"))install.packages("~/R/data.table",repo=NULL)
if(!requireNamespace("nc"))install.packages("~/R/nc",repo=NULL)
library(data.table)
cran.url <- "http://cloud.r-project.org/"#for banner R version and source.
options(repos=c(CRAN="file:///projects/genomic-ml/CRAN"))
if(!requireNamespace("BiocManager"))install.packages("BiocManager")
avail = available.packages(repos=BiocManager::repositories())
all.deps = tools::package_dependencies(
  "data.table",
  db=avail,
  reverse=TRUE,
  recursive=TRUE
)[[1]]
is.bioc <- grepl("bioconductor", avail[,"Repository"])
from.bioc <- avail[is.bioc, "Package"]
bioc.deps <- intersect(from.bioc, all.deps)
missing.dt <- nc::capture_all_str(
  "params.teeout",
  "there is no package called .",
  dep='[^"]+?',
  ".\n")
fwrite(unique(missing.dt),"missing.deps.csv")
deps = tools::package_dependencies(
  "data.table",
  db = avail[!is.bioc,],# just CRAN revdeps though (not Bioc) from October 2020
  which="all",
  reverse=TRUE,
  recursive=FALSE
)[[1]]
dt.git.dir <- "~/R/data.table"
popular_deps.csv <- "~/genomic-ml/data.table-revdeps/popular_deps.csv"
popular_deps <- fread(popular_deps.csv)
(popular_deps <- data.table(dep=unique(c(
  popular_deps$dep,
  bioc.deps,
  missing.dt$dep))))
fwrite(popular_deps,popular_deps.csv)
git.cmds <- paste(
  "cd", dt.git.dir,
  "&& git checkout master && git pull && git log|head -1")
git.out <- system(git.cmds, intern=TRUE)
master.sha <- sub("commit ", "", git.out[length(git.out)])
pretty.cmd <- paste(
  "cd", dt.git.dir,
  '&& git log --pretty=format:"%h - %s"|head -1')
pretty.line <- system(pretty.cmd, intern=TRUE)
writeLines(pretty.line, "data.table_master.git.log")
master.desc <- read.dcf(file.path(dt.git.dir, "DESCRIPTION"))
master.version <- master.desc[, "Version"]
if(FALSE){
  # before build need to install deps.
  install.packages("data.table", dep=TRUE)
  system("conda install pandoc")
  ## for building R
  if(FALSE){#old
  system("conda install -c biobuilds readline-devel")
  system("conda install -c rmg glibc")
  system("conda install -c anaconda openssl libxml2 freetype libxcb libtiff pango")
  system("conda install -c conda-forge proj gsl mpi av fftw imagemagick mysql-devel netcdf4 librsvg icu pkg-config gdal jpeg libcurl texinfo fontconfig cairo xorg-libx11 xorg-libxt xorg-libxext xorg-libxau xorg-libxrender libgomp")
  }
  system("conda install -c conda-forge pandoc udunits readline openssl libxml2 freetype libxcb libtiff pango glib proj gsl mpi av fftw imagemagick mysql-devel netcdf4 librsvg icu pkg-config gdal jpeg libcurl texinfo fontconfig cairo xorg-libx11 xorg-libxt xorg-libxext xorg-libxau xorg-libxrender libgomp gfortran gcc g++")
  tinytex::install_tinytex()
  tinytex:::install_yihui_pkgs()
  system('tlmgr search --global --file "/grfext.sty"')
  system("tlmgr install grfext")
}

conda.pkgs <- c(
  tcltk2="tk",
  protolite="protobuf",
  odbc="pyodbc",
  pdftools="poppler",
  ssh="libssh",
  tesseract="tesseract",
  gifski="rust",
  sodium="libsodium",
  Rmpfr="mpfr",
  redland="rdflib",
  glpkAPI="glpk",
  clustermq="zeromq",
  RPostgres="libpq",
  xslt="libxslt",
  RQuantLib="quantlib",
  RODBC="r-rodbc",
  jqr="jq")
## some libraries are installed under $HOME (openssl), some using
## module system (gdal), and most others via conda.
build.modules <- c(
  sf="gdal/3.3.1",
  runjags="jags",
  Rmpi="openmpi",
  "anaconda3",
  Rfast="gcc")
load.vec <- paste("module load", build.modules, "&&")
load.str <- paste(load.vec, collapse=" ")
(env.setup <- paste(load.str, "conda activate emacs1 &&"))
path.cmd <- paste(env.setup, "echo $PATH")
path.str <- system(path.cmd,intern=TRUE)
path.vec <- strsplit(path.str, ":")[[1]]
openmpi.bin <- grep('openmpi', path.vec, value=TRUE)
openmpi.dir <- dirname(openmpi.bin)

## create scratch dir.
now <- Sys.time()
tomorrow <- now+60*60*24
today.str <- strftime(now, "%Y-%m-%d")
tomorrow.str <- strftime(tomorrow, "%Y-%m-%d")
USER <- Sys.getenv("USER")
scratch.dir <- file.path(
  "/scratch",
  USER,
  "data.table-revdeps",
  today.str)
writeLines(scratch.dir, "JOBDIR")
dir.create(scratch.dir, showWarnings = FALSE, recursive = TRUE)
R.src.prefix <- "~/R"

## Build R-devel and R-release.
banner.lines <- readLines(paste0(cran.url, "banner.shtml"))
banner.row <- nc::capture_all_str(
  banner.lines,
  '"',
  path='.*?tar[.]gz',
  '"')
R.vec <- c(
  devel="src/base-prerelease/R-devel.tar.gz",
  release=banner.row$path)
R.ver.vec <- c()
for(R.i in seq_along(R.vec)){
  path.tar.gz <- R.vec[R.i]
  version.lower <- names(path.tar.gz)
  R.tar.gz <- basename(path.tar.gz) 
  R.dir <- paste0("R-", version.lower)
  R.dir.orig <- sub(".tar.gz", "", R.tar.gz)
  R.ver.path <- normalizePath(
    file.path(R.src.prefix, R.dir))
  R <- file.path(R.ver.path, "bin", "R")
  rebuild.R <- if(interactive()){
    FALSE
  }else if(version.lower=="devel"){
    TRUE
  }else{
    R.version.lines <- system(paste(R, "--version"), intern=TRUE)
    installed.R.vers <- nc::capture_all_str(
      R.version.lines[2], "^R version ", version=".*?", " [(]"
    )[, paste0("R-", version)]
    installed.R.vers != R.dir.orig
  }
  includes <- c("$CONDA_PREFIX","$HOME")
  libs <- c("$CONDA_PREFIX/lib","$HOME/lib","$HOME/lib64")
  flag <- function(VAR, value.vec, collapse){
    paste0(VAR, '="', paste(value.vec, collapse=collapse), '"')
  }
  build.cmd <- paste(
    env.setup,
    "cd", R.src.prefix,
    "&& tar xf", R.tar.gz,
    if(R.dir.orig!=R.dir)paste("&& mv", R.dir.orig, R.dir),
    "&& cd", R.dir,
    '&&',
    ## flag("FC", "$CONDA_PREFIX/bin/gfortran", ""),
    ## flag("CC", "$CONDA_PREFIX/bin/gcc", ""),
    ## flag("CXX", "$CONDA_PREFIX/bin/g++", ""),
    PKG_CONFIG_PATH <- flag("PKG_CONFIG_PATH", paste0(libs, "/pkgconfig"), ":"),
    flag("CPPFLAGS", paste0("-I", includes, "/include"), " "),
    flag(
      "LDFLAGS",
      paste0("-L", libs, " -Wl,-rpath=", libs),
      " "),
    './configure',
    '--prefix=$HOME',
    '--enable-memory-profiling',
    '--with-tcl-config=$CONDA_PREFIX/lib/tclConfig.sh',
    '--with-tk-config=$CONDA_PREFIX/lib/tkConfig.sh',
    '&& make clean && LC_ALL=C make')
  R.e <- function(cmd){
    R.cmd <- sprintf(
      "%s R_LIBS_USER= %s xvfb-run -d %s -e '%s' 2>&1",
      env.setup,
      PKG_CONFIG_PATH,
      R,
      cmd)
    print(R.cmd)
    system(R.cmd)
  }
  if(rebuild.R){
    ## first save popular packages.
    base.rec.pkgs <- basename(c(
      dirname(Sys.glob(file.path(
        R.ver.path,"src","library","*","DESCRIPTION"))),
      sub("[.]tgz$", "", Sys.glob(file.path(
        R.ver.path,"src","library","Recommended","*.tgz")))
    ))
    already.installed <- dir(file.path(R.ver.path, "library"))
    save.pkgs <- setdiff(already.installed,base.rec.pkgs)
    pop.lib.vec <- file.path(R.ver.path,"library",save.pkgs)
    library.save <- file.path(R.src.prefix, "library-save", version.lower)
    dir.create(library.save, showWarnings = FALSE, recursive = TRUE)
    pop.save.vec <- file.path(library.save,save.pkgs)
    file.rename(pop.lib.vec, pop.save.vec)
    ## Then delete old base R source.
    local.tar.gz <- file.path(R.src.prefix, R.tar.gz)
    unlink(local.tar.gz)
    unlink(R.ver.path, recursive = TRUE)
    ## Then download base R source and build.
    R.url <- paste0(cran.url, path.tar.gz)
    download.file(R.url, local.tar.gz)
    cat(build.cmd,"\n")
    system(build.cmd)
    ## Then restore saved packages.
    file.rename(pop.save.vec, pop.lib.vec)
    ## these packages need to be installed specially when R is first
    ## built, but do not need any special update.
    R.e('install.packages("BiocManager")')#needed for popular deps from bioc.
  }
  if(FALSE){
    ## These are notes for installing some system libraries from source.
    system("cd ~/src/icu && PKG_CONFIG_PATH=$HOME/lib/pkgconfig:$HOME/lib64/pkgconfig:$HOME/.conda/envs/emacs1/lib/pkgconfig ./configure --prefix=$HOME && make && make install")
    system('cd ~/src/rasqual-0.9.33 && LDFLAGS="-L$HOME/.conda/envs/emacs1/lib -Wl,-rpath=$HOME/.conda/envs/emacs1/lib" PKG_CONFIG_PATH=$HOME/lib/pkgconfig:$HOME/lib64/pkgconfig:$HOME/.conda/envs/emacs1/lib/pkgconfig ./configure --prefix=$HOME && make && make install')
    system('cd ~/src/raptor2-2.0.15 && LDFLAGS="-L$HOME/.conda/envs/emacs1/lib -Wl,-rpath=$HOME/.conda/envs/emacs1/lib" PKG_CONFIG_PATH=$HOME/lib/pkgconfig:$HOME/lib64/pkgconfig:$HOME/.conda/envs/emacs1/lib/pkgconfig ./configure --prefix=$HOME && make && make install')
    system('cd ~/redland-1.0.17 && LDFLAGS="-L$HOME/.conda/envs/emacs1/lib -Wl,-rpath=$HOME/.conda/envs/emacs1/lib" PKG_CONFIG_PATH=$HOME/lib/pkgconfig:$HOME/lib64/pkgconfig:$HOME/.conda/envs/emacs1/lib/pkgconfig ./configure --with-mysql=no --with-virtuoso=no --prefix=$HOME && make && make install')
    R.e('install.packages("redland")')#build icu first https://github.com/unicode-org/icu/releases/tag/release-70-1 from https://download.librdf.org/source/ CFLAGS=-I$HOME/.conda/envs/emacs1/include LDFLAGS="-L$HOME/.conda/envs/emacs1/lib -Wl,-rpath=$HOME/.conda/envs/emacs1/lib" ./configure --prefix=$HOME && make && make install
    R.e('install.packages("RQuantLib")')#works if we have quantlib, but conda install quantlib hangs. ./configure --with-boost-include=$HOME/.conda/envs/emacs1/include --with-boost-lib=$HOME/.conda/envs/emacs1/lib --prefix=$HOME && make && make install
    R.e('install.packages("gifski")')#works, after install rust to homedir via "curl https://sh.rustup.rs -sSf | sh"
    ## OK ABOVE
    ##R.e('install.packages("symengine")')#mpfr installed but cant find, posted https://github.com/symengine/symengine.R/issues/119
  }
  options.repos.bioc <- 'options(repos=c(if(requireNamespace("BiocManager"))BiocManager::repositories(),CRAN="http://cloud.r-project.org"))'
  ## These packages have special installation procedures, and there
  ## are not a lot of them, so we can run them for both R
  ## versions. Will update if there is a new version on CRAN.
  R.e(sprintf('install.packages("Rmpi",configure.args="--with-mpi=%s")', openmpi.dir))
  R.e('install.packages("RODBC",configure.args="--with-odbc-manager=odbc")')
  ##R.e('install.packages("slam");install.packages("Rcplex",configure.args="--with-cplex-dir=/home/th798/cplex")')#conda install -c ibmdecisionoptimization cplex only installs python package, need to register on IBM web site, download/install cplex, then install.packages slam, then install packages Rcplex with configure args.
  R.e('install.packages("slam");install.packages("~/R/Rcplex",repos=NULL,configure.args="--with-cplex-dir=/home/th798/cplex")')#conda install -c ibmdecisionoptimization cplex only installs python package, need to register on IBM web site, download/install cplex, then install.packages slam, then install packages Rcplex with configure args.
  R.e(sprintf('%s;dep <- read.csv("missing.deps.csv")$dep;install.packages(dep)', options.repos.bioc))#not dep=TRUE since these are deps (not checked) of revdeps (which we check).
  R.e(sprintf('%s;dep <- read.csv("%s")$dep;ins <- rownames(installed.packages());print(some <- dep[!dep %%in%% ins]);install.packages(some)', options.repos.bioc, popular_deps.csv))#not dep=TRUE since these are deps (not checked) of revdeps (which we check).
  R.e(sprintf('%s;update.packages(ask=FALSE)', options.repos.bioc))
  if(FALSE){
    ## install deps from bioc now.
  }
  R.java.cmd <- paste(R, "CMD javareconf")
  system(R.java.cmd)
  R_VERSION <- paste0("R_",toupper(version.lower))
  R.e(sprintf('cat(gsub("[()]", "", gsub(" ", "_", R.version[["version.string"]])), file="%s")', file.path(scratch.dir, R_VERSION)))
  R.ver.vec[[R.dir]] <- R.ver.path
}

## Build vignettes and make sure conda env is activated so pandoc is
## available.
if(!requireNamespace("litedown"))install.packages("litedown")
master.build.cmd <- paste(
  "module load anaconda3 &&",
  "conda activate emacs1 &&",
  R.home("bin/R"),
  "CMD build",
  dt.git.dir,
  "2>&1 | tee build_dt.out")
unlink("data.table*tar.gz")
system(master.build.cmd)
master.old <- paste0("data.table_", master.version, ".tar.gz")
dl.row <- download.packages("data.table", destdir=".")
colnames(dl.row) <- c("pkg", "path")
release.old <- dl.row[,"path"]

## copy data table source packages to /scratch
master.new <- file.path(
  scratch.dir, paste0(
    "data.table_master_", master.version, ".", master.sha, ".tar.gz"))
if(grepl(" ", master.new))stop(master.new)
file.copy(master.old, master.new, overwrite=TRUE)
release.new <- file.path(
  scratch.dir,
  sub("_", "_release_", basename(release.old)))
file.copy(release.old, release.new, overwrite=TRUE)
n.deps <- length(deps)
##n.deps <- 2
task.id <- seq(1, n.deps)
deps.dt <- data.table(Package=deps[task.id], task.id)
deps.csv <- file.path(scratch.dir, "deps.csv")
data.table::fwrite(deps.dt, deps.csv)

packages.dir <- file.path(scratch.dir, "packages")
unlink(packages.dir, recursive=TRUE)
dir.create(packages.dir, showWarnings=FALSE)
for(dep.i in 1:nrow(deps.dt)){
  dir.i <- file.path(scratch.dir, "tasks", dep.i)
  dir.create(dir.i, showWarnings=FALSE, recursive=TRUE)
  dir.pkg <- file.path(packages.dir, deps.dt[dep.i, Package])
  system(paste("ln -s", dir.i, dir.pkg))
}

log.txt <- file.path(scratch.dir, "tasks", "%a", "log.txt")
task.dir <- file.path(
  "/tmp",
  USER,
  "$SLURM_JOB_ID",
  basename(paste(R.ver.vec)),
  "$SLURM_ARRAY_TASK_ID")  
tmp.lib <- file.path(task.dir, "library")
cache.dir <- file.path(task.dir, "R.cache")
R.cmds <- paste(
  env.setup,
  "mkdir -p", tmp.lib, "&&",
  "mkdir -p", cache.dir, "&&",
  "LC_ALL=C",
  PKG_CONFIG_PATH,
  paste0("R_CACHE_ROOTPATH=", cache.dir),
  paste0("R_LIBS_USER=", tmp.lib),
  "xvfb-run -d",
  file.path(R.ver.vec, "bin", "R"),
  "--vanilla",
  "--args",
  deps.csv,
  "$SLURM_ARRAY_TASK_ID",
  release.new,
  master.new,
  "<",
  normalizePath("check_one.R", mustWork=TRUE))
large_memory <- fread("large_memory.csv")
array.mem.dt <- deps.dt[
, gigabytes := ifelse(Package %in% large_memory$Package, 16, 4)
][, {
  d <- diff(gigabytes)!=0
  is.start <- c(TRUE,d)
  is.end <- c(d,TRUE)
  data.table(
    gigabytes=gigabytes[is.start],
    start=which(is.start),
    end=which(is.end))
}][
, indices := ifelse(start==end, start, paste0(start,"-",end))
][, data.table(
  array=paste(indices,collapse=","),
  job=NA_character_
), by=gigabytes]
for(array.mem.i in 1:nrow(array.mem.dt)){
  array.mem.row <- array.mem.dt[array.mem.i]
  run_one_contents = paste0("#!/bin/bash
#SBATCH --array=", array.mem.row$array, "
#SBATCH --time=9:00:00
#SBATCH --mem=", array.mem.row$gigabytes, "GB
#SBATCH --cpus-per-task=1
#SBATCH --output=", log.txt, "
#SBATCH --error=", log.txt, "
#SBATCH --job-name=dt", today.str, "
module unload R
", paste(R.cmds, collapse="\n"))
  run_one_sh = file.path(scratch.dir, sprintf("run_one_%dGB.sh", array.mem.row$gigabytes))
  writeLines(run_one_contents, run_one_sh)
  cat(
    "Try a test run:\nSLURM_ARRAY_TASK_ID=",
    deps.dt[Package=="ShinyQuickStarter", task.id],
    " bash ", run_one_sh, "\n", sep="")
  sbatch.cmd <- paste("sbatch", run_one_sh)
  sbatch.out <- system(sbatch.cmd, intern=TRUE)
  JOBID <- gsub("[^0-9]", "", sbatch.out)
  array.mem.dt[array.mem.i, job := JOBID]
  cat(JOBID, "\n", file=file.path(scratch.dir, "JOBID"), append=TRUE)
}

cat(Sys.getenv("SLURM_JOB_ID"), "\n", file=file.path(scratch.dir, "PARAMS_ID"))
analyze.R <- normalizePath("analyze.R", mustWork=TRUE)
## https://hpc.nih.gov/docs/job_dependencies.html
JOBID.colon <- paste(array.mem.dt$job, collapse=":")
analyze_sh_contents = paste0("#!/bin/bash
#SBATCH --time=4:00:00
#SBATCH --mem=4GB
#SBATCH --cpus-per-task=1
#SBATCH --output=analyze.out
#SBATCH --error=analyze.out
#SBATCH --depend=afterany:", JOBID.colon, "
#SBATCH --job-name=analyze", today.str, "
", env.setup, R.home("bin/R"), " --vanilla < ", analyze.R, "\n")
cat(analyze_sh_contents, file="analyze.sh")
system("sbatch analyze.sh")

params_sh_contents = paste0("#!/bin/bash
#SBATCH --time=10:00:00
#SBATCH --mem=16GB
#SBATCH --cpus-per-task=1
#SBATCH --output=params.out
#SBATCH --error=params.out
#SBATCH --begin=", tomorrow.str, "T00:01
#SBATCH --job-name=params", today.str, "
export HOME=~
export USER=`whoami`
. ~/.bashrc
export
cd ~/genomic-ml/data.table-revdeps
", env.setup, " /packages/R/4.1.2/bin/R --no-save < ",
"params.R 2>&1 | tee params.teeout\n")
params_sh <- "~/bin/params.sh"
cat(params_sh_contents, file=params_sh)
crontab.line <- system("crontab -l|grep params.sh",intern=TRUE)
##1 0 * * * ~/bin/sbatch_params.sh
if(FALSE){
  system(paste("sbatch", params_sh))#now re-launched via crontab.
}
