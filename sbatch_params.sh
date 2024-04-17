#!/bin/bash
ANALYZE=$(squeue -u th798 -o "%j"|grep ^analyze)
if [ "$ANALYZE" == "" ]; then
    sbatch ~/bin/params.sh
else
    echo analyze not done yet, so not launching another params job
fi
