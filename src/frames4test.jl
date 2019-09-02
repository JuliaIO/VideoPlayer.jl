using Makie, Dates, Observables, Printf, Images

mss = [Millisecond(25), Millisecond(125)]
t = Millisecond(Second(5))
fs = Int.(t./mss)
fs[end] += 1
Δt = vcat((fill(ms, f) for (ms, f) in zip(mss, fs))...)
Δt[1] = Millisecond(0)
ts = cumsum(Δt)
cd(tempdir())
dar = 2
w = length(ts)
h = dar*w
frame = Observable(1)
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
# poly!(scene, limits, color = :gray)
text!(scene, msg, position = (2, w), align = (:left,  :bottom))#, color = :white)
scatter!(scene, point, markersize = 10, marker = :+)#, color = :white)
for i in 1:w
    frame[] = i
    AbstractPlotting.update_limits!(scene)
    AbstractPlotting.update!(scene)
    fname = @sprintf "%03i.png" i
    save(fname, scene)
end
run(`mogrify -resize $(h)x$h\! "*".png`)
run(`ffmpeg -y -i %03d.png -pix_fmt yuv420p cfr.mp4`)
f1, f2 = fs
fps1, fps2 = Millisecond(Second(1)) .÷ mss
run(`mp4fpsmod -r $f1:$fps1  -r $f2:$fps2 -o vfr.mp4 cfr.mp4`)

using VideoIO
f = VideoIO.openvideo("/tmp/vfr.mp4")
# pixelaspectratio = VideoIO.aspect_ratio(f)
ts2 = Millisecond[]
while !eof(f)
    read(f)
    l = gettime(f)
    push!(ts2, Millisecond(round(Int, 1000l)))
end
