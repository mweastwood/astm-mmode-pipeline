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

spws=$3
#spws="4 6 8 10 12 14 16 18"

datasets=$4
#datasets="100hr rainy"

for data in $datasets
do
    for spw in $spws
    do
        [ $1 -le 0 ] && [ $2 -ge 0 ] && title getdata && ./00-getdata.sh $spw $data
        [ $1 -le 1 ] && [ $2 -ge 1 ] && title flag && ./01-flag.sh $spw $data
        [ $1 -le 2 ] && [ $2 -ge 2 ] && title smooth && ./02-smooth.sh $spw $data
        [ $1 -le 3 ] && [ $2 -ge 3 ] && title calibrate && ./03-calibrate.sh $spw $data

        [ $1 -le 10 ] && [ $2 -ge 10 ] && title fitrfi && ./10-fitrfi.sh $spw $data
        [ $1 -le 11 ] && [ $2 -ge 11 ] && title subrfi && ./11-subrfi.sh $spw $data
        [ $1 -le 12 ] && [ $2 -ge 12 ] && title fitrfi-special && ./12-fitrfi-special.sh $spw $data
        [ $1 -le 13 ] && [ $2 -ge 13 ] && title subrfi-special && ./13-subrfi-special.sh $spw $data
        [ $1 -le 14 ] && [ $2 -ge 14 ] && title peel && ./14-peel.sh $spw $data

        [ $1 -le 20 ] && [ $2 -ge 20 ] && title fold && ./20-fold.sh $spw $data
        [ $1 -le 21 ] && [ $2 -ge 21 ] && title getmmodes && ./21-getmmodes.sh $spw $data
        [ $1 -le 22 ] && [ $2 -ge 22 ] && title getalm && ./22-getalm.sh $spw $data
        [ $1 -le 23 ] && [ $2 -ge 23 ] && title makemap && ./23-makemap.sh $spw $data
    done
done

