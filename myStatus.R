get_check_cmd <- function(pkg.tar.gz){
  paste(
    "TERM=dumb",
    "_R_CHECK_TESTS_NLINES_=0",
    "_R_CHECK_FORCE_SUGGESTS_=0",
    R.home("bin/R"),
    "CMD check --timings",
    pkg.tar.gz)
}
## find and replace for significant differences.
fun.list <- list(
  replace.tmpfile=function(lines){
    gsub("/tmp/Rtmp.*?/file[a-f0-9]+", "/tmp/RtmpXXX/fileXXX", lines, perl=TRUE)
  },
  replace.tmpdir=function(lines){
    gsub("/tmp/Rtmp.*?/", "/tmp/RtmpXXX/", lines)
  },
  remove.Duration=function(lines){
    gsub("  Duration:.*", "  Duration: IRRELEVANT", lines)
  },
  remove.time=function(lines){
    gsub("  [[].*?[]] ", "[XX:XX:XX]", lines)
  },
  ## single-line parsers above.
  vec.to.string=function(lines){
    paste(lines, collapse="\n")
  },
  ## multi-line string parsers below.
  remove.size=function(string){
    sub(
      "\n[*] checking installed package size.*\n(.*\n)*?[*]",
      "\n*", string, perl=TRUE)
  })
someLog <- function(log.file){
  log.lines <- readLines(log.file)
  for(fun.i in seq_along(fun.list)){
    fun <- fun.list[[fun.i]]
    log.lines <- fun(log.lines)
  }
  strsplit(log.lines, "\n")[[1]]
}
myStatus <- function(log.file, line.vec=NULL){
  if(!is.character(line.vec)){
    line.vec <- someLog(log.file)
  }
  nc::capture_first_vec(
    line.vec,
    "[*] ",
    nc::field("checking", " ", '.*'),
    " [.]{3}.*?",
    msg="[A-Z]+",
    "$",
    nomatch.error=FALSE
  )[!is.na(msg)]
}
myDiff <- function(Rvers.dir){
  check.log.vec <- Sys.glob(file.path(Rvers.dir, "*", "00check.log"))
  if(length(check.log.vec) != 2){
    print(check.log.vec)
    stop("there should be two log files, one for each data.table version")
  }
  status.dt.list <- list()
  for(log.i in seq_along(check.log.vec)){
    check.log <- check.log.vec[[log.i]]
    dt.vers <- sub("_.*", "", basename(dirname(check.log)))
    some.status <- myStatus(check.log)
    status.dt.list[[log.i]] <- data.table(
      dt.vers,
      some.status)
  }
  status.dt <- do.call(rbind, status.dt.list)
  status.wide <- dcast(status.dt, checking ~ dt.vers, value.var="msg")
  NA2T <- function(x)ifelse(is.na(x), TRUE, x)
  status.wide[NA2T(master != release)]
}  
get_flavor <- function(Rvers)ifelse(
  grepl("devel", Rvers),
  "r-devel-linux-x86_64-debian-gcc",
  "r-release-linux-x86_64")
