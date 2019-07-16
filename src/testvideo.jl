function createtestvideo(filename; w = 300, h = 300, fps = 25, totalseconds = 10)
    totalframes = fps*totalseconds
    Δt = Millisecond(Second(1))/fps
    framenumber = Observable(1)
    msg = lift(framenumber) do fn
        t = Time(0) + (fn - 1)*Δt
        """
        Test video
        Frame #: $fn
        Time: $t"""
    end
    scene = Scene(resolution = (w, h), backgroundcolor = :black)
    text!(scene, msg, color = :black)
    # scene
    record(scene, filename, 1:totalframes, framerate = fps) do i
        framenumber[] = i
    end
end
