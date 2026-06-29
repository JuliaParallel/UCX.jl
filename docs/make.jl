using UCX
using Literate
using Documenter

##
# Generate examples
##

const EXAMPLES_DIR = joinpath(@__DIR__, "..", "examples")
const OUTPUT_DIR   = joinpath(@__DIR__, "src/generated")

examples = [
]

for (_, name) in examples
    example_filepath = joinpath(EXAMPLES_DIR, string(name, ".jl"))
    Literate.markdown(example_filepath, OUTPUT_DIR, documenter=true)
end

examples = [title=>joinpath("generated", string(name, ".md")) for (title, name) in examples]

makedocs(;
    modules=[UCX],
    authors="Valentin Churavy",
    repo=Remotes.GitHub("JuliaParallel", "UCX.jl"),
    sitename="UCX.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://juliaparallel.github.io/UCX.jl",
        assets=String[],
        mathengine = MathJax3(),
    ),
    pages = [
        "Home" => "index.md",
        # "Examples" => examples,
        "API" => "api.md",
    ],
    doctest = true,
    linkcheck = true,
)

deploydocs(;
    repo="github.com/JuliaParallel/UCX.jl",
    devbranch = "main",
    push_preview = true,
)
