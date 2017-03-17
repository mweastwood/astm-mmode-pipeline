#!/bin/bash

set -eux

JULIA=julia-0.5.0

cd `dirname $0`/../..
cd pipeline
$JULIA -p 8 -e \
    "reload(\"Pipeline\"); @time Pipeline.subrfi($1, \"$2\")"

