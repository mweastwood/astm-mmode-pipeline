#!/bin/bash

set -eu
cd `dirname $0`/..

JULIA=julia-0.5.0
MACHINEFILE_ONE=../workspace/machine-files/one-process-each.machinefile
MACHINEFILE_MAX=../workspace/machine-files/max-processes-each.machinefile

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

function getdata {
    title getdata
    local spw=$1
    local dataset=`quote $2`
    echo "spw=$1, dataset=$2"
    $JULIA --machinefile $MACHINEFILE_MAX -e \
        "using Pipeline; @time Pipeline.Calibration.getdata($spw, $dataset)"
}

function flag {
    title flag
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -e "using Pipeline; @time Pipeline.Calibration.flag($spw, $dataset, $target)"
}

function smooth {
    title smooth
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -e "using Pipeline; @time Pipeline.Calibration.sawtooth($spw, $dataset, $target)"
}

function calibrate {
    title calibrate
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -e "using Pipeline; @time Pipeline.Calibration.calibrate($spw, $dataset, $target)"
}

function fitrfi {
    title fitrfi
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -e "using Pipeline; @time Pipeline.Calibration.fitrfi($spw, $dataset, $target)"
}

function subrfi {
    title subrfi
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -p 8 -e "using Pipeline; @time Pipeline.Calibration.subrfi($spw, $dataset, $target)"
}

function peel {
    title peel
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA --machinefile $MACHINEFILE_MAX -e \
        "using Pipeline; @time Pipeline.Calibration.peel($spw, $dataset, $target)"
}

function smeared {
    title smeared
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -e "using Interactive; @time Interactive.smeared_image_everything($spw, $dataset, $target)"
}

function addrfi {
    title addrfi
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    local rfi_target=`quote $4`
    echo "spw=$spw, dataset=$dataset"
    echo "target=$target"
    echo "rfi_target=$rfi_target"
    $JULIA -e "using Pipeline; @time Pipeline.Calibration.addrfi($spw, $dataset, $target, $rfi_target)"
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

function wiener {
    title wiener
    local spw=$1
    local dataset=`quote $2`
    local rfi_restored_target=`quote $3`
    local rfi_subtracted_target=`quote $4`
    echo "spw=$spw, dataset=$dataset"
    echo "rfi_restored_target=$rfi_restored_target"
    echo "rfi_subtracted_target=$rfi_subtracted_target"
    $JULIA -e "using Pipeline; @time Pipeline.MModes.wiener($spw, $dataset, $rfi_restored_target, $rfi_subtracted_target)"
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
        [ $1 -le 00 ] && [ $2 -ge 00 ] && getdata   $spw $dataset
        [ $1 -le 01 ] && [ $2 -ge 01 ] && flag      $spw $dataset "raw"
        [ $1 -le 02 ] && [ $2 -ge 02 ] && smooth    $spw $dataset "flagged-raw"
        [ $1 -le 03 ] && [ $2 -ge 03 ] && calibrate $spw $dataset "smoothed-flagged-raw"

        [ $1 -le 10 ] && [ $2 -ge 10 ] && fitrfi    $spw $dataset "calibrated"
        [ $1 -le 11 ] && [ $2 -ge 11 ] && subrfi    $spw $dataset "calibrated"
        [ $1 -le 12 ] && [ $2 -ge 12 ] && peel      $spw $dataset "rfi-subtracted-calibrated"
        [ $1 -le 13 ] && [ $2 -ge 13 ] && smeared   $spw $dataset "peeled"
        [ $1 -le 14 ] && [ $2 -ge 14 ] && addrfi    $spw $dataset "peeled" "rfi-subtracted-calibrated"
        [ $1 -le 15 ] && [ $2 -ge 15 ] && fitrfi    $spw $dataset "rfi-restored-peeled"
        [ $1 -le 16 ] && [ $2 -ge 16 ] && subrfi    $spw $dataset "rfi-restored-peeled"
        [ $1 -le 17 ] && [ $2 -ge 17 ] && smeared   $spw $dataset "rfi-subtracted-peeled"

        [ $1 -le 20 ] && [ $2 -ge 20 ] && fold      $spw $dataset "rfi-restored-peeled"
        [ $1 -le 21 ] && [ $2 -ge 21 ] && fold      $spw $dataset "rfi-subtracted-peeled"
        [ $1 -le 22 ] && [ $2 -ge 22 ] && getmmodes $spw $dataset "folded-rfi-restored-peeled"
        [ $1 -le 23 ] && [ $2 -ge 23 ] && getmmodes $spw $dataset "folded-rfi-subtracted-peeled"
        [ $1 -le 24 ] && [ $2 -ge 24 ] && getalm    $spw $dataset "mmodes-rfi-restored-peeled"
        [ $1 -le 25 ] && [ $2 -ge 25 ] && getalm    $spw $dataset "mmodes-rfi-subtracted-peeled"
        [ $1 -le 26 ] && [ $2 -ge 26 ] && wiener    $spw $dataset "alm-rfi-restored-peeled" "alm-rfi-subtracted-peeled"

        [ $1 -le 30 ] && [ $2 -ge 30 ] && makemap   $spw $dataset "alm-rfi-restored-peeled"
        [ $1 -le 31 ] && [ $2 -ge 31 ] && makemap   $spw $dataset "alm-rfi-subtracted-peeled"
        [ $1 -le 32 ] && [ $2 -ge 32 ] && makemap   $spw $dataset "alm-wiener-filtered"
    done
done

