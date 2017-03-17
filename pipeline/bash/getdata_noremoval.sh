#!/bin/bash
cd `dirname $0`
julia --machinefile ../workspace/machine-files/max-processes-each.machinefile -e "using Pipeline; Pipeline.getdata($1, dosources=false, dosun=false, dorfi=false)"

