#!/bin/bash

set -eux

JULIA=julia-0.5.0

cd `dirname $0`/../..
input="alm-cleaned-$2"
$JULIA -e \
    "include(\"pipeline/Pipeline.jl\"); @time Pipeline.makemap($1, \"$input\")"

