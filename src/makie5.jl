using Makie, VideoIO, Dates, Observables, DataStructures

include("testvideo.jl")

testvideo = joinpath(tempdir(), "test.mp4")

# create the test video if it doesn't exist
if !isfile(testvideo)
    createtestvideo(testvideo)
end


avf = VideoIO.testvideo("annie_oakley")
testvideo = avf.io
# f = VideoIO.openvideo(avf)

# open the video
f = VideoIO.openvideo(testvideo)

f2 = VideoIO.openvideo(testvideo)

duration = VideoIO.get_duration(f.avin.io)

_img = read(f)
seekstart(f)

img = Observable(_img)
current = Observable(0.0)
on(current) do t
    try
        seek(f, t)
    catch ex
        if !isa(ex, EOFError)
            throw(ex)
        end
    end
end
correctcurrent = lift(img) do _
    gettime(f)
end
timestamp = lift(correctcurrent) do cc
    Time(0,0,0,1) + Millisecond(round(Int, 1000cc))
end

# all the stuff needed for display
rsc() = Scene(;camera = campixel!, raw = true, backgroundcolor = :black)
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
slidersteps = range(0, duration, length = 100)
slider_h = slider!(rsc(), slidersteps, start = 0, valueprinter = i -> "no, this will be wrong", textcolor = :white)

lift(slider_h[end][:value]) do t
    current[] = t
    if !eof(f)
        img[] = read(f)
    end
    nothing
end

# this is for a separate display of the time stamp, due to the fact that we can not calculate with the time stamp is from the frame number (which is what the slider has)
timestamp_h = text!(rsc(), lift(string, timestamp), color = :white)

# I have to have a forward button becuase apparently the stuff in the lift gets evaluated, so to have the movie start in frame #1 I need to go forward once and the backwards...
fwdbutton = button!(rsc(), ">", textcolor = :white)
lift(fwdbutton[end][:clicks]) do _
    if !eof(f)
        img[] = read(f)
    end
    #=if correctcurrent[] - slider_h[end][:value][] > step(slidersteps)/2
        @info "do"
        slider_h[end][:value][] += step(slidersteps) # this doesn't work
    end=#
    nothing
end
bckbutton = button!(rsc(), "<", textcolor = :white)
lift(bckbutton[end][:clicks]) do _
    t2 = correctcurrent[]
    seek(f, max(t2 - 1, 0.0))
    read(f)
    t0 = 0.0
    t1 = 0.0
    while t1 < t2
        t0 = gettime(f)
        read(f)
        t1 = gettime(f)
    end
    current[] = t0
    img[] = read(f)
end

# done!
hbox(vbox(bckbutton, slider_h, fwdbutton, timestamp_h), scene)

# played = Observables.async_latest(play, play_bubtton[end][:clicks])

# hbox(vbox(play_button, next_button, slider_h), scene)

