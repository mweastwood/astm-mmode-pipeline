#!/bin/bash

# create all the directories needed by the pipeline

set -eu
cd `dirname $0`/..

JULIA=julia-0.5.0
MACHINEFILE=workspace/machine-files/one-process-each.machinefile

$JULIA --machinefile $MACHINEFILE -e 'isdir("/dev/shm/mweastwood") || mkdir("/dev/shm/mweastwood")'
$JULIA -e 'isdir("workspace") || mkdir("workspace")'
$JULIA -e 'isdir("workspace/source-lists") || mkdir("workspace/source-lists")'
$JULIA -e 'isdir("logs") || mkdir("logs")'


