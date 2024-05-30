const GEO_FILE = "cities1000"
const GEO_SOURCE = "http://download.geonames.org/export/dump"
const DATA_DIR = joinpath(dirname(dirname(pathof(ReverseGeocode))),"data")

"""
Geoname description from https://download.geonames.org/export/dump/:

Note that in the cities1000 dataset, the `name` is a city name. 

The main 'geoname' table has the following fields :
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
modification date : date of last modification in yyyy-MM-dd format
"""
const COLUMN_TYPE = OrderedDict(
    :geonameid => Int, 
    :name => String,
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

# Columns to select from the geonames data and store in the reference dataset
const DEFAULT_GEONAME_SELECT = [:geonameid, :name, :latitude, :longitude, 
:feature_class, :feature_code, :country_code, :admin1_code, :admin2_code, 
:population, :modification_date]
const DEFAULT_DECODER_OUTPUT  = [:country_code, :name, :country]

"""
    Geocoder(cities_data::AbstractDataFrame; filters::Vector{Function} = Function[])
    Geocoder(;
        data_dir::String=DATA_DIR, 
        geo_file::String=GEO_FILE, 
        decoder_output_columns::Vector{Symbol} = DEFAULT_DECODER_OUTPUT,
        filters::Vector{Function} = Function[]
    )

Geocoder structure that holds the reference points and their labels (city name and country code).

The second constructor is used to create the Geocoder from the geoname data that it automatically downloads on first run.
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
    decoder_output_columns::Vector{Symbol}    = DEFAULT_DECODER_OUTPUT,
    filters::Vector{Function} = Function[]
)

    # First time setup   
    if !isfile(joinpath(data_dir,"$geo_file.csv"))
        @info "$geo_file.csv not found in $data_dir."
        if !isfile(joinpath(data_dir,"$geo_file.zip"))
            @info "Downloading $geo_file zip from $GEO_SOURCE/$geo_file.zip."
            download_raw_geoname_data(;data_dir=data_dir, geo_file=geo_file)
        end
        @info "Processing $geo_file.zip."
        process_and_store_geoname_data(;data_dir=data_dir, geo_file=geo_file)
        @info "Reference dataset sucessfuly extracted and saved in $(joinpath(data_dir,geo_file)).csv."
    end

    # Load reference dataset and create Geocoder
    dataframe = read_data(; data_dir, geo_file, decoder_output_columns)
    Geocoder(dataframe; data_dir, filters)
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
    read_data(;data_dir="./data", geo_file="cities1000", select=DEFAULT_DECODER_OUTPUT) => DataFrame

Load coordinates, country codes and city names from the `.csv` saved export of the geonames file.
Make sure to download the date before calling `read_data()`.
"""
function read_data(;
    data_dir::String       = DATA_DIR, 
    geo_file::String       = GEO_FILE,
    decoder_output_columns::Vector{Symbol} = DEFAULT_DECODER_OUTPUT,
)
    filter!(x -> x ≠ :country, decoder_output_columns)
    union!(decoder_output_columns, [:latitude, :longitude])
    
    data = CSV.read(joinpath(data_dir,"$geo_file.csv"), DataFrame; 
        validate = false,
        delim    = '\t',
        types    = COLUMN_TYPE,
        select   = decoder_output_columns
    )

    select!(data, decoder_output_columns)
    data
end

"""
    download_raw_geoname_data(;data_dir="./data", geo_file="cities1000")

Download dump from [geonames.org](http://download.geonames.org/export/dump/). This function 
fetches a file of cities with a population > 1000 (and seats of administrations of ceratain country subdivisions, 
other options are population 500, 5000, 15000, see geonames.org for details). 
"""
function download_raw_geoname_data(;
    data_dir::String=DATA_DIR,
    geo_file::String=GEO_FILE,
)
    Downloads.download("$GEO_SOURCE/$geo_file.zip", joinpath(data_dir,"$geo_file.zip"))
end

"""
    process_geoname_data(;data_dir="./data", geo_file="cities1000", header =collect(keys(COLUMN_TYPE)), select=DEFAULT_GEONAME_SELECT)

Process the raw geoname data and save it as a csv. Only selected columns are stored in the csv file. Removes the zip file. 
"""
function process_and_store_geoname_data(;
    data_dir::String=DATA_DIR, 
    geo_file::String=GEO_FILE, 
    header::Vector{Symbol} = collect(keys(COLUMN_TYPE)),
    select::Vector{Symbol} = DEFAULT_GEONAME_SELECT
)
    @assert Set(select) ⊆ Set(header) "`select` columns must be a subset of dataset `header`."
    # extract the csv and drop unnecessary columns
    r = ZipFile.Reader(joinpath(data_dir,"$geo_file.zip"))
    data = CSV.File(read(r.files[1]); delim="\t", header, select)
    close(r)
    # resave needed data as csv
    CSV.write(joinpath(data_dir,"$geo_file.csv"), data; delim="\t")
    # clean up
    rm(joinpath(data_dir,"$geo_file.zip"))
end

"""
Download and resave the country codes csv from geonames. 
Country codes are part of the package so this function does not usually need to run during install. 
"""
function download_country_codes(;data_dir::String=DATA_DIR)
    Downloads.download("http://download.geonames.org/export/dump/countryInfo.txt", joinpath(data_dir, "countryInfo.txt"))
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
