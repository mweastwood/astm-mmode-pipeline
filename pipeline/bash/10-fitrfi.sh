#!/bin/bash

set -eux

JULIA=julia-0.5.0

cd `dirname $0`/../..
input="calibrated-$2-visibilities"
$JULIA -e \
    "include(\"pipeline/Pipeline.jl\"); @time Pipeline.fitrfi($1, \"$input\")"

