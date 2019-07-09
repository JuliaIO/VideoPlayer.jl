using Makie, VideoIO, Dates, Observables

avf = VideoIO.testvideo("annie_oakley")
flipx=false
flipy=false
f = VideoIO.openvideo(avf)
# seek(f, 2.0)
pixelaspectratio = VideoIO.aspect_ratio(f)
h = f.height
w = round(typeof(h), f.width*pixelaspectratio)
scene = Makie.Scene(resolution = (w, h))
buf = read(f)
makieimg = Makie.image!(scene, 1:h, 1:w, buf, show_axis = false, scale_plot = false)[end]
Makie.rotate!(scene, -0.5pi)
if flipx && flipy
    Makie.scale!(scene, -1, -1, 1)
else
    flipx && Makie.scale!(scene, -1, 1, 1)
    flipy && Makie.scale!(scene, 1, -1, 1)
end
next_button = button(">", raw=true, camera=campixel!) 
function readshow(_ = nothing)
    read!(f, buf)
    makieimg[3] = buf
end
stepped = lift(readshow, next_button[end][:clicks])
slide_slider = slider(0:round(Int, Dates.value(VideoIO.get_duration(avf.io))/10^6), raw = true, camera = campixel!, start = 0)
function slide(t)
    seek(f, Float64(t))
    readshow()
end
slided = lift(slide, slide_slider[end][:value])
t = onany(stepped, slided) do _, _
    gettime(f)
end
txt = text("00:00:00.000", raw = true, camera = campixel!)
onany(t) do s
    txt[end][1] = string(Time(0) + Microsecond(round(Int, 1000000s)))
end
hbox(vbox(s1, bnext, txt), scene)
