#!/bin/bash

set -eu
cd `dirname $0`

JULIA=julia-0.5.0
MACHINEFILE_ONE=../workspace/machine-files/one-process-each.machinefile
MACHINEFILE_MAX=../workspace/machine-files/max-processes-each.machinefile

#spws="4 6 8 10 12 14 16 18"
#datasets="100hr rainy"

lower=$1
upper=$2
spws=$3
datasets=$4
current_number=""

function isbetween {
    current_number=$1
    [ $lower -le $current_number ] && [ $upper -ge $current_number ]
}

function title {
    mytitle="$current_number-$1"
    len=`expr length $mytitle`
    echo
    echo $mytitle
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

function observe {
    title observe
    local spw=$1
    local dataset=`quote $2`
    local mmodes_target=`quote $3`
    local alm_target=`quote $4`
    echo "spw=$spw, dataset=$dataset"
    echo "mmodes_target=$mmodes_target"
    echo "alm_target=$alm_target"
    $JULIA --machinefile $MACHINEFILE_ONE -e \
        "using Pipeline; @time Pipeline.MModes.observation_matrix($spw, $dataset, $mmodes_target, $alm_target)"
}

function peakpsf {
    title peakpsf
    local spw=$1
    local dataset=`quote $2`
    echo "spw=$spw, dataset=$dataset"
    $JULIA -e "using Pipeline; @time Pipeline.Cleaning.getpsf_peak($spw, $dataset)"
}

function restore {
    title restore
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    local src=`quote "$4"`
    print_parameters $spw $dataset $target
    echo "source=$src"
    $JULIA -e "using Pipeline; Pipeline.Calibration.removed_source_visibilities($spw, $dataset, $target, $src)"
}

for dataset in $datasets
do
    for spw in $spws
    do
        isbetween 00 && getdata   $spw $dataset
        isbetween 01 && flag      $spw $dataset "raw"
        isbetween 02 && smooth    $spw $dataset "flagged-raw"
        isbetween 03 && calibrate $spw $dataset "smoothed-flagged-raw"

        isbetween 10 && fitrfi    $spw $dataset "calibrated"
        isbetween 11 && subrfi    $spw $dataset "calibrated"
        isbetween 12 && peel      $spw $dataset "rfi-subtracted-calibrated"
        isbetween 13 && smeared   $spw $dataset "peeled"
        isbetween 14 && addrfi    $spw $dataset "peeled" "rfi-subtracted-calibrated"
        isbetween 15 && fitrfi    $spw $dataset "rfi-restored-peeled"
        isbetween 16 && subrfi    $spw $dataset "rfi-restored-peeled"
        isbetween 17 && smeared   $spw $dataset "rfi-subtracted-peeled"

        isbetween 20 && fold      $spw $dataset "rfi-restored-peeled"
        isbetween 21 && fold      $spw $dataset "rfi-subtracted-peeled"
        isbetween 22 && getmmodes $spw $dataset "folded-rfi-restored-peeled"
        isbetween 23 && getmmodes $spw $dataset "folded-rfi-subtracted-peeled"
        isbetween 24 && getalm    $spw $dataset "mmodes-rfi-restored-peeled"
        isbetween 25 && getalm    $spw $dataset "mmodes-rfi-subtracted-peeled"
        isbetween 26 && wiener    $spw $dataset "alm-rfi-restored-peeled" "alm-rfi-subtracted-peeled"

        isbetween 30 && makemap   $spw $dataset "alm-rfi-restored-peeled"
        isbetween 31 && makemap   $spw $dataset "alm-rfi-subtracted-peeled"
        isbetween 32 && makemap   $spw $dataset "alm-wiener-filtered"

        isbetween 40 && observe   $spw $dataset "mmodes-rfi-subtracted-peeled" "alm-wiener-filtered"
        isbetween 41 && peakpsf   $spw $dataset

        isbetween 50 && restore   $spw $dataset "peeled" 'Cyg A'
        isbetween 51 && fold      $spw $dataset "cyga-peeled"
        isbetween 52 && getmmodes $spw $dataset "folded-cyga-peeled"
        isbetween 53 && getalm    $spw $dataset "mmodes-cyga-peeled"
        isbetween 54 && makemap   $spw $dataset "alm-cyga-peeled"

        isbetween 60 && restore   $spw $dataset "peeled" 'Hya A'
        isbetween 61 && fold      $spw $dataset "hyaa-peeled"
        isbetween 62 && getmmodes $spw $dataset "folded-hyaa-peeled"
        isbetween 63 && getalm    $spw $dataset "mmodes-hyaa-peeled"
        isbetween 64 && makemap   $spw $dataset "alm-hyaa-peeled"

        isbetween 70 && restore   $spw $dataset "peeled" 'Per B'
        isbetween 71 && fold      $spw $dataset "perb-peeled"
        isbetween 72 && getmmodes $spw $dataset "folded-perb-peeled"
        isbetween 73 && getalm    $spw $dataset "mmodes-perb-peeled"
        isbetween 74 && makemap   $spw $dataset "alm-perb-peeled"

        isbetween 80 && restore   $spw $dataset "peeled" '3C 353'
        isbetween 81 && fold      $spw $dataset "3c353-peeled"
        isbetween 82 && getmmodes $spw $dataset "folded-3c353-peeled"
        isbetween 83 && getalm    $spw $dataset "mmodes-3c353-peeled"
        isbetween 84 && makemap   $spw $dataset "alm-3c353-peeled"
    done
done

