#!/bin/bash
cd `dirname $0`
OMP_NUM_THREAS=16 julia-0.5.0 -e "using Pipeline; Pipeline.makemap($1, \"$2\", \"$3\")"

