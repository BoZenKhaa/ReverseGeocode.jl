module ReverseGeocode

using ZipFile,
    CSV,
    NearestNeighbors,
    Logging,
    DataFrames,
    DataStructures

export Geocoder, decode

include("geocoder.jl")

end