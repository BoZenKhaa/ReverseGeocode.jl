const GEO_FILE = "cities1000"
const GEO_SOURCE = "http://download.geonames.org/export/dump"
const DATA_DIR = "./data"

"""
Column names in the geonames dumpfile (from http://download.geonames.org/export/dump):
"""
const COLUMNS = [:geonameid, :name, :asciiname, :alternatenames, :latitude, :longitude, 
                :feature_class, :feature_code, :country_code, :cc2, :admin1_code, :admin2_code, 
                :admin3_code, :admin4_code, :population, :elevation, :dem, :timezone, :modification_date]
                
"""
    Geocoder(;data_dir="./data", geo_file="cities1000"))

Geocoder structure that holds the reference points and their labels (city name and country code).
"""
struct Geocoder
    tree::NNTree
    info::Array{NamedTuple{(:city, :country_code),Tuple{String, String}}}
    country_codes::Dict{String, String}

    function Geocoder(;data_dir::String=DATA_DIR, geo_file::String=GEO_FILE)
        if ! isfile("$data_dir/$geo_file.csv")
            download_data(;data_dir=data_dir, geo_file=geo_file)
        end
        points, info = read_data(;data_dir=data_dir, geo_file=geo_file)

        tree = KDTree(points)
        country_codes = Dict(CSV.File("$data_dir/country_codes.csv"; delim="\t", header=false))

        new(tree, info, country_codes)
    end
end


"""
    read_data(;data_dir="./data", geo_file="cities1000")

Load coordinates, country codes and city names from the `.csv` saved export of the geonames file.
Make sure to call `download_data()` before `read_data()`.
"""
function read_data(;data_dir::String=DATA_DIR, geo_file::String=GEO_FILE)
    data = CSV.File("$data_dir/$geo_file.csv"; delim="\t", header=true, types=[String, Float64, Float64, String])
    
    n = length(data)
    points = Array{Float64}(undef, 2, n)
    info = Array{NamedTuple{(:city, :country_code),Tuple{String, String}}}(undef, n)
    for (i,row) in enumerate(data)
        points[:,i] .= row.latitude, row.longitude
        info[i] = (city = row.name, country_code = row.country_code)
    end
    points, info
end

"""
    download_data(;data_dir="./data", geo_file="cities1000", header=COLUMNS)

Download dump from [geonames.org](http://download.geonames.org/export/dump/). This function 
fetches a file of cities with a population > 1000 (and seats of administrations of ceratain country subdivisions, 
other options are population 500, 5000, 15000, see geonames.org for details). 
The dump is unpacked and city name, coordinates and country code are saved 
in a `.csv` file for use in the Geocoder. 
"""
function download_data(;data_dir::String=DATA_DIR, geo_file::String=GEO_FILE, header=COLUMNS)
    println(pwd())
    # Download the source file
    download("$GEO_SOURCE/$geo_file.zip", "$data_dir/$geo_file.zip")
    # extract the csv and drop unnecessary columns
    r = ZipFile.Reader("$data_dir/$geo_file.zip")
    data = CSV.File(read(r.files[1]); delim="\t", header=header, select=[:name,:latitude,:longitude,:country_code])
    close(r)
    # save needed data as csv
    CSV.write("$data_dir/$geo_file.csv", data; delim="\t")
    # clean up
    rm("$data_dir/$geo_file.zip")
    
    @info "Download and preprocessing of reference poitns was succesful."
end

"""
Download and resave the country codes csv from geonames. 
Country codes are part of the package so this function does not usually need to run during install. 
"""
function download_country_codes(;data_dir::String=DATA_DIR)
    download("http://download.geonames.org/export/dump/countryInfo.txt", "$data_dir/countryInfo.txt")
    country_info = CSV.File("$data_dir/countryInfo.txt"; delim="\t", header=false, select=[1,5], datarow=51)
    country_codes = Dict([(c.Column1, c.Column5) for c in country_info])
    CSV.write("$data_dir/country_codes.csv", country_codes, delim="\t", header=false)
end

"""
    decode(gc::Geocoder, points) => Array{NamedTuple{(:country, :country_code, :city), Tuple{String, String, String}}}

Return country name and city for collection of points. Points should be either an array of staticaly sized arrays 
(e.g. StaticArrays) or a Matrix (see NearestNeighbors.jl documentation for details). 

The country and city is determined by the nearest neighbor search in the labelled list of city locations from geonames.org.
As such, the results may not be exactly accurate (e.g searches for points close to borders or in the middle of nowhere).

Nearest neighbor search uses the euclidian metric in the space of lat/lon coordinates. 

```
# Example
julia> gc = Geocoder();
julia> ReverseGeocode.decode(gc, [SA[49.5863897, 17.2627342], SA[63.3342550, 12.0280064]])
2-element Array{Tuple{String,String},1}:
 (country="Czechia", country_code="CZ", city="Olomouc")
 (country="Norway", country_code="NO", city="Meråker")
```
"""
function decode(gc::Geocoder, points::Union{AbstractArray{<:AbstractArray{<:Real, 1}}, AbstractArray{<:Real,2}})::Array{NamedTuple{(:country, :country_code, :city), Tuple{String, String, String}}}
    idxs, dist = nn(gc.tree, points)
    infos = [gc.info[idx] for idx in idxs]
    tags = [(country=gc.country_codes[i.country_code], country_code=i.country_code, city=i.city) for i in infos]
end


"""
    decode(gc::Geocoder, point) => NamedTuple{(:country, :country_code, :city), Tuple{String, String, String}}

Decode for single point. If processing many points, use `decode(gc, points)` instead of this method in a loop. 
"""
function decode(gc::Geocoder, point::AbstractArray{<:Real, 1})
    decode(gc, [point,])[1]
end