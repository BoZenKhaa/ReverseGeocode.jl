module ReverseGeocode

using ZipFile
using CSV
using NearestNeighbors
using Logging

export Geocoder, decode

include("geocoder.jl")

end