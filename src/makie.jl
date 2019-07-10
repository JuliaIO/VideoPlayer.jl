using Makie, VideoIO, Dates, Observables
avf = VideoIO.testvideo("annie_oakley")
f = VideoIO.openvideo(avf)
img = read(f)
sz = size(img)
nframesbuffer = round(Int, 5f.framerate)
buff = Channel{typeof(img)}(nframesbuffer)
function fillbuff()
    while !eof(f) 
        put!(buff, read(f))
    end
end
task = @async fillbuff()
bind(buff, task)
flipx=false
flipy=false
pixelaspectratio = VideoIO.aspect_ratio(f)
h = f.height
w = round(typeof(h), f.width*pixelaspectratio)
scene = Makie.Scene(resolution = (w, h))
makieimg = Makie.image!(scene, 1:h, 1:w, img, show_axis = false, scale_plot = false)[end]
Makie.rotate!(scene, -0.5pi)
if flipx && flipy
    Makie.scale!(scene, -1, -1, 1)
else
    flipx && Makie.scale!(scene, -1, 1, 1)
    flipy && Makie.scale!(scene, 1, -1, 1)
end
next_button = button(">", raw=true, camera=campixel!) 
function readshow(_ = nothing)
    makieimg[3] = take!(buff)
end
stepped = lift(readshow, next_button[end][:clicks])
play_button = button("▷", raw=true, camera=campixel!) 
function play(c)
    if isodd(c)
        for img in buff
            makieimg[3] = img
            sleep(1/f.framerate)
        end
    end
end
played = lift(play, next_button[end][:clicks])
hbox(vbox(play_button, next_button), scene)
