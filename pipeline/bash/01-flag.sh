#!/bin/bash

set -eux

JULIA=julia-0.5.0

cd `dirname $0`/../..
input="raw-$2-visibilities"
$JULIA -e \
    "include(\"pipeline/Pipeline.jl\"); @time Pipeline.flag($1, \"$input\")"

