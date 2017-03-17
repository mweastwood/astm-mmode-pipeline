#!/bin/bash

set -eux

[ $1 -le 0 ] && ./00-getdata.sh 18 rainy
[ $1 -le 1 ] && ./01-flag.sh 18 raw-rainy-visibilities
[ $1 -le 2 ] && ./02-smooth.sh 18 flagged-raw-rainy-visibilities
[ $1 -le 3 ] && ./03-calibrate.sh 18 smoothed-rainy-visibilities

