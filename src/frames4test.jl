using Makie, Dates, Observables, Printf, Images

# Two different frame-periods
mss = [Millisecond(25), Millisecond(125)]

# Normalization time
t = Millisecond(Second(5))

fs = Int.(t./mss)
fs[end] += 1
# Create a video with two "sections" of different framerates.
Δt = vcat((fill(ms, f) for (ms, f) in zip(mss, fs))...)
# start at time 0
Δt[1] = Millisecond(0)

# timestamps for frames
ts = cumsum(Δt)
cd(tempdir())

# Direct (?) aspect ratio
dar = 2
w = length(ts)
h = dar*w

frame = Observable(1) # framenumber

# define a point which we plot a scatter on
point = lift(frame) do fn
    [(fn, dar*fn)] # why?
end

# define a text string, which will be plotted.
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

# limits of the Scene
limits = FRect3D(Vec3f0(1, 2, 0), Vec3f0(w - 1, 2w - 2, 0))

scene = Scene(
        resolution = (w, h), 
        limits = limits,  
        scale_plot = false, 
        show_axis = false)
        #, padding=(0,0), backgroundcolor=:red
)

# poly!(scene, limits, color = :gray)

# plot the text, which indicates position and time
text!(scene, msg, position = (2, w), align = (:left,  :bottom))#, color = :white)
# plot the marker (to test mouse positioning)
scatter!(scene, point, markersize = 10, marker = :+)#, color = :white)

# We're not using Makie's recording framework - but we _could_ use a Stepper.
for i in 1:w
    frame[] = i
    AbstractPlotting.update_limits!(scene)
    AbstractPlotting.update!(scene)
    fname = @sprintf "%03i.png" i
    save(fname, scene)
end

# create a specific (and equal) SAR
run(`mogrify -resize $(h)x$h\! "*".png`)
# create an MP4 from the collection of images
run(`ffmpeg -y -i %03d.png -pix_fmt yuv420p cfr.mp4`) 

# framerates
f1, f2 = fs

# ?
fps1, fps2 = Millisecond(Second(1)) .÷ mss

# make the video VFR
run(`mp4fpsmod -r $f1:$fps1  -r $f2:$fps2 -o vfr.mp4 cfr.mp4`)

run(`ffmpeg -y -i vfr.mp4 -c copy -bsf:v h264_metadata=sample_aspect_ratio=0.5 testvideo.mp4`)


#=using VideoIO
f = VideoIO.openvideo("vfr2.mp4")
pixelaspectratio = VideoIO.aspect_ratio(f)

f = VideoIO.openvideo("cfr.mp4")

ts2 = Millisecond[]
while !eof(f)
    read(f)
    # l = gettime(f)
    # push!(ts2, Millisecond(round(Int, 1000l)))
    push!(ts2, Millisecond(1))
end
ts2=#



# here we create `n` frames in the form of individual images
using FileIO, Colors, Printf
n = 6
levels = UInt8.(range(0, stop = 255, length = n))
path = mktempdir()
img = Matrix{UInt8}(undef, 10, 10)
for (i, l) in enumerate(levels)
    name = @sprintf "%03i.jpg" i
    fill!(img, l)
    save(joinpath(path, name), img)
end

# here we convert these `n` images into a video
x = joinpath(path, "%03d.jpg")
y = joinpath(path, "out.mp4")
fps = 25
run(`ffmpeg -i $x -r $fps -pix_fmt gray $y`)

duration = n/fps
times = range(0, step = 1/fps, length = n + 1)
@assert duration == last(times)

# now let's see how many frames VideoIO thinks are in this video
# and what images "made it"
using VideoIO, Statistics
f = VideoIO.openvideo(y)
fn = 0
pix = Float64[]
times = Float64[]
while !eof(f)
    global fn
    img = read(f)
    push!(pix, mean(Gray.(img)))
    push!(times, gettime(f))
    fn += 1
end
@show fn # I get `n - 2` here
@show pix # I get [0.0, 0.2, 0.4, 0.6] So the last 2 are missing
@show sum(times)

duration = VideoIO.get_duration(f.avin.io)
run(`ffmpeg -i $y -f null -`)
