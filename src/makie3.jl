using Makie, VideoIO, Dates, Observables

include("testvideo.jl")

# create the test video if it doesn't exist
testvideo = joinpath(tempdir(), "test.mp4")
if !isfile(testvideo)
    createtestvideo(testvideo)
end

# open the video
f = VideoIO.openvideo(testvideo)

# read one image to get its type <-- this might be unecessary since we might know that in advance for all videos
img = Observable(read(f))

# get an estimate for the number of frames, I'm over-shooting here to be sure we have enough space for them
nframes = 2round(Int, VideoIO.get_duration(f.avin.io)/Microsecond(Second(1))*f.framerate)

# prepare the holders for the frames and the time-stamps
frames = Vector{typeof(img[])}()#Vector{tyepof(img[])}(undef, nframes)
timestamps = String[]#Vector{String}(undef, nframes)
sizehint!(frames, nframes)
sizehint!(timestamps, nframes)

# reset the pointer to the begining of the file <-- there might be a more elegant way to achieve this
f = VideoIO.openvideo(testvideo)

# load up the WHOLE video to memory and get the corresponding time-stamps
while !eof(f)
    push!(frames, read(f))
    # note that I'm saving the time stamps as strings, cause that's all we care about right now, might change later
    t = Time(0) + Millisecond(round(Int, 1000gettime(f)))
    push!(timestamps, string(t))
end

# get the actual number of frames (needed actually later)
nframes = length(timestamps)

# all the stuff needed for display
pixelaspectratio = VideoIO.aspect_ratio(f)
h = f.height
w = round(typeof(h), f.width * pixelaspectratio)
rsc() = Scene(;camera = campixel!, raw = true, backgroundcolor = :black)
scene = Scene(resolution = (w, h), backgroundcolor = :black)
Makie.image!(scene, 1:h, 1:w, img, show_axis = false, scale_plot = false)
Makie.rotate!(scene, -0.5π)
update_limits!(scene)
update_cam!(scene)
update!(scene)

# everything starts at this observable, the current frame
currentframe = Observable(1)

# it controls which frame is displayed
lift(currentframe) do i
    img[] = frames[i]
end

# the slider, updating currentframe and getting its string from timestamps
slider_h = slider!(rsc(), 1:length(timestamps), start = 1, valueprinter = i -> timestamps[i], textcolor = :white)
lift(slider_h[end][:value]) do i
    currentframe[] = i
end

# I have to have a forward button becuase apparently the stuff in the lift gets evaluated, so to have the movie start in frame #1 I need to go forward once and the backwards...
fwdbutton = button!(rsc(), ">", textcolor = :white)
lift(fwdbutton[end][:clicks]) do _
    if currentframe[] < nframes # check we are not in the last frame
        currentframe[] += 1
        slider_h[end][:value][] += 1 
        # so now the movie is in frame #2
    end
    0
end
bckbutton = button!(rsc(), "<", textcolor = :white)
lift(bckbutton[end][:clicks]) do _
    if currentframe[] > 1 # check we're not in frame #1
        currentframe[] -= 1
        slider_h[end][:value][] -= 1
        # and now we're back in frame #1
    end
    0
end

# done!
hbox(vbox(bckbutton, slider_h, fwdbutton), scene)



