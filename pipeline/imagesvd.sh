#!/bin/bash
cd `dirname $0`
OMP_NUM_THREAS=16 julia -e "using Pipeline; Pipeline.imagesvd($1, $2)"

