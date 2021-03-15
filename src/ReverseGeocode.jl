module ReverseGeocode

using ZipFile
using CSV
using NearestNeighbors

export Geocoder, decode

include("geocoder.jl")

end