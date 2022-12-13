#!/bin/bash
module load anaconda3
conda activate emacs1
conda env export --from-history > emacs1-env-from-history.yml
