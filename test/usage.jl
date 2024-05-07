using Revise
using ReverseGeocode
using ZipFile, CSV

gc = ReverseGeocode.Geocoder()
decode(gc, [[34.2,100.00] [50.01,16.35]])

data_dir=ReverseGeocode.DATA_DIR
geo_file=ReverseGeocode.GEO_FILE
header = collect(keys(ReverseGeocode.COLUMN_TYPE))
select = ReverseGeocode.DEFAULT_GEONAME_SELECT

Set(select)
Set(select) ⊆ Set(header)

gc.download

gc = Geocoder(;data_dir="./test/downloaded_data/", geo_file="test_cities1000")

@assert Set(select) ⊆ Set(header) "`select` columns must be a subset of dataset `header`."

    # Download the source file
download("$(ReverseGeocode.GEO_SOURCE)/$geo_file.zip", joinpath(data_dir,"$geo_file.zip"))
@info "Not downloading anything right now. Nothing at all. Nil. Nada. Zilch."
# extract the csv and drop unnecessary columns
r = ZipFile.Reader(joinpath(data_dir,"$geo_file.zip"))
data = CSV.File(read(r.files[1]); delim="\t", header, select)
close(r)
# save needed data as csv
CSV.write(joinpath(data_dir,"$geo_file.csv"), data; delim="\t")
# clean up
rm(joinpath(data_dir,"$geo_file.zip"))

@info "Reference dataset sucessfuly saved in $data_dir."
