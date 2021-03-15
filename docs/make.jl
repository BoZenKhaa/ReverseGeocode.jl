using ReverseGeocode
using Documenter

DocMeta.setdocmeta!(ReverseGeocode, :DocTestSetup, :(using ReverseGeocode); recursive=true)

makedocs(;
    modules=[ReverseGeocode],
    authors="Jan Mrkos <mrkosjan@gmail.com>",
    repo="https://github.com/BoZenKhaa/ReverseGeocode.jl/blob/{commit}{path}#{line}",
    sitename="ReverseGeocode.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://BoZenKhaa.github.io/ReverseGeocode.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/BoZenKhaa/ReverseGeocode.jl",
)
