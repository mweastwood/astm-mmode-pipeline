#!/bin/bash

set -eux

JULIA=julia-0.5.0
MACHINEFILE_MAX=workspace/machine-files/max-processes-each.machinefile

cd `dirname $0`/../..
$JULIA --machinefile $MACHINEFILE_MAX -e \
    "include(\"pipeline/Pipeline.jl\"); Pipeline.getdata($1, \"$2\")"

