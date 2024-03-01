module ReverseGeocode

using ZipFile,
    CSV,
    NearestNeighbors,
    Logging,
    DataFrames

export Geocoder, decode

include("geocoder.jl")

end