(job.dir <- readLines("JOBDIR", n=1))
rmarkdown::render("analyze.Rmd")
job.date <- basename(job.dir)
index.html <- file.path("analyze", job.date, "index.html")
unlink(index.html)
file.copy("analyze.html", index.html)
analyze.dirs <- sort(Sys.glob("analyze/*"), decreasing=TRUE)
max.check.days <- 7
keep.dirs <- analyze.dirs[1:min(max.check.days,length(analyze.dirs))]
(rm.dirs <- setdiff(analyze.dirs, keep.dirs))
unlink(rm.dirs, recursive=TRUE)
system("cd /projects/genomic-ml && unpublish_data data.table-revdeps && publish_data data.table-revdeps")
unlink("/scratch/th798/data.table-revdeps/*", recursive=TRUE)

