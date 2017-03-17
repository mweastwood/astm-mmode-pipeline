#!/bin/bash
cd `dirname $0`
julia --machinefile ../workspace/machine-files/one-process-each.machinefile -e "using Pipeline; Pipeline.getmodel($1, \"$2\", \"$3\", \"$4\")"

