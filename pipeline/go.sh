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

function getmmodes-odd {
    title getmmodes-odd
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -e "using Pipeline; @time Pipeline.MModes.getmmodes_odd($spw, $dataset, $target)"
}

function getmmodes-even {
    title getmmodes-even
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -e "using Pipeline; @time Pipeline.MModes.getmmodes_even($spw, $dataset, $target)"
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

function interpol {
    title interpol
    local spw=$1
    local dataset=`quote $2`
    local visibilities_target=`quote $3`
    local alm_target=`quote $4`
    echo "spw=$spw, dataset=$dataset"
    echo "visibilities_target=$visibilities_target"
    echo "alm_target=$alm_target"
    $JULIA --machinefile $MACHINEFILE_ONE -e \
        "using Pipeline; @time Pipeline.MModes.interpolate($spw, $dataset, $visibilities_target, $alm_target)"
}

function wiener {
    title wiener
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -e "using Pipeline; @time Pipeline.MModes.wiener($spw, $dataset, $target)"
}

function makemap {
    title makemap
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -e "using Pipeline; @time Pipeline.MModes.makemap($spw, $dataset, $target, 512)"
    $JULIA -e "using Pipeline; @time Pipeline.MModes.makemap($spw, $dataset, $target, 2048)"
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

function getpsf {
    title getpsf
    local spw=$1
    local dataset=`quote $2`
    echo "spw=$spw, dataset=$dataset"
    $JULIA --machinefile $MACHINEFILE_ONE -e \
        "using Pipeline; @time Pipeline.Cleaning.getpsf($spw, $dataset)"
}

function getpsf_w {
    title getpsf_w
    local spw=$1
    echo "spw=$spw"
    $JULIA -p 8 -e "using Pipeline; @time Pipeline.Cleaning.getpsf_width($spw)"
}

function register {
    title register
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -p 16 -e "using Pipeline; @time Pipeline.Cleaning.register($spw, $dataset, $target)"
}

function clean {
    title clean
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -p 8 -e "using Pipeline; @time Pipeline.Cleaning.clean($spw, $dataset, $target)"
}

function restore {
    title restore
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -e "using Pipeline; @time Pipeline.Cleaning.restore($spw, $dataset, $target)"
}

function glamour {
    title glamour
    local spw=$1
    local dataset=`quote $2`
    local target=`quote $3`
    print_parameters $spw $dataset $target
    $JULIA -e "using Pipeline; @time Pipeline.MModes.glamour($spw, $dataset, $target)"
}

for dataset in $datasets
do
    for spw in $spws
    do
        # Calibration
        isbetween 00 && getdata   $spw $dataset
        isbetween 01 && flag      $spw $dataset "raw"
        isbetween 02 && smooth    $spw $dataset "flagged-raw"
        isbetween 03 && calibrate $spw $dataset "smoothed-flagged-raw"
        isbetween 04 && smeared   $spw $dataset "calibrated"

        # Source Removal
        isbetween 10 && fitrfi    $spw $dataset "calibrated"
        isbetween 11 && subrfi    $spw $dataset "calibrated"
        isbetween 12 && peel      $spw $dataset "rfi-subtracted-calibrated"
        isbetween 13 && smeared   $spw $dataset "peeled"
        isbetween 14 && addrfi    $spw $dataset "peeled" "rfi-subtracted-calibrated"
        isbetween 15 && fitrfi    $spw $dataset "rfi-restored-peeled"
        isbetween 16 && subrfi    $spw $dataset "rfi-restored-peeled"
        isbetween 17 && smeared   $spw $dataset "rfi-subtracted-peeled"

        # m-Mode Analysis
        isbetween 20 && fold      $spw $dataset "rfi-subtracted-peeled"
        isbetween 21 && getmmodes $spw $dataset "folded-rfi-subtracted-peeled"
        isbetween 22 && getalm    $spw $dataset "mmodes-rfi-subtracted-peeled"
        isbetween 23 && interpol  $spw $dataset "folded-rfi-subtracted-peeled" "alm-rfi-subtracted-peeled"
        isbetween 24 && wiener    $spw $dataset "alm-interpolated"
        isbetween 25 && makemap   $spw $dataset "alm-rfi-subtracted-peeled"
        isbetween 26 && makemap   $spw $dataset "alm-interpolated"
        isbetween 27 && makemap   $spw $dataset "alm-wiener-filtered"

        # Cleaning
        isbetween 30 && observe   $spw $dataset "mmodes-rfi-subtracted-peeled" "alm-wiener-filtered"
        isbetween 31 && getpsf    $spw $dataset
        isbetween 32 && getpsf_w  $spw
        isbetween 33 && clean     $spw $dataset "alm-wiener-filtered"
        isbetween 34 && restore   $spw $dataset "alm-wiener-filtered"
        isbetween 35 && register  $spw $dataset "map-restored"
        isbetween 36 && glamour   $spw $dataset "map-restored-registered"

        # Jackknife
        isbetween 50 && getmmodes-odd  $spw $dataset "rfi-subtracted-peeled-interpolated"
        isbetween 51 && getmmodes-even $spw $dataset "rfi-subtracted-peeled-interpolated"
        isbetween 52 && getalm    $spw $dataset "mmodes-odd-rfi-subtracted-peeled-interpolated"
        isbetween 53 && getalm    $spw $dataset "mmodes-even-rfi-subtracted-peeled-interpolated"
        isbetween 54 && wiener    $spw $dataset "alm-odd-rfi-subtracted-peeled-interpolated"
        isbetween 55 && wiener    $spw $dataset "alm-even-rfi-subtracted-peeled-interpolated"
        isbetween 56 && makemap   $spw $dataset "alm-odd-wiener-filtered"
        isbetween 57 && makemap   $spw $dataset "alm-even-wiener-filtered"

        # Jackknife cleaning
        isbetween 60 && clean     $spw $dataset "alm-odd-wiener-filtered"
        isbetween 61 && clean     $spw $dataset "alm-even-wiener-filtered"
        isbetween 62 && restore   $spw $dataset "alm-odd-wiener-filtered"
        isbetween 63 && restore   $spw $dataset "alm-even-wiener-filtered"
        isbetween 64 && register  $spw $dataset "map-odd-restored"
        isbetween 65 && register  $spw $dataset "map-even-restored"
        isbetween 66 && glamour   $spw $dataset "map-odd-restored-registered"
        isbetween 67 && glamour   $spw $dataset "map-even-restored-registered"
    done
done

