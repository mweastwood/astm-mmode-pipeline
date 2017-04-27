#!/bin/bash

# test spawning workers on all of the ASTM machines

set -eu
cd `dirname $0`

JULIA=julia-0.5.0
PROGRAM='
    for astm = 4:13
        @show astm
        str = @sprintf("astm%02d", astm)
        @time addprocs([(str,1)])
    end
'

$JULIA -e "$PROGRAM"

