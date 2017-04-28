#!/bin/bash

set -eux

JULIA=julia-0.5.0

cd `dirname $0`/../..
input="peeled-$2-visibilities"
$JULIA -e \
    "include(\"pipeline/Pipeline.jl\"); @time Pipeline.fitrfi_special($1, \"$input\")"

