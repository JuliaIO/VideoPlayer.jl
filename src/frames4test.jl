using Makie, Dates, Observables, Printf, Images

2,4,3,5

for i in [2,5,8,125]
    j = Int(1000/i)
    @show Int(60/j)
end

2, 5

frs = [20, 10, 5]
ti = 5
Δts = []
for fr in frs, Δt in 1:fr*ti
    push!(Δts,  

fr1 = 30
fr2 = 15
fr3 = 5

t = 5
n1 = fr1*t
n2 = fr2*t
n3 = fr3*t



tosecond(x::T) where {T} = x/convert(T, Second(1))

cd(tempdir())
dar = 2
w = 200
h = dar*w
# Δt = collect(Iterators.repeated(Millisecond(33), w - 1))
Δt = Millisecond(33):oneunit(Millisecond):Millisecond(w + 31)
ts = [Millisecond(0); cumsum(Δt)]
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

limits = FRect3D(Vec3f0(1, 2, 0), Vec3f0(w - 1, 2w - 2, 0))

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
run(`ffmpeg -y -i %03d.png -pix_fmt yuv420p ffmpeg-cfr.mp4`)
open("timecodes.txt", "w") do io
    println(io, "# timecode format v2")
    for t in ts
        println(io, string(Dates.value(t)))
    end
end
run(`mp4fpsmod -o vfr.mp4 -t timecodes.txt ffmpeg-cfr.mp4`)

# run(`ffmpeg -y -i vfr1.mp4 -vf setdar=dar=1/$dar vfr.mp4`)

#=open("timecodes.txt", "w") do io
    for (Δ, i) in zip(Δt, 1:w)
        fname = @sprintf "%03i.png" i
        duration = tosecond(Δ)
        println(io, "file '$fname'")
        println(io, "duration $duration")
    end
    i = w
    fname = @sprintf "%03i.png" i
    println(io, "file '$fname'")
end=#

# run(`ffmpeg -y -safe 0 -f concat -i timecodes.txt -segment_time_metadata 1 -vf setdar=dar=1/$dar -vsync vfr -copyts testvideo.mp4`)

# run(`ffmpeg -y -f concat -i timecodes.txt -vf setdar=dar=1/$dar -vsync 0 testvideo.mp4`)

using VideoIO
f = VideoIO.openvideo("/tmp/vfr.mp4")
# pixelaspectratio = VideoIO.aspect_ratio(f)
ts2 = Millisecond[]
while !eof(f)
    read(f)
    l = gettime(f)
    push!(ts2, Millisecond(round(Int, 1000l)))
end

using VideoIO, Dates
vf = download("https://s3.eu-central-1.amazonaws.com/vision-group-file-sharing/Data%20backup%20and%20storage/Yakir/vfr1.mp4")
f = VideoIO.openvideo(vf)
ts = Millisecond[]
while !eof(f)
    read(f)
    t = gettime(f)
    push!(ts, Millisecond(round(Int, 1000t)))
end



run(`mp4fpsmod -r 30:1 -r 0:2 -o vfr.mp4 ffmpeg-cfr.mp4`)
