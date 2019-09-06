using Makie, VideoIO, Dates, Observables, DataStructures

include("testvideo.jl")

testvideo = joinpath(tempdir(), "testvideo.mp4")

# create the test video if it doesn't exist
if !isfile(testvideo)
    createtestvideo(testvideo)
end


avf = VideoIO.testvideo("annie_oakley")
testvideo = avf.io
# f = VideoIO.openvideo(avf)

# open the video
f = VideoIO.openvideo(testvideo)

duration = VideoIO.get_duration(f.avin.io)

img = read(f)
T = typeof(img)
bufferf = VideoIO.openvideo(testvideo)

# bufferradius = f.width*f.height*VideoIO.get_duration(f.avin.io)*f.framerate
bufferradius = 200
buffertime = bufferradius/f.framerate
bufferlength = 2bufferradius + 1
buffer = CircularBuffer{Pair{Float64, T}}(bufferlength)

function fillbuffer()
    for _ in 1:bufferlength
        push!(buffer, Pair(gettime(bufferf), read(bufferf)))
    end
end
fillbuffer()

current = Observable(first(buffer[bufferradius + 1]))

correctcurrent = lift(current) do c
    if c ∈ first.(buffer)
        c
    else
        seek(f, c)
        gettime(f)
    end
end

timestamp = lift(correctcurrent) do cc
    Time(0) + Millisecond(round(Int, 1000cc))
end

img = lift(correctcurrent) do cc
    i = findfirst(timg -> first(timg) > cc, buffer)
    if isnothing(i)
        read(f)
    else
        last(buffer[i])
    end
end
updatebuffer = on(correctcurrent) do cc
    m = max(cc - buffertime, 0.0)
    M = min(cc + buffertime, duration)
    mi = findfirst(timg -> first(timg) ≥ m, buffer)
    Mi = findfirst(timg -> first(timg) ≥ M, buffer)
    if mi == 1 && m > 0
        seek(bufferf, m)
        if Mi == 1
            fillbuffer()
        else
            # @assert Mi < bufferlength
            news = Vector{Pair{Float64, T}}()
            push!(news, Pair(gettime(bufferf), read(bufferf)))
            while first(news[end]) < first(first(buffer))
                push!(news, Pair(gettime(bufferf), read(bufferf)))
            end
            pop!(news)
            for timg in Iterators.reverse(news)
                pushfirst!(buffer, timg)
            end
        end
    elseif !isnothing(mi)
        # @assert isnothing(Mi) m, M, mi, Mi
        while first(buffer[end]) < M
            push!(buffer, Pair(gettime(bufferf), read(bufferf)))
        end
    else
        # @assert isnothing(Mi) m, M, mi, Mi
        seek(bufferf, m)
        fillbuffer()
    end
    0
end


        
# all the stuff needed for display
pixelaspectratio = VideoIO.aspect_ratio(f)
h = f.height
w = round(typeof(h), f.width * pixelaspectratio)
AbstractPlotting.set_theme!(backgroundcolor = :black)
scene = Scene(resolution = (w, h))
Makie.image!(scene, 1:h, 1:w, img, show_axis = false, scale_plot = false)
Makie.rotate!(scene, -0.5π)
update_limits!(scene)
update_cam!(scene)
Makie.update!(scene)

# the slider, updating currentframe and getting its string from timestamps
slider_h = slider(range(0, duration, step = 1/f.framerate), start = 0, valueprinter = i -> "no, this will be wrong", textcolor = :white)

lift(slider_h[end][:value]) do t
    current[] = t
end

# this is for a separate display of the time stamp, due to the fact that we can not calculate with the time stamp is from the frame number (which is what the slider has)
timestamp_h = text(lift(string, timestamp), color = :white, raw = true, camera = campixel!)

# I have to have a forward button becuase apparently the stuff in the lift gets evaluated, so to have the movie start in frame #1 I need to go forward once and the backwards...
fwdbutton = button(">", textcolor = :white)
lift(fwdbutton[end][:clicks]) do _
    i = findfirst(timg -> first(timg) == correctcurrent[], buffer)
    @assert !isnothing(i)
    correctcurrent[] = first(buffer[i])
    slider_h[end][:value][] += 1
    # so now the movie is in frame #2
    # end
end
#=bckbutton = button!(rsc(), "<", textcolor = :white)
lift(bckbutton[end][:clicks]) do _
if currentframe[] > 1 # check we're not in frame #1
currentframe[] -= 1
slider_h[end][:value][] -= 1
# and now we're back in frame #1
end
0
end=#

# done!
hbox(vbox(slider_h, fwdbutton, timestamp_h), scene)

# played = Observables.async_latest(play, play_bubtton[end][:clicks])

# hbox(vbox(play_button, next_button, slider_h), scene)

