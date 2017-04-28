#!/bin/bash

set -eux

JULIA=julia-0.5.0

cd `dirname $0`/../..
input="rfi-subtracted-peeled-$2-visibilities"
$JULIA -e \
    "include(\"pipeline/Pipeline.jl\"); @time Pipeline.fold($1, \"$input\")"

