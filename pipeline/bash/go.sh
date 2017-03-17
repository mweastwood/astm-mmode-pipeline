#!/bin/bash

set -eux
cd `dirname $0`

function title {
    set +x
    len=`expr length $1`
    echo
    echo $1
    printf '%*s\n' $len | tr ' ' "="
    set -x
}

spws="18"
#spws="4 6 8 10 12 14 16 18"

for spw in $spws
do
    [ $1 -le 0 ] && [ $2 -ge 0 ] && title getdata && \
        ./00-getdata.sh $spw rainy

    [ $1 -le 1 ] && [ $2 -ge 1 ] && title flag && \
        ./01-flag.sh $spw raw-rainy-visibilities

    [ $1 -le 2 ] && [ $2 -ge 2 ] && title smooth && \
        ./02-smooth.sh $spw flagged-raw-rainy-visibilities

    [ $1 -le 3 ] && [ $2 -ge 3 ] && title calibrate && \
        ./03-calibrate.sh $spw smoothed-rainy-visibilities

    [ $1 -le 4 ] && [ $2 -ge 4 ] && title fitrfi && \
        ./04-fitrfi.sh $spw calibrated-rainy-visibilities

    [ $1 -le 5 ] && [ $2 -ge 5 ] && title subrfi && \
        ./05-subrfi.sh $spw calibrated-rainy-visibilities

    [ $1 -le 6 ] && [ $2 -ge 6 ] && title peel && \
        ./06-peel.sh $spw rfi-subtracted-calibrated-rainy-visibilities

    [ $1 -le 7 ] && [ $2 -ge 7 ] && title fold && \
        ./07-fold.sh $spw peeled-rainy-visibilities

    [ $1 -le 8 ] && [ $2 -ge 8 ] && title getmmodes && \
        ./08-getmmodes.sh $spw folded-peeled-rainy-visibilities

    [ $1 -le 9 ] && [ $2 -ge 9 ] && title getalm && \
        ./09-getalm.sh $spw mmodes-peeled-rainy

    [ $1 -le 10 ] && [ $2 -ge 10 ] && title makemap && \
        ./10-makemap.sh $spw alm-peeled-rainy
done

