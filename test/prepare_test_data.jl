using NearestNeighbors
using ReverseGeocode

"""
Prepares smaller dataset for testing.
Run this script after changing the testcases and 
after downloading and processing the dataset.
"""
function prepare_testing_dataset(points; 
        full_data="$(ReverseGeocode.DATA_DIR)/$(ReverseGeocode.GEO_FILE).csv")  
    gc = Geocoder()

    # For each tested point, use 10 closest points
    idxs, dist = knn(gc.tree, points, 4)

    # Find the corresponding lines and save them
    lns = unique([1, vcat(vec(idxs)...).+1...]) # 1 for the header

    full_data_lines = readlines(full_data)
    open("./test/data/test_cities.csv", "w") do io
        for ln in lns
            line = full_data_lines[ln]
            write(io, "$line\n")
        end
    end
end

println("Preparing test data...")
points = [l.loc for l in test_locs] # test_locs is variable used in tests.
prepare_testing_dataset(points)
println("Done.")