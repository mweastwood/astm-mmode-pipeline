#!/bin/bash
cd `dirname $0`
julia -p 16 -e "using Pipeline; Pipeline.makemovie($1)"

