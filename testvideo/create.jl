import Pkg
Pkg.activate(".")

using GLMakie, VideoIO, Makie, Dates, Printf, Colors, ImageTransformations, FFMPEG

mss = [Millisecond(25), Millisecond(125)] # intervals between frames for the 2 different FPS
fs = Int[] # number of frames per FPS
ts = [Millisecond(0)] # the timestamps
for (i, ms) in enumerate(mss)
    n = 1
    while last(ts) < Second(5i)
        push!(ts, last(ts) + ms)
        n += 1
    end
    push!(fs, n)
end
fs[1] -= 1 # a correction for how `mp4fpsmod` works.
dar = 2 # or PAR, the physical geometry of the pixels.
w = length(ts) # width of the image
h = dar*w # scaling the height
frame = Node(1)
point = lift(frame) do fn
    [(fn, dar*fn)]
end
msg = lift(frame, point) do fn, p
    ti = @sprintf "%03i" fn
    t = @sprintf "%-012s" Time(0) + ts[fn]
    x, y = p[]
    """
    Frame #: $ti
    Time: $t
    x: $x
    y: $y"""
end
limits = FRect3D(Vec3f0(1, 2, 0), Vec3f0(w - 1, 2w - 2, 0))
scene = Scene(resolution = (w, h), limits = limits,  scale_plot = false, show_axis = false)#, padding=(0,0), backgroundcolor=:red)
text!(scene, msg, position = (2, w), align = (:left,  :bottom))#, color = :white)
scatter!(scene, point, markersize = 10, marker = :+)#, color = :white)
imgstack = []
imgstack = map(1:w) do i
    frame[] = i
    AbstractPlotting.update_limits!(scene)
    AbstractPlotting.update!(scene)
    imresize(Gray.(GLMakie.scene2image(scene)), h, h)
end
props = [:color_range=>2, :priv_data => ("crf"=>"0","preset"=>"medium")]
y = "cfr.mp4"
encodevideo(y,imgstack,framerate=30,AVCodecContextProperties=props)
f1, f2 = fs
fps1, fps2 = Millisecond(Second(1)) .÷ mss
run(`mp4fpsmod -r $f1:$fps1  -r $f2:$fps2 -o vfr.mp4 cfr.mp4`)
ffmpeg_exe(` -y -i vfr.mp4 -c copy -bsf:v h264_metadata=sample_aspect_ratio=0.5 testvideo.mp4`)

f = VideoIO.openvideo("testvideo.mp4")
pixelaspectratio = VideoIO.aspect_ratio(f)
@assert pixelaspectratio == 0.5

f = VideoIO.openvideo("testvideo.mp4")
ts2 = Millisecond[]
while !eof(f)
    read(f)
    l = gettime(f)
    push!(ts2, Millisecond(round(Int, 1000l)))
    # push!(ts2, Millisecond(1))
end
@assert ts2 == ts

rm("cfr.mp4")
rm("vfr.mp4")
