using ReverseGeocode
using Test
using StaticArrays
using NearestNeighbors

test_locs = [
(tag = (country="Czechia", country_code="CZ", city="Olomouc"), latlon = SA[49.5863897, 17.2627342]),
(tag = (country="Germany", country_code="DE", city="Bad Elster"), latlon = SA[50.3005700, 12.2091950]),
(tag = (country="Czechia", country_code="CZ", city="Hranice"), latlon = SA[50.3050656, 12.1865356]),
(tag = (country="Norway", country_code="NO", city="Meråker"), latlon = SA[63.3342550, 12.0280064]),
(tag = (country="Norway", country_code="NO", city="Meråker"), latlon = SA[63.2887794, 12.1626800]), # cordinates are in fact 5 km from the Norwegian border in Sweden, by the town of Storlien
]

@testset "ReverseGeocode.jl" begin
@testset "decode" begin
    data_dir = "./prepared_data"
    geo_file = "test_cities"
    gc = Geocoder(;data_dir=data_dir, geo_file=geo_file)

    # Test individually
    for loc in test_locs
        geo = ReverseGeocode.decode(gc, loc.latlon)

        @test loc.tag == ReverseGeocode.decode(gc, loc.latlon)
    end
    
    # Test with array of SAs
    @test [loc.tag for loc in test_locs] == ReverseGeocode.decode(gc, [loc.latlon for loc in test_locs])

    # Test with Matrix
    test_loc_matrix = Matrix(hcat([l.latlon for l in test_locs]...))
    @test [loc.tag for loc in test_locs] == ReverseGeocode.decode(gc, test_loc_matrix)

    
    select = [:country_code, :name, :country, :population]
    df = ReverseGeocode.read_data(;data_dir=data_dir, geo_file=geo_file, decoder_output_columns=select)

    # Test decoder constructed with user specified :population via `select`
    gc = Geocoder(; data_dir=data_dir, geo_file=geo_file, decoder_output_columns=select)
    for loc in test_locs
        geo = ReverseGeocode.decode(gc, loc.latlon)
        idx = findfirst(==(loc.tag.city), df.name)
        @test geo.population == df.population[idx]
    end
    
    # Test decoder constructed with df 
    gc = Geocoder(df)

    for loc in test_locs
        geo = ReverseGeocode.decode(gc, loc.latlon)
        idx = findfirst(==(loc.tag.city), df.name)
        @test geo.population == df.population[idx]
    end
end
@testset "Geocoder setup" begin
    geo_file = "test_cities1000"
    data_dir = "./downloaded_data/"

    """
        Mockup of the download function.
    """
    function ReverseGeocode.download_raw_geoname_data(;
        data_dir::String=DATA_DIR,
        geo_file::String=GEO_FILE,
    )
        mock_data_source = "./downloaded_data/mock_website_download/test_cities1000.zip"
        cp(mock_data_source, joinpath(data_dir,"$geo_file.zip"))
    end

    gc = Geocoder(;data_dir=data_dir, geo_file=geo_file, decoder_output_columns = ReverseGeocode.DEFAULT_DECODER_OUTPUT)

    @test !isfile(joinpath(data_dir, "$geo_file.zip"))
    @test isfile(joinpath(data_dir, "$geo_file.csv"))

    output = decode(gc, [[0.,0.] [50.00,50.00]])
    @test collect(keys(output[1])) == [:country, :country_code, :city]
end
end