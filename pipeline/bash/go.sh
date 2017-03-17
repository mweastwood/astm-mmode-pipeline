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

[ $1 -le 0 ] && [ $2 -ge 0 ] && title getdata && \
    ./00-getdata.sh 18 rainy

[ $1 -le 1 ] && [ $2 -ge 1 ] && title flag && \
    ./01-flag.sh 18 raw-rainy-visibilities

[ $1 -le 2 ] && [ $2 -ge 2 ] && title smooth && \
    ./02-smooth.sh 18 flagged-raw-rainy-visibilities

[ $1 -le 3 ] && [ $2 -ge 3 ] && title calibrate && \
    ./03-calibrate.sh 18 smoothed-rainy-visibilities

[ $1 -le 4 ] && [ $2 -ge 4 ] && title fitrfi && \
    ./04-fitrfi.sh 18 calibrated-rainy-visibilities

[ $1 -le 5 ] && [ $2 -ge 5 ] && title subrfi && \
    ./05-subrfi.sh 18 calibrated-rainy-visibilities

[ $1 -le 6 ] && [ $2 -ge 6 ] && title peel && \
    ./06-peel.sh 18 rfi-subtracted-calibrated-rainy-visibilities

[ $1 -le 7 ] && [ $2 -ge 7 ] && title fold && \
    ./07-fold.sh 18 peeled-rainy-visibilities

[ $1 -le 8 ] && [ $2 -ge 8 ] && title getmmodes && \
    ./08-getmmodes.sh 18 folded-peeled-rainy-visibilities

[ $1 -le 9 ] && [ $2 -ge 9 ] && title getalm && \
    ./09-getalm.sh 18 mmodes-peeled-rainy

[ $1 -le 10 ] && [ $2 -ge 10 ] && title makemap && \
    ./10-makemap.sh 18 alm-peeled-rainy

