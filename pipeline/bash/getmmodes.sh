#!/bin/bash
cd `dirname $0`
OMP_NUM_THREADS=16 julia-0.5.0 -e "using Pipeline; Pipeline.getmmodes($1)"

