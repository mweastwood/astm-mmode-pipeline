#!/bin/bash
cd `dirname $0`
julia --machinefile ../workspace/machine-files/max-processes-except-astm11.machinefile -e "using Pipeline; Pipeline.gettransfermatrix($1)"

