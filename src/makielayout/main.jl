using AbstractPlotting, GLMakie, MakieLayout, VideoIO, Dates

file = "/home/yakir/videos/[TorrentCounter.to].Spirited.Away.2001.English.Dubbed.1080p.BluRay.x264.[1.8GB].mp4"
f = VideoIO.openvideo(file)
pixelaspectratio = VideoIO.aspect_ratio(f)
h = f.height
w = round(typeof(h), f.width*pixelaspectratio)
duration = VideoIO.get_duration(unsafe_load(f.avin.apFormatContext[1]))
buff = read(f)
img = Node(rotr90(buff))
ct = Node("00:00:00.000")
cc = Node("-")
h_control = 0.1
scene, layout = layoutscene(0, resolution = (Float64(w), h/(1 - h_control)), backgroundcolor = :yellow)
ax = layout[1, 1:5] = LAxis(scene, aspect = DataAspect(), backgroundcolor = :yellow)
layout[2, 1] = LText(scene, ct, textsize = 30, color = :white)
layout[2, 2] = LText(scene, cc, textsize = 30, color = :white)
sl = layout[2, 3] = LSlider(scene, range = range(0, stop = duration, length = 100), startvalue = 0)
on(sl.value) do t
    seek(f, t)
    read!(f, buff)
    img[] = rotr90(buff)
end
bt = layout[2,4] = LButton(scene, label = "⊵")
on(bt.clicks) do _
    read!(f, buff)
    img[] = rotr90(buff)
end
pl = layout[2,5] = LToggle(scene)
on(pl.active) do p
    # while p && !eof(f) && isopen(scene)
    #     read!(f, buff)
    #     img[] = rotr90(buff)
    #     sleep(1/f.framerate)
    # end
end
imgplot = image!(ax, 1:w, 1:h, img)
rowsize!(layout, 2, Relative(h_control))
colsize!(layout, 1, Relative(0.2))
colsize!(layout, 2, Relative(0.2))
hidedecorations!(ax)
tightlimits!(ax)
# rotate!(scene, -π/2)
on(img) do _
    t = VideoIO.gettime(f)
    ct[] = string(Time(0) + Millisecond(round(Int, 1000t)))
end
mousestate = addmousestate!(ax.scene, imgplot)
onmouseleftclick(mousestate) do state
    coordinate = round.(Int, state.pos)
    cc[] = string(coordinate)
end
scene
