module ReverseGeocode

using ZipFile,
    CSV,
    NearestNeighbors,
    Logging,
    DataFrames,
    DataStructures,
    Downloads

export Geocoder, decode

include("geocoder.jl")

end