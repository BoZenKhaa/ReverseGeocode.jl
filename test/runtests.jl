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
    gc = Geocoder(;data_dir="./data", geo_file="test_cities")

    # Test individually
    for loc in test_locs
        @test loc.tag == ReverseGeocode.decode(gc, loc.latlon)
    end
    
    # Test with array of SAs
    @test [loc.tag for loc in test_locs] == ReverseGeocode.decode(gc, [loc.latlon for loc in test_locs])

    # Test with Matrix
    test_loc_matrix = Matrix(hcat([l.latlon for l in test_locs]...))
    @test [loc.tag for loc in test_locs] == ReverseGeocode.decode(gc, test_loc_matrix)
end