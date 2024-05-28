# ReverseGeocode

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://BoZenKhaa.github.io/ReverseGeocode.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://BoZenKhaa.github.io/ReverseGeocode.jl/dev/)
[![Build Status](https://github.com/BoZenKhaa/ReverseGeocode.jl/workflows/CI/badge.svg)](https://github.com/BoZenKhaa/ReverseGeocode.jl/actions)
[![Coverage](https://codecov.io/gh/BoZenKhaa/ReverseGeocode.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/BoZenKhaa/ReverseGeocode.jl)


ReverseGeocode is a tool for quick offline reverse geocoding in Julia.

The tool returns city and country closest to provided latitude/longitude coordinate (WGS84).

## Installation
In REPL, simply run 
```julia
import Pkg; Pkg.add("ReverseGeocode")
```
to install the package. 

The reference dataset is download on the first use. To download the data, simply run
```julia
julia> using ReverseGeocode
julia> Geocoder();
[ Info: Reference dataset sucessfuly saved in ./data.]
```

## Usage example:
The `decode` function works with either single lat/lon point or with an array of points or a Matrix. Lat/lon are assumed to be decimal degrees (WGS84).
```julia
using ReverseGeocode, StaticArrays 

gc = Geocoder()

# single coordinate
decode(gc, SA[51.45,0.00])
#(country = "United Kingdom", country_code = "GB", city = "Lee")

# multiple coordinates
decode(gc, [[34.2,100.00] [50.01,16.35]])
#2-element Array{NamedTuple{(:country, :country_code, :city),Tuple{String,String,String}},1}:
# (country = "China", country_code = "CN", city = "Kequ")
# (country = "Czechia", country_code = "CZ", city = "Ústí nad Orlicí")
```
Note that due to the requirements of the NearestNeighbors library, the dimension of points needs to be set at type level, so use of either StaticArrays or Matrices for input data is recommended. 

### Decode Output Customization

The user can also explicitly specify the decode output as well. The cities data contains other additional headers (e.g., `population`, `admin1`, `modification_date`) that can be included into the output.

For example, if the user wants population data from the GeoNames cities table: 

```julia
gc = Geocoder(; select = [:country, :country_code, :name,  :population])

# single coordinate
decode(gc, SA[51.45,0.00])
#(country = "United Kingdom", country_code = "GB", city = "Lee", population = 14573)
```

For a full list of headers, access `ReverseGeocode.DEFAUL_DOWNLOAD_SELECT`.

More advanced customization can be achieved by passing a `DataFrame` with other user custom headers into the constructor: 

Example 1
```julia
# Example to add a test column to the data
df = ReverseGeocode.read_data()
df.test_col = fill(10, nrow(df))

gc = Geocoder(df)

decode(gc, SA[51.45,0.00])
# (country = "United Kingdom", country_code = "GB", city = "Lee", test_col = 10)
```

Example 2 : add continent codes into the constructor:

```julia

continent_codes = Dict{String, String}(
    CSV.File(
        joinpath(dirname(dirname(pathof(ReverseGeocode))),"data", "continent_codes.csv"); 
        delim  = '\t', header = false,
        types = [String, String]
    )
)

df = ReverseGeocode.read_data()
country_ISO = Array(df.country_code)
df.continent = getindex.(Ref(continent_codes), country_ISO)

gc = Geocoder(df)

decode(gc, [[34.2,100.00] [50.01,16.35]])
# 2-element Vector{NamedTuple}:
# (country = "China", country_code = "CN", city = "Kequ", continent = "AS")
# (country = "Czechia", country_code = "CZ", city = "Ústí nad Orlicí", continent = "EU")
```


## Description

The package works by searching for the nearest neighbor in the downloaded list of known locations from [geonames.org](http://download.geonames.org/export/dump). 

As such, it is extremely fast compared to online APIs. This makes it useful for quickly annotating large numbers of points. Additionally, as the labelling runs locally, it can not exhaust limits of free web APIs.

## Limitations

Since the reverse geocoding is performed simply by finding the nearest labelled point, the labelling may not return accurate annotations for some points (e.g. points close to borders of two cities or countries may be mislabelled). 

## Future plans
See the [docs](https://bozenkhaa.github.io/ReverseGeocode.jl/dev/).

## Acknowledgmenets
 - Inspired by the python package [reverse_geocode](https://github.com/richardpenman/reverse_geocode)
 - Data from [geonames.org](http://download.geonames.org/export/dump) under [Creative Commons Attribution 4.0 License](https://creativecommons.org/licenses/by/4.0/)
