job.dir <- readLines("JOBDIR", n=1)
rmarkdown::render("analyze.Rmd")
job.date <- basename(job.dir)
index.html <- file.path("analyze", job.date, "index.html")
unlink(index.html)
file.copy("analyze.html", index.html)
##system(paste("cd analyze && ln -f", job.date, "00_latest"))
analyze.dirs <- sort(Sys.glob("analyze/*"), decreasing=TRUE)
keep.dirs <- analyze.dirs[1:min(7,length(analyze.dirs))]
rm.dirs <- setdiff(analyze.dirs, keep.dirs)
unlink(rm.dirs, recursive=TRUE)
system("cd ~/genomic-ml && unpublish_data data.table-revdeps && publish_data data.table-revdeps")
unlink(job.dir, recursive=TRUE)

