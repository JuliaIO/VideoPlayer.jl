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
timestamp = Observable(Time(0))

# reset the pointer to the begining of the file <-- there might be a more elegant way to achieve this
f = VideoIO.openvideo(testvideo)

# create a buffer of 2 seconds
nframesbuffer = round(Int, 2f.framerate)
buff = Channel{Pair{Time, typeof(img[])}}(nframesbuffer)
# fill up the buffer with the next 15 seconds worth of frames
task = @async begin
    while !eof(f)
        t = Time(0) + Millisecond(round(Int, 1000gettime(f)))
        put!(buff, Pair(t, read(f)))
        yield() # needed 
    end
end

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
old_slider_pos = Observable(1)

# get an estimate for the number of frames, this could be very innacurate for VFR videos
nframes = round(Int, VideoIO.get_duration(f.avin.io)*f.framerate)

# the slider, updating currentframe and getting its string from timestamps
slider_h = slider!(rsc(), 1:nframes, start = 1, valueprinter = i -> "no, this will be wrong", textcolor = :white)
lift(slider_h[end][:value]) do frame
    while old_slider_pos[] ≤ frame
        timestamp[], img[] = take!(buff)
        old_slider_pos[] += 1
    end
    0
    # currentframe[] = frame
end

# this is for a separate display of the time stamp, due to the fact that we can not calculate with the time stamp is from the frame number (which is what the slider has)
timestamp_h = text!(rsc(), lift(string, timestamp), color = :white)

# I have to have a forward button becuase apparently the stuff in the lift gets evaluated, so to have the movie start in frame #1 I need to go forward once and the backwards...
fwdbutton = button!(rsc(), ">", textcolor = :white)
lift(fwdbutton[end][:clicks]) do _
    # if currentframe[] < nframes # check we are not in the last frame
    timestamp[], img[] = take!(buff)
    slider_h[end][:value][] += 1 
        # so now the movie is in frame #2
    # end
    0
end
#=bckbutton = button!(rsc(), "<", textcolor = :white)
lift(bckbutton[end][:clicks]) do _
    if currentframe[] > 1 # check we're not in frame #1
        currentframe[] -= 1
        slider_h[end][:value][] -= 1
        # and now we're back in frame #1
    end
    0
end=#

# done!
hbox(vbox(slider_h, fwdbutton, timestamp_h), scene)


