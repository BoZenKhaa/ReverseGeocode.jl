# ReverseGeocode

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://BoZenKhaa.github.io/ReverseGeocode.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://BoZenKhaa.github.io/ReverseGeocode.jl/dev/)
[![Build Status](https://github.com/BoZenKhaa/ReverseGeocode.jl/workflows/CI/badge.svg)](https://github.com/BoZenKhaa/ReverseGeocode.jl/actions)
[![Coverage](https://codecov.io/gh/BoZenKhaa/ReverseGeocode.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/BoZenKhaa/ReverseGeocode.jl)


ReverseGeocode is a tool for quick offline reverse geocoding of coordinates in Julia.

The tool returns city and country closest to a latitude/longitude coordinate (WGS84).

## Installation
In REPL, simply run 
```
import Pkg; Pkg.add("ReverseGeocode")
```
to install the package. 

The reference dataset is download upon first usage. To download the data for offline use, run
```
using ReverseGeocode
Geocoder()
```

## Usage example:
The `decode` function works with either single lat/lon point or with an array of points or a Matrix.
```julia
using ReverseGeocode, StaticArrays 

gc = Geocoder()

# single coordinate
decode(gc, SA[51.45,0.00])
#(country = "United Kingdom", country_code = "GB", city = "Blackheath")

# multiple coordinates
decode(gc, [[34.2,100.00] [50.01,16.35]])
#2-element Array{NamedTuple{(:country, :country_code, :city),Tuple{String,String,String}},1}:
# (country = "China", country_code = "CN", city = "Kequ")
# (country = "Czechia", country_code = "CZ", city = "Ústí nad Orlicí")
```
Note that due to the requirements of the NearestNeighbors library, the dimension of points needs to be set at type level, so use of either StaticArrays or Matrices for input data is recommended. 

## Description

The package works by searching for the nearest neighbor in the list of known locations from [geonames.org](http://download.geonames.org/export/dump). 

As such, it is useful for quickly annotating large numbers of points that would otherwise exhaust free web APIs.

As such, it may not return accurate annotations for some points (e.g. points close to country borders may be mislabelled). 

## Future plans
See the page in [docs](https://bozenkhaa.github.io/ReverseGeocode.jl/dev/future_plans/).

## Acknowledgmenets
 - Inspired by the python package [reverse_geocode](https://github.com/richardpenman/reverse_geocode)
 - Data from [geonames.org](http://download.geonames.org/export/dump) under [Creative Commons Attribution 4.0 License](https://creativecommons.org/licenses/by/4.0/)
