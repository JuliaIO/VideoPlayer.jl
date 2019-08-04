# setup
# using Pkg
# Pkg.pkg"add Makie#master AbstractPlotting#master GLMakie#master VideoIO#master Observables DataStructures"

using Makie, VideoIO, Dates, Observables

# include(joinpath(@__DIR__, "testvideo.jl"))

# testvideo = joinpath(tempdir(), "test.mp4")
#
# # create the test video if it doesn't exist
# if !isfile(testvideo)
#     createtestvideo(testvideo)
# end


testvideo = joinpath(tempdir(), "testvideo.mp4")
# f = VideoIO.openvideo(avf)
_correctimg(img) = rotr90(img)

# open the video
f = VideoIO.openvideo(testvideo)

f2 = VideoIO.openvideo(testvideo)

duration = VideoIO.get_duration(f.avin.io)

_img = _correctimg(read(f))
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
Makie.image!(scene, 1:w, 1:h, img, show_axis = false, scale_plot = false)
# Makie.rotate!(scene, -0.5π)
update_limits!(scene)
update_cam!(scene)
Makie.update!(scene)

# the slider, updating currentframe and getting its string from timestamps
slidersteps = range(0, duration, length = 100)
slider_h = slider!(rsc(), slidersteps, start = 0.0, valueprinter = _ -> "lolno", textcolor = :white)

lift(slider_h[end][:value]) do t
    current[] = t
    if !eof(f)
        img[] = _correctimg(read(f))
    end
    nothing
end

# this is for a separate display of the time stamp, due to the fact that we can not calculate with the time stamp is from the frame number (which is what the slider has)
timestamp_h = text!(rsc(), lift(string, timestamp), color = :white)

# I have to have a forward button becuase apparently the stuff in the lift gets evaluated, so to have the movie start in frame #1 I need to go forward once and the backwards...
fwdbutton = button!(rsc(), ">", textcolor = :white)
lift(fwdbutton[end][:clicks]) do _
    slider_h[end].value[] = slider_h[end].value[] + steplen
    # if !eof(f)
    #     img[] = _correctimg(read(f))
    # end
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
    # read(f)
    # t0 = 0.0
    # t1 = 0.0
    # while t1 < t2
    #     t0 = gettime(f)
    #     read(f) # TODO FIXME inefficient
    #     t1 = gettime(f)
    # end
    current[] = max(t2 - 1, 0.0)
    img[] = read(f) |> _correctimg
end

# done!

sc = Scene(resolution = (Int64(w), h+Int64(100)))
sc.center=false

hbox(vbox(bckbutton, slider_h, fwdbutton, timestamp_h), scene; parent=sc)

# setup keyboard controls
kb = on(sc.events.keyboardbuttons) do kb
    if ispressed(sc, Keyboard.right)
        fwdbutton[end][:clicks][] += 1
    elseif ispressed(sc,Keyboard.left)
        bckbutton[end][:clicks][] += 1
    end
end

lastmpos = Node(Point2f0(0e0, 0e0))

to_screen(scene, mpos) = Point2f0(mpos) .- Point2f0(minimum(pixelarea(scene)[]))
mouseposition(scene) = to_world(scene, to_screen(scene, events(scene).mouseposition[]))

mb = on(scene.events.mousebuttons) do mb
    if ispressed(scene, Mouse.left)
        lastmpos[] = mouseposition(scene)
    end
end

return sc, lastmpos

Observables.off(scene.events.mousebuttons, mb)
