using Makie, VideoIO, Dates, Observables

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
