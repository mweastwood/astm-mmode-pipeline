#!/bin/bash
cd `dirname $0`
julia -e "using Pipeline; Pipeline.integrate($1, input=\"$2\", output=\"$3\")"

