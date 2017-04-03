#!/bin/bash

set -eux

JULIA=julia-0.5.0

cd `dirname $0`/../..
input="mmodes-peeled-$2"
$JULIA -e \
    "include(\"pipeline/Pipeline.jl\"); @time Pipeline.fitrfi_mmodes($1, \"$input\")"

