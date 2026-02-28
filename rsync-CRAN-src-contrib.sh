#!/bin/bash
rsync -rptlzv --delete --exclude='*/' cran.r-project.org::CRAN/src/contrib/ /projects/genomic-ml/CRAN/src/contrib/
