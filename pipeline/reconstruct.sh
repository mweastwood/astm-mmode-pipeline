#!/bin/bash
cd `dirname $0`
OMP_NUM_THREAS=16 julia -e "using Pipeline; Pipeline.reconstruct($1, \"$2\", \"$3\", \"$4\", $5)"

