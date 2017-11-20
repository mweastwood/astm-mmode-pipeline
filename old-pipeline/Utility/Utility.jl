"""
    module Utility

This module includes interfaces for working with external tools such as `dada2ms` and `wsclean`.
"""
module Utility

export dada2ms, wsclean

using CasaCore.Tables

include("dada2ms.jl")
include("wsclean.jl")

end

