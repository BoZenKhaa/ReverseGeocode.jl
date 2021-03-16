const GEO_FILE = "cities1000"
const GEO_SOURCE = "http://download.geonames.org/export/dump"
const DATA_DIR = "./data"

"""
'''
Column names in the geonames dumpfile (from http://download.geonames.org/export/dump):
---------------------------------------------------
geonameid         : integer id of record in geonames database
name              : name of geographical point (utf8) varchar(200)
asciiname         : name of geographical point in plain ascii characters, varchar(200)
alternatenames    : alternatenames, comma separated, ascii names automatically transliterated, convenience attribute from alternatename table, varchar(10000)
latitude          : latitude in decimal degrees (wgs84)
longitude         : longitude in decimal degrees (wgs84)
feature class     : see http://www.geonames.org/export/codes.html, char(1)
feature code      : see http://www.geonames.org/export/codes.html, varchar(10)
country code      : ISO-3166 2-letter country code, 2 characters
cc2               : alternate country codes, comma separated, ISO-3166 2-letter country code, 200 characters
admin1 code       : fipscode (subject to change to iso code), see exceptions below, see file admin1Codes.txt for display names of this code; varchar(20)
admin2 code       : code for the second administrative division, a county in the US, see file admin2Codes.txt; varchar(80) 
admin3 code       : code for third level administrative division, varchar(20)
admin4 code       : code for fourth level administrative division, varchar(20)
population        : bigint (8 byte int) 
elevation         : in meters, integer
dem               : digital elevation model, srtm3 or gtopo30, average elevation of 3''x3'' (ca 90mx90m) or 30''x30'' (ca 900mx900m) area in meters, integer. srtm processed by cgiar/ciat.
timezone          : the iana timezone id (see file timeZone.txt) varchar(40)
modification date : date of last modification in yyyy-MM-dd format]
'''
"""
const COLUMNS = [:geonameid, :name, :asciiname, :alternatenames, :latitude, :longitude, 
                :feature_class, :feature_code, :country_code, :cc2, :admin1_code, :admin2_code, 
                :admin3_code, :admin4_code, :population, :elevation, :dem, :timezone, :modification_date]
                
"""
    Geocoder(;data_dir="./data", geo_file="cities1000"))

Geocoder structure that holds the reference points and their labels.
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

Load coordinates, country_codes and city names from the csv export of the geonames file.
Make sure to call download_data() before read_data().
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
fetches a file of all cities with a population > 1000 (other options are 500,5000,15000) (or 
seats of admin div). The dump is unpacked and city name, coordinates and country code are resaved 
in a csv file for use in the Geocoder. 
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
end

"""
Download and resave the country codes csv from geonames.
"""
function download_country_codes(;data_dir::String=DATA_DIR)
    download("http://download.geonames.org/export/dump/countryInfo.txt", "$data_dir/countryInfo.txt")
    country_info = CSV.File("$data_dir/countryInfo.txt"; delim="\t", header=false, select=[1,5], datarow=51)
    country_codes = Dict([(c.Column1, c.Column5) for c in country_info])
    CSV.write("$data_dir/country_codes.csv", country_codes, delim="\t", header=false)
end

"""
    decode(gc::Geocoder, points)=> Array{Tuple{String, String}}

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
 ("Czechia", "CZ", "Olomouc")
 ("Norway", "NO", "Meråker")
```
"""
function decode(gc::Geocoder, points::Union{AbstractArray{<:AbstractArray{<:Real, 1}}, AbstractArray{<:Real,2}})=>
    idxs, dist = nn(gc.tree, points)
    info = [gc.info[idx] for idx in idxs]
    tags = [(gc.country_codes[i.country_code], i.country_code, i.city) for i in info]
end


"""
    decode(gc::Geocoder, point) => Tuple(String, String)

Decode for single points. If processing many points, it should be faster with `decode(gc, points)` than with this function. 
"""
function decode(gc::Geocoder, point::AbstractArray{<:Real, 1})
    decode(gc, [point,])[1]
end