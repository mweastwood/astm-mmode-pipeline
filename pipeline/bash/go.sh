#!/bin/bash

set -eu
cd `dirname $0`/..

JULIA=julia-0.5.0
MACHINEFILE_ONE=../workspace/machine-files/one-process-each.machinefile

#spws="4 6 8 10 12 14 16 18"
#datasets="100hr rainy"

spws=$3
datasets=$4

function title {
    len=`expr length $1`
    echo
    echo $1
    printf '%*s\n' $len | tr ' ' "="
    date
}

function quote {
    echo "\"$1\""
}

function print_parameters {
    echo "spw=$1, dataset=$2, target=$3"
}

function addrfi {
    title addrfi
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    local rfi=`quote $4`
    print_parameters $spw $dataset $target
    $JULIA -e "using Pipeline; @time Pipeline.Calibration.addrfi($spw, $dataset, $target, $rfi)"
}

function fold {
    title fold
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -e "using Pipeline; @time Pipeline.MModes.fold($spw, $dataset, $target)"
}

function getmmodes {
    title getmmodes
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -e "using Pipeline; @time Pipeline.MModes.getmmodes($spw, $dataset, $target)"
}

function getalm {
    title getalm
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA --machinefile $MACHINEFILE_ONE -e \
        "using Pipeline; @time Pipeline.MModes.getalm($spw, $dataset, $target)"
}

function makemap {
    title makemap
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -e "using Pipeline; @time Pipeline.MModes.makemap($spw, $dataset, $target)"
}

for dataset in $datasets
do
    for spw in $spws
    do
        #[ $1 -le 0 ] && [ $2 -ge 0 ] && title getdata && ./00-getdata.sh $spw $dataset
        #[ $1 -le 1 ] && [ $2 -ge 1 ] && title flag && ./01-flag.sh $spw $dataset
        #[ $1 -le 2 ] && [ $2 -ge 2 ] && title smooth && ./02-smooth.sh $spw $dataset
        #[ $1 -le 3 ] && [ $2 -ge 3 ] && title calibrate && ./03-calibrate.sh $spw $dataset

        #[ $1 -le 10 ] && [ $2 -ge 10 ] && title fitrfi && ./10-fitrfi.sh $spw $dataset
        #[ $1 -le 11 ] && [ $2 -ge 11 ] && title subrfi && ./11-subrfi.sh $spw $dataset
        #[ $1 -le 12 ] && [ $2 -ge 12 ] && title peel && ./12-peel.sh $spw $dataset
        [ $1 -le 13 ] && [ $2 -ge 13 ] && addrfi    $spw $dataset "peeled" "rfi-subtracted-calibrated"

        [ $1 -le 20 ] && [ $2 -ge 20 ] && fold      $spw $dataset "rfi-restored-peeled"
        [ $1 -le 21 ] && [ $2 -ge 21 ] && getmmodes $spw $dataset "folded-rfi-restored-peeled"
        [ $1 -le 22 ] && [ $2 -ge 22 ] && getalm    $spw $dataset "mmodes-rfi-restored-peeled"
        [ $1 -le 23 ] && [ $2 -ge 23 ] && makemap   $spw $dataset "alm-rfi-restored-peeled"
    done
done

