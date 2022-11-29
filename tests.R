library(data.table)
source("myStatus.R")
## these folders 
test.dir.vec <- Sys.glob("tests/nodiff/*")
for(test.dir in test.dir.vec){
  diff.dt <- myDiff(test.dir)
  if(nrow(diff.dt)){
    print(diff.dt)
  }
}
