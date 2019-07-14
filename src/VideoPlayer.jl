module VideoPlayer

using VideoIO

abstract type AbstractVideoBackend end

include(joinpath(@__DIR__, "..", "deps", "includes.jl"))

play(args...; kwargs...) = play(videobackend(), args...; kwargs...)

export videobackend, play

end # module
