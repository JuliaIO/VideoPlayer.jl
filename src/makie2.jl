#!/usr/bin/env julia

# # setup
# import Pkg
# Pkg.pkg"add Makie#master AbstractPlotting#master GLMakie#master
#         Observables#master VideoIO"
import Pkg
Pkg.activate(".")
using Makie, Dates, Observables, VideoIO

# load the video
avf = VideoIO.testvideo("annie_oakley")
f = VideoIO.openvideo(avf)

f = VideoIO.openvideo("test.mp4")

# Determine the width and height of the Scene
pixelaspectratio = VideoIO.aspect_ratio(f)
h = f.height
w = round(typeof(h), f.width * pixelaspectratio)

# To flip or not to flip?
flipx = false
flipy = false

rsc() = Scene(;camera = campixel!, raw = true, backgroundcolor = :black)

# define the initial Scene
scene = Scene(resolution = (w, h), backgroundcolor = :black)

# define some Observables
time = Node(0.0)
buf = Node(read(f))

# plot the image.  We're plotting an Observable, so on its update it will update
# the image as well.
img = image!(scene, 1:h, 1:w, buf, show_axis = false, scale_plot = false)[end]
scene

# Rotate and scale the scene
Makie.rotate!(scene, -0.5π)
Makie.scale!(scene, flipx ? -1 : 1,  flipy ? -1 : 1)
# Update all aspects of the Scene.
update_limits!(scene)
update_cam!(scene)
update!(scene)

# when time is updated, lazy-load the video.
lift(time) do t
    seek(f, t)
    read!(f, buf[])
    buf[] = buf[]
end
# update the scene to make sure
update!(scene)
# display it
scene

# set the time to some value - check all this works
time[] = 12.0

# print in minutes
function print_time(i)
    return string(Time(0) + Microsecond(round(Int, 1e6*gettime(f))))#Microsecond(round(Int, 1000000 * i)))
end
# create a slider to control time (a time machine⁉)
timeslider = slider!(rsc(), 0:1/f.framerate:10, valueprinter = print_time,
            textcolor = :white)
# When the value of the slider is changed, change the time.
lift(timeslider[end][:value]) do value
    time[] = value
end

# Go back and forward by 1 frame each
# backbutton = button!(rsc(), "<", textcolor = :white)
fwdbutton  = button!(rsc(), ">", textcolor = :white)
# tie the slider value to the buttons as well
# lift(backbutton[end][:clicks]) do clicks
    # timeslider[end][:value][] -= 1/f.framerate
# end
lift(fwdbutton[end][:clicks]) do clicks
    timeslider[end][:value][] += 1/f.framerate
end

hbox(vbox(timeslider, fwdbutton), scene)

# Lo and behold!  A minimal video "player"!

##################################################################################

# Play button not implemented yet.
#=
playing = Node(true)
playlabel = lift(playing) do p
    if p
        "→"
    else
        "||"
    end
end
playbutton = button!(Scene(t), playlabel, textcolor = :white)
lift(playbutton[end][:clicks]) do clicks
    playing[] = !playing[]
end
playing[] = true
playlabel[]
=#
