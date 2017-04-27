#!/bin/bash

# delete all files in /dev/shm/mweastwood

set -eu
cd `dirname $0`

JULIA=julia-0.5.0
MACHINEFILE=../workspace/machine-files/one-process-each.machinefile
PROGRAM='
    dir = "/dev/shm/mweastwood"
    if myid() != 1 && isdir(dir)
        files = readdir(dir)
        if length(files) > 0
            for file in files
                rm(joinpath(dir, file), recursive=true)
            end
        end
    end
'

$JULIA --machinefile $MACHINEFILE -e "$PROGRAM"

