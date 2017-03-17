#!/bin/bash

set -eux

./00-getdata.sh 18 rainy
./01-flag.sh 18 raw-rainy-visibilities

