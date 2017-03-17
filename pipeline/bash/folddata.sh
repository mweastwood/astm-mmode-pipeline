#!/bin/bash
cd `dirname $0`
julia -e "using Pipeline; Pipeline.folddata($1, input=\"$2\", output=\"$3\")"

