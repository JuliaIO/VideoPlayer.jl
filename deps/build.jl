import Pkg

VLC = try; success(`vlc --version`); catch; false; end

MAKIE = try
            Pkg.add("GLFW")
            using GLFW
            true
            Pkg.rm("GLFW")
        catch
            false
        end

VLC   && @info "VLC backend is available"
MAKIE && @info "Makie backend is available"

open(joinpath(@__DIR__, "includes.jl"), "w") do file

    VLC && println(file, "include(\"vlc.jl\")")

    MAKIE && println(file, "include(\"makie.jl\")")

end
