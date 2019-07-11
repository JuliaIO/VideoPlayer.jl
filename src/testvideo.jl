using Makie, FFMPEG, Observables, Dates

w = 200
h = 100
fps = 25
totalseconds = 10

totalframes = fps*totalseconds
Δt = Millisecond(Second(1))/fps
framenumber = Observable(1)
msg = lift(framenumber) do fn
    t = Time(0) + fn*Δt
    """
Test video
Frame #: $fn
Time: $t"""
end
scene = Scene(resolution = (w, h), backgroundcolor = :black)
text!(scene, msg, color = :white)
scene

record(scene, "test.mp4", 1:totalframes, framerate = fps) do i
    framenumber[] = i
end
