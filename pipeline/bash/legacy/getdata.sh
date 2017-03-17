#!/bin/bash
cd `dirname $0`
julia-0.5.0 --machinefile ../workspace/machine-files/max-processes-each.machinefile -e "using Pipeline; Pipeline.getdata($1)"

