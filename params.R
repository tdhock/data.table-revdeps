if(!requireNamespace("data.table"))install.packages("~/R/data.table",repo=NULL)
if(!requireNamespace("nc"))install.packages("~/R/nc",repo=NULL)
library(data.table)
cran.url <- "http://cloud.r-project.org/"
options(repos=c(CRAN=cran.url))
avail = available.packages(repos=cran.url)
deps = tools::package_dependencies(
  "data.table",
  db = avail,  # just CRAN revdeps though (not Bioc) from October 2020
  which="all",
  reverse=TRUE,
  recursive=FALSE
)[[1]]
dt.git.dir <- "~/R/data.table"
git.cmds <- paste(
  "cd", dt.git.dir,
  "&& git checkout master && git pull && git log|head -1")
git.out <- system(git.cmds, intern=TRUE)
master.sha <- sub("commit ", "", git.out[length(git.out)])
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
build.modules <- c(sf="gdal/3.3.1", runjags="jags", Rmpi="openmpi", "anaconda3")
load.vec <- paste("module load", build.modules, "&&")
load.str <- paste(load.vec, collapse=" ")
(env.setup <- paste(load.str, "conda activate emacs1 &&"))
path.cmd <- paste(env.setup, "echo $PATH")
path.str <- system(path.cmd,intern=TRUE)
path.vec <- strsplit(path.str, ":")[[1]]
openmpi.bin <- grep('openmpi', path.vec, value=TRUE)
openmpi.dir <- dirname(openmpi.bin)

## Build R-devel and R-release.
rebuild.R <- TRUE
R.src.prefix <- "~/R"
if(rebuild.R){
  unlink(file.path(R.src.prefix, "R-devel*"), recursive=TRUE)
}
banner.lines <- readLines(paste0(cran.url, "banner.shtml"))
banner.row <- nc::capture_all_str(
  banner.lines,
  '"',
  path='.*?tar[.]gz',
  '"')
R.vec <- c(
  "src/base-prerelease/R-devel.tar.gz",
  banner.row$path)
R.ver.vec <- c()
for(R.i in seq_along(R.vec)){
  path.tar.gz <- R.vec[R.i]
  R.tar.gz <- basename(path.tar.gz)
  R.dir <- sub(".tar.gz", "", R.tar.gz)
  R.ver.path <- normalizePath(
    file.path(R.src.prefix, R.dir))
  local.tar.gz <- file.path(R.src.prefix, R.tar.gz)
  includes <- c("$CONDA_PREFIX","$HOME")
  libs <- c("$CONDA_PREFIX/lib","$HOME/lib","$HOME/lib64")
  flag <- function(VAR, value.vec, collapse){
    paste0(VAR, '="', paste(value.vec, collapse=collapse), '"')
  }
  build.cmd <- paste(
    env.setup,
    "cd", R.src.prefix,
    "&& tar xf", R.tar.gz,
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
    './configure --prefix=$HOME --enable-memory-profiling',
    '&& make clean && LC_ALL=C make')
  if(!file.exists(local.tar.gz)){
    R.url <- paste0(cran.url, path.tar.gz)
    download.file(R.url, local.tar.gz)
    cat(build.cmd,"\n")
    system(build.cmd)
    R <- file.path(R.ver.path, "bin", "R")
    R.e <- function(cmd){
      R.cmd <- sprintf(
        "%s R_LIBS_USER= %s %s -e '%s' 2>&1",
        env.setup,
        PKG_CONFIG_PATH,
        R,
        cmd)
      print(R.cmd)
      system(R.cmd)
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
    R.e(sprintf('install.packages("Rmpi",configure.args="--with-mpi=%s")', openmpi.dir))
    R.e('install.packages("RODBC",configure.args="--with-odbc-manager=odbc")')
    R.e('install.packages("slam");install.packages("Rcplex",configure.args="--with-cplex-dir=/home/th798/cplex")')#conda install -c ibmdecisionoptimization cplex only installs python package, need to register on IBM web site, download/install cplex, then install.packages slam, then install packages Rcplex with configure args.
    R.e('dep <- read.csv("~/genomic-ml/data.table-revdeps/popular_deps.csv")$dep;ins <- rownames(installed.packages());print(some <- dep[!dep %in% ins]);install.packages(some)')
  }
  R.ver.vec[[R.dir]] <- R.ver.path
}

## Build vignettes and make sure conda env is activated so pandoc is
## available.
if(!requireNamespace("rmarkdown"))install.packages("rmarkdown")
master.build.cmd <- paste(
  "module load anaconda3 &&",
  "conda activate emacs1 &&",
  R.home("bin/R"), "CMD build", dt.git.dir)
system(master.build.cmd)
master.old <- paste0("data.table_", master.version, ".tar.gz")
dl.row <- download.packages("data.table", destdir=".")
colnames(dl.row) <- c("pkg", "path")
release.old <- dl.row[,"path"]

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
master.new <- file.path(
  scratch.dir, paste0(
    "data.table_master_", master.version, ".", master.sha, ".tar.gz"))
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
  file.path(R.ver.vec, "bin", "R"),
  "--vanilla",
  "--args",
  deps.csv,
  "$SLURM_ARRAY_TASK_ID",
  release.new,
  master.new,
  "<",
  normalizePath("check_one.R", mustWork=TRUE))
run_one_contents = paste0("#!/bin/bash
#SBATCH --array=1-", n.deps, "
#SBATCH --time=6:00:00
#SBATCH --mem=16GB
#SBATCH --cpus-per-task=1
#SBATCH --output=", log.txt, "
#SBATCH --error=", log.txt, "
#SBATCH --job-name=dt", today.str, "
module unload R
", paste(R.cmds, collapse="\n"))
run_one_sh = file.path(scratch.dir, "run_one.sh")
writeLines(run_one_contents, run_one_sh)
cat(
  "Try a test run:\nSLURM_ARRAY_TASK_ID=",
  deps.dt[Package=="ShinyQuickStarter", task.id],
  " bash ", run_one_sh, "\n", sep="")

sbatch.cmd <- paste("sbatch", run_one_sh)
sbatch.out <- system(sbatch.cmd, intern=TRUE)
JOBID <- gsub("[^0-9]", "", sbatch.out)
cat(JOBID, "\n", file=file.path(scratch.dir, "JOBID"))
analyze.R <- normalizePath("analyze.R", mustWork=TRUE)
analyze_sh_contents = paste0("#!/bin/bash
#SBATCH --time=4:00:00
#SBATCH --mem=4GB
#SBATCH --cpus-per-task=1
#SBATCH --output=analyze.out
#SBATCH --error=analyze.out
#SBATCH --depend=afterany:", JOBID, "
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
##1 0 * * * sbatch ~/bin/params.sh
if(FALSE){
  system(paste("sbatch", params_sh))#now re-launched via crontab.
}
