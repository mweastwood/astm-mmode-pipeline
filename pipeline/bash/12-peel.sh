#!/bin/bash

set -eux

JULIA=julia-0.5.0
MACHINEFILE_MAX=../workspace/machine-files/max-processes-each.machinefile

cd `dirname $0`/../..
cd pipeline
$JULIA --machinefile $MACHINEFILE_MAX -e \
    "reload(\"Pipeline\"); @time Pipeline.Calibration.peel($1, \"$2\", \"rfi-subtracted-calibrated\")"
$JULIA -e \
    "reload(\"Interactive\"); @time Interactive.smeared_image_everything($1, \"$2\", \"peeled\")"

