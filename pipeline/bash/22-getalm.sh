#!/bin/bash

set -eux

JULIA=julia-0.5.0
MACHINEFILE_ONE=../workspace/machine-files/one-process-each.machinefile

cd `dirname $0`/../..
cd pipeline
input="mmodes-peeled-$2"
$JULIA --machinefile $MACHINEFILE_ONE -e \
    "reload(\"Pipeline\"); @time Pipeline.getalm($1, \"$input\")"

