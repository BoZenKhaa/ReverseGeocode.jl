```@meta
CurrentModule = ReverseGeocode
```

# ReverseGeocode

Julia package for fast offline reverse geocoding. 

## Table of contents
```@contents
Depth=2
```

The tool returns city and country closest to provided latitude/longitude coordinate (WGS84).

## Installation
In REPL, simply run 
```julia
import Pkg; Pkg.add("ReverseGeocode")
```
to install the package. 

The reference dataset is download on the first use. To download the data, simply run
```julia
using ReverseGeocode
Geocoder()
```

## Usage example:
The `decode` function works with either single lat/lon point or with an array of points or a Matrix. Lat/lon are assumed to be decimal degrees (WGS84).
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

The package works by searching for the nearest neighbor in the downloaded list of known locations from [geonames.org](http://download.geonames.org/export/dump). 

As such, it is extremely fast compared to online APIs. This makes it useful for quickly annotating large numbers of points. Additionally, as the labelling runs locally, it can not exhaust limits of free web APIs.

## Limitations

Since the reverse geocoding is performed simply by finding the nearest labelled point, the labelling may not return accurate annotations for some points (e.g. points close to borders of two cities or countries may be mislabelled). 

## Acknowledgmenets
 - Inspired by the python package [reverse_geocode](https://github.com/richardpenman/reverse_geocode)
 - Data from [geonames.org](http://download.geonames.org/export/dump) under [Creative Commons Attribution 4.0 License](https://creativecommons.org/licenses/by/4.0/)

