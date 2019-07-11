using Makie, Dates, Observables, VideoIO

using Makie, VideoIO
f = VideoIO.openvideo(testvideo)
# seek(f, 5.0) # skip the beginning
img = Node(read(f))
buff = Channel{typeof(img[])}(100) # have a buffer with 500 frames
task = @async begin # this is the task that fills that buffer
    while !eof(f)
        put!(buff, read(f))
    end
end
pixelaspectratio = VideoIO.aspect_ratio(f)
h = f.height
w = round(typeof(h), f.width * pixelaspectratio)
scene = Scene(resolution = (w, h), backgroundcolor = :black)
Makie.image!(scene, img)
# Rotate and scale the scene
Makie.rotate!(scene, -0.5π)
# Update all aspects of the Scene.
update_limits!(scene)
update_cam!(scene)
update!(scene)
slider_h = slider(1:250, raw = true, camera = campixel!, start = 2)
old_slider_pos = Node(1)
lift(slider_h[end][:value]) do frame
    while old_slider_pos[] ≤ frame
        img[] = take!(buff)
        old_slider_pos[] += 1
    end
end
hbox(slider_h, scene)




struct Frame{V, T}
    img::V
    time::T
end

# load the video
include("testvideo.jl")
testvideo = joinpath(tempdir(), "test.mp4")
if !isfile(testvideo)
    createtestvideo(testvideo)
end
f = VideoIO.openvideo(testvideo)

# Determine the width and height of the Scene
pixelaspectratio = VideoIO.aspect_ratio(f)
h = f.height
w = round(typeof(h), f.width * pixelaspectratio)

img = read(f)
t = gettime
movie = Vector{Frame}()
push!(movie, img)
while !eof(f)
    push!(movie, read(f))
end


# To flip or not to flip?
flipx = false
flipy = false

rsc() = Scene(;camera = campixel!, raw = true, backgroundcolor = :black)

# define the initial Scene
scene = Scene(resolution = (w, h), backgroundcolor = :black)

# define some Observables
frame = Node(1)
buf = lift(frame) do i
    movie[i]
end

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

# update the scene to make sure
update!(scene)
# display it
scene

fwdbutton  = button!(rsc(), ">", textcolor = :white)
next_button = button(">", raw=true, camera=campixel!)
function step(_)
    frame[] += 1
end
stepped = lift(step, next_button[end][:clicks])

nframes = round(Int, VideoIO.get_duration(avf.io)/Microsecond(Second(1))*f.framerate)

slider_h = slider(1:nframes, raw = true, camera = campixel!, start = 2)

old_slider_pos = Node(1)

lift(slider_h[end][:value]) do new_slider_position
    if old_slider_pos[] ≤ new_slider_position
        for i in old_slider_pos[]:new_slider_position
            buf[] = take!(buff)
        end
        old_slider_pos[] = new_slider_position
    else
        println("no back")
    end
end
hbox(vbox(slider_h, next_button), scene)


hbox(vbox(next_button), scene)


# print in minutes
function print_time(i)
    return string(Time(0) + Microsecond(round(Int, 1000000 * i)))
end
# create a slider to control time (a time machine⁉)
timeslider = slider!(rsc(), 0:1/f.framerate:24, valueprinter = print_time,
            textcolor = :white)
# When the value of the slider is changed, change the time.
lift(timeslider[end][:value]) do value
    time[] = value
end

# Go back and forward by 1 frame each
backbutton = button!(rsc(), "<", textcolor = :white)
fwdbutton  = button!(rsc(), ">", textcolor = :white)
# tie the slider value to the buttons as well
lift(backbutton[end][:clicks]) do clicks
    timeslider[end][:value][] -= 1/f.framerate
end
lift(fwdbutton[end][:clicks]) do clicks
    timeslider[end][:value][] += 1/f.framerate
end

hbox(vbox(backbutton, timeslider, fwdbutton), scene)

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



using Makie, VideoIO#, Observables
avf = VideoIO.testvideo("annie_oakley")
f = VideoIO.openvideo(avf)
seek(f, 5.0) # skip the beginning
img = Node(read(f))
buff = Channel{typeof(img[])}(500) # have a buffer with 500 frames
task = @async begin # this is the task that fills that buffer
    while !eof(f)
        put!(buff, read(f))
    end
end
scene = Makie.image(img)
slider_h = slider(1:500, raw = true, camera = campixel!, start = 2)
old_slider_pos = Node(1)
lift(slider_h[end][:value]) do frame
    if old_slider_pos[] ≤ frame
        for i in old_slider_pos[]:frame
            img[] = take!(buff)
        end
        old_slider_pos[] = frame
    else
        println("can't go back in time! Yet…")
    end
end
hbox(slider_h, scene)




abstract type MakieBackend <: AbstractVideoBackend end

avf = VideoIO.testvideo("annie_oakley")
f = VideoIO.openvideo(avf)

seek(f, 5.0)

img = read(f)

sz = size(img)

nframesbuffer = round(Int, 15f.framerate)

buff = Channel{typeof(img)}(nframesbuffer)

task = @async begin
    while !eof(f)
        put!(buff, read(f))
    end
end

# bind(buff, task)

flipx=false

flipy=false

pixelaspectratio = VideoIO.aspect_ratio(f)

h = f.height

w = round(typeof(h), f.width*pixelaspectratio)

scene = Makie.Scene(resolution = (w, h), backgroundcolor = :black)

makieimg = Makie.image!(scene, 1:h, 1:w, img, show_axis = false, scale_plot = false)[end]

# Rotate and scale the scene
Makie.rotate!(scene, -0.5π)
Makie.scale!(scene, flipx ? -1 : 1,  flipy ? -1 : 1)

next_button = button(">", raw=true, camera=campixel!)

function readshow(i = nothing)
    makieimg[3] = take!(buff)
end

stepped = lift(readshow, next_button[end][:clicks])

nframes = round(Int, VideoIO.get_duration(avf.io)/Microsecond(Second(1))*f.framerate)

slider_h = slider(1:nframes, raw = true, camera = campixel!, start = 2)

old_slider_pos = Node(1)

lift(slider_h[end][:value]) do frame
    @show frame old_slider_pos[] buff
    if old_slider_pos[] ≤ frame# < nframesbuffer
        for i in old_slider_pos[]:frame# - old_slider_pos[]
            take!(buff)
        end
        readshow()
        old_slider_pos[] = frame
    else
        @show frame
    end
end

hbox(vbox(slider_h, next_button), scene)

play_button = button("▷", raw=true, camera=campixel!)

function play(c)
    println("play: ", c)
    if isodd(c)
        for img in buff
            makieimg[3] = img
            sleep(1/f.framerate)
            break
        end
    end
end

# TODO use Observables.async_latest here!!  Button will do its thing well then

played = lift(play, next_button[end][:clicks])

hbox(vbox(play_button, next_button), scene)

videobackend() = MakieBackend
