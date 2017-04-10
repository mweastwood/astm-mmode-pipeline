#!/bin/bash

set -eux

JULIA=julia-0.5.0

cd `dirname $0`/../..
cd pipeline
input="peeled-$2-visibilities"
$JULIA -e \
    "reload(\"Pipeline\"); @time Pipeline.smeared_image_everything($1, \"$input\")"

