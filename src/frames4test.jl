using Makie, Dates, Observables, Printf

tosecond(x::T) where {T} = x/convert(T, Second(1))

cd(tempdir())
dar = 2
w = 200
h = dar*w
Δt = Millisecond(1):oneunit(Millisecond):Millisecond(w)
ts = cumsum(Δt)
# totaltime = ts[end]
frame = Observable(1)
point = lift(frame) do fn
    [(fn, 2fn)]
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
limits = FRect(1, 2, w - 1, 2w - 2)
scene = Scene(resolution = (w, h), limits = limits,  scale_plot = false, show_axis = false)#, padding=(0,0), backgroundcolor=:red)
poly!(scene, limits, color = :gray)
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
open("timecodes.txt", "w") do io
    for (Δ, i) in zip(Δt, 1:w)
        fname = @sprintf "%03i.png" i
        duration = tosecond(Δ)
        println(io, "file '$fname'")
        println(io, "duration $duration")
    end
    i = w
    fname = @sprintf "%03i.png" i
    println(io, "file '$fname'")
end

run(`ffmpeg -y -safe 0 -f concat -i timecodes.txt -segment_time_metadata 1 -vf setdar=dar=1/$dar -vsync vfr -copyts testvideo.mp4`)

run(`ffmpeg -y -f concat -i timecodes.txt -vf setdar=dar=1/$dar -vsync 0 testvideo.mp4`)

using VideoIO
f = VideoIO.openvideo("/tmp/testvideo.mp4")
pixelaspectratio = VideoIO.aspect_ratio(f)
l = gettime(f)
while !eof(f)
    global l
    read(f)
    n = gettime(f)
    x = n - l
    @show x
    l = n
end

