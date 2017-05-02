#!/bin/bash

set -eux

JULIA=julia-0.5.0

cd `dirname $0`/../..
input="flagged-raw-$2-visibilities"
$JULIA -e \
    "include(\"pipeline/Pipeline.jl\"); @time Pipeline.Calibration.sawtooth($1, \"$input\")"

