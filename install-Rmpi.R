## This is a simplified version of params.R, used for testing if Rmpi
## can be installed.
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
rebuild.R <- FALSE
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
  }
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
  R.e(sprintf('install.packages("Rmpi",configure.args="--with-mpi=%s")', openmpi.dir))
  R.ver.vec[[R.dir]] <- R.ver.path
}
