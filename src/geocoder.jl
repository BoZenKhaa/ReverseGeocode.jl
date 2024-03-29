const GEO_FILE = "cities1000"
const GEO_SOURCE = "http://download.geonames.org/export/dump"
const DATA_DIR = joinpath(dirname(dirname(pathof(ReverseGeocode))),"data")
const DEFAULT_DECODER_OUTPUT  = [:country_code, :name, :country]
const DEFAULT_DOWNLOAD_SELECT = [:geonameid, :name, :latitude, :longitude, 
:feature_class, :feature_code, :country_code, :admin1_code, :admin2_code, 
:population, :modification_date]

const COLUMN_TYPE = OrderedDict(
    :geonameid => Int, 
    :name => String,
    :city => String,
    :asciiname => String, 
    :alternatenames => String, 
    :latitude => Float64, 
    :longitude => Float64, 
    :feature_class => String, 
    :feature_code => String, 
    :country_code => String, 
    :cc2 => String, 
    :admin1_code => String, 
    :admin2_code => String, 
    :admin3_code => String, 
    :admin4_code => String, 
    :population => Int, 
    :elevation => Int,
    :dem => Int, 
    :timezone => String, 
    :modification_date => String
)
                
"""
    Geocoder(cities_data::AbstractDataFrame; filters::Vector{Function} = Function[])
    Geocoder(;data_dir::String=DATA_DIR, geo_file::String=GEO_FILE, filters::Vector{Function} = Function[])

Geocoder structure that holds the reference points and their labels (city name and country code).
"""
struct Geocoder
    tree::NNTree
    info::Array{NamedTuple}
    country_codes::Dict{Symbol, Symbol}
end

function Geocoder(cities_data::AbstractDataFrame;
    data_dir::String          = DATA_DIR,
    filters::Vector{Function} = Function[]
)
    data = foldl((df, f) -> f(df), filters, init=cities_data)
    
    points, info = _split_latlon_and_info(rename(data, :name => :city))
    tree = KDTree(points)
    country_codes = Dict{Symbol, Symbol}(
        CSV.File(joinpath(data_dir, "country_codes.csv"); 
            delim  = '\t', 
            header = false,
            types = [Symbol, Symbol]
        )
    )

    Geocoder(tree, info, country_codes)
end

function Geocoder(;
    data_dir::String          = DATA_DIR,
    geo_file::String          = GEO_FILE,
    select::Vector{Symbol}    = DEFAULT_DECODER_OUTPUT,
    filters::Vector{Function} = Function[]
)
    if ! isfile(joinpath(data_dir,"$geo_file.csv"))
        download_data(;data_dir=data_dir, geo_file=geo_file)
    end

    data = read_data(; data_dir, geo_file, select)
    Geocoder(data; data_dir, filters)
end


function _split_latlon_and_info(data::AbstractDataFrame)
    info_headers = tuple(filter(x -> x ∉ [:latitude, :longitude], Symbol.(names(data)))...)
    
    n = nrow(data)
    points = Array{Float64}(undef, 2, n)
    example_info = NamedTuple{info_headers}(
        getproperty.(Ref(data[1, :]), info_headers)
    )
    
    info = Array{typeof(example_info)}(undef, n)
    for (i, row) ∈ enumerate(eachrow(data))
        points[:, i] .= row.latitude, row.longitude
        row_info = NamedTuple{info_headers}(
            getproperty.(Ref(row), info_headers)
        )
        info[i]  = NamedTuple{info_headers}(Tuple(row_info))
    end

    points, info
end

"""
    read_data(;data_dir="./data", geo_file="cities1000")

Load coordinates, country codes and city names from the `.csv` saved export of the geonames file.
Make sure to call `download_data()` before `read_data()`.
"""
function read_data(;
    data_dir::String       = DATA_DIR, 
    geo_file::String       = GEO_FILE,
    select::Vector{Symbol} = DEFAULT_DECODER_OUTPUT,
)
    filter!(x -> x ≠ :country, select)
    union!(select, [:latitude, :longitude])
    
    data = CSV.read(joinpath(data_dir,"$geo_file.csv"), DataFrame; 
        validate = false,
        delim    = '\t',
        types    = COLUMN_TYPE,
        select
    )

    select!(data, select)
    data
end

"""
    download_data(;data_dir="./data", geo_file="cities1000", header=COLUMNS)

Download dump from [geonames.org](http://download.geonames.org/export/dump/). This function 
fetches a file of cities with a population > 1000 (and seats of administrations of ceratain country subdivisions, 
other options are population 500, 5000, 15000, see geonames.org for details). 
The dump is unpacked and city name, coordinates and country code are saved 
in a `.csv` file for use in the Geocoder. 
"""
function download_data(;
    data_dir::String=DATA_DIR,
    geo_file::String=GEO_FILE,
    header = keys(COLUMN_TYPE),
    select = DEFAULT_DOWNLOAD_SELECT
)
    # Download the source file
    download("$GEO_SOURCE/$geo_file.zip", joinpath(data_dir,"$geo_file.zip"))
    # extract the csv and drop unnecessary columns
    r = ZipFile.Reader(joinpath(data_dir,"$geo_file.zip"))
    data = CSV.File(read(r.files[1]); delim="\t", header, select)
    close(r)
    # save needed data as csv
    CSV.write(joinpath(data_dir,"$geo_file.csv"), data; delim="\t")
    # clean up
    rm(joinpath(data_dir,"$geo_file.zip"))
    
    @info "Reference dataset sucessfuly saved in $data_dir."
end

"""
Download and resave the country codes csv from geonames. 
Country codes are part of the package so this function does not usually need to run during install. 
"""
function download_country_codes(;data_dir::String=DATA_DIR)
    download("http://download.geonames.org/export/dump/countryInfo.txt", "$data_dir/countryInfo.txt")
    country_info = CSV.File(joinpath(data_dir,"countryInfo.txt"); delim="\t", header=false, select=[1,5], datarow=51)
    country_codes = Dict([(c.Column1, c.Column5) for c in country_info])
    CSV.write(joinpath(data_dir,"country_codes.csv"), country_codes, delim="\t", header=false)
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
function decode(gc::Geocoder, points::Union{AbstractVector{<:AbstractVector{<:Real}}, AbstractMatrix{<:Real}})::Vector{NamedTuple{}}
    idxs, dist = nn(gc.tree, points)
    infos = [gc.info[idx] for idx in idxs]

    [(;country=string(gc.country_codes[Symbol(x.country_code)]), x... ) for x in infos]
end


"""
    decode(gc::Geocoder, point) => NamedTuple{(:country, :country_code, :city), Tuple{String, String, String}}

Decode for single point. If processing many points, preferably use `decode(gc, points)` instead of using this method in a loop. 
"""
function decode(gc::Geocoder, point::AbstractVector{<:Real})
    decode(gc, [point])[1]
end
