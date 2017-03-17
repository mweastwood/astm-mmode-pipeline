#!/bin/bash
cd `dirname $0`
julia -e "using Pipeline; Pipeline.fitbeam($1)"

