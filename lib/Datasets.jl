"Define some helper functions for converting between arrays and TTCal Datasets."
module Datasets

using TTCal

function array_to_ttcal(array, metadata, time, T=TTCal.Dual)
    metadata = deepcopy(metadata)
    TTCal.slice!(metadata, time, axis=:time)
    ttcal_dataset = TTCal.Dataset(metadata, polarization=T)
    for frequency in 1:Nfreq(metadata)
        visibilities = ttcal_dataset[frequency, 1]
        α = 1
        for antenna1 = 1:Nant(metadata), antenna2 = antenna1:Nant(metadata)
            J = pack_jones_matrix(array, frequency, α, T)
            if J != zero(typeof(J))
                visibilities[antenna1, antenna2] = J
            end
            α += 1
        end
    end
    ttcal_dataset
end

function pack_jones_matrix(array, frequency, α, ::Type{TTCal.Dual})
    TTCal.DiagonalJonesMatrix(array[1, frequency, α], array[2, frequency, α])
end
function pack_jones_matrix(array, frequency, α, ::Type{TTCal.XX})
    array[1, frequency, α]
end
function pack_jones_matrix(array, frequency, α, ::Type{TTCal.YY})
    array[2, frequency, α]
end

function ttcal_to_array(ttcal_dataset)
    data = zeros(Complex128, 2, Nfreq(ttcal_dataset), Nbase(ttcal_dataset))
    for frequency in 1:Nfreq(ttcal_dataset)
        visibilities = ttcal_dataset[frequency, 1]
        α = 1
        for antenna1 = 1:Nant(ttcal_dataset), antenna2 = antenna1:Nant(ttcal_dataset)
            J = visibilities[antenna1, antenna2]
            unpack_jones_matrix!(data, frequency, α, J, TTCal.polarization(ttcal_dataset))
            α += 1
        end
    end
    data
end

function unpack_jones_matrix!(data, frequency, α, J, ::Type{TTCal.Dual})
    data[1, frequency, α] = J.xx
    data[2, frequency, α] = J.yy
end
function unpack_jones_matrix!(data, frequency, α, J, ::Type{TTCal.XX})
    data[1, frequency, α] = J
end
function unpack_jones_matrix!(data, frequency, α, J, ::Type{TTCal.YY})
    data[2, frequency, α] = J
end

end

