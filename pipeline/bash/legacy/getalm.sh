#!/bin/bash
cd `dirname $0`
julia-0.5.0 --machinefile ../workspace/machine-files/one-process-each.machinefile -e "using Pipeline; Pipeline.getalm($1, \"$2\", \"$3\", $4)"

