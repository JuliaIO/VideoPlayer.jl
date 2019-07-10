module VideoPlayer

    using VideoIO

    abstract type AbstractVideoBackend end

    videobackend() = MakieBackend

    play(args...; kwargs...) = play(videobackend(), args...; kwargs...)

    export videobackend, play

end # module
