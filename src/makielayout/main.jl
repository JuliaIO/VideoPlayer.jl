using AbstractPlotting, GLMakie, MakieLayout, VideoIO, Dates

function step!(f, buff, img)
    read!(f, buff)
    img[] = rotr90(buff)
end

function videoexplorer(file)
    # open video
    f = VideoIO.openvideo(file)

    # some stats about the video
    pixelaspectratio = VideoIO.aspect_ratio(f)
    h = f.height
    w = round(typeof(h), f.width*pixelaspectratio)
    duration = VideoIO.get_duration(unsafe_load(f.avin.apFormatContext[1]))
    fr = 1/f.framerate

    # prepare observables
    buff = read(f)
    img = Node(rotr90(buff))
    ct = Node("00:00:00.000")
    cc = Node("-")

    # build player
    h_control = 0.1 # relative height of the controlers
    scene, layout = layoutscene(0, resolution = (Float64(w), h/(1 - h_control)), backgroundcolor = :yellow)
    ax = layout[1, 1:5] = LAxis(scene, aspect = DataAspect(), backgroundcolor = :yellow)
    layout[2, 1] = LText(scene, ct, textsize = 30, color = :white)
    cl = layout[2, 2] = LText(scene, cc, textsize = 30, color = :white)
    sl = layout[2, 3] = LSlider(scene, range = range(0, stop = duration, length = 100), startvalue = 0)

    # slider seeks
    on(sl.value) do t
        seek(f, t)
        step!(f, buff, img)
    end

    # button steps one frame forward
    bt = layout[2,4] = LButton(scene, label = "⊵")
    on(bt.clicks) do _
        step!(f, buff, img)
    end

    # this is the mechanism for the play functionality
    # I'm using a channel as a means to indicate if the 
    # video should play or not.
    # The channel contains an arbitrary boolean value
    c = Channel{Bool}(1)
    # and is asynchronously consumed by the playing.
    @async for _ in c
        step!(f, buff, img)
        sleep(fr)
        put!(c, true) # here I put a value back so it'll keep on playing
    end

    # the toggle button for the playing
    pl = layout[2,5] = LToggle(scene)
    on(pl.active) do p
        if p
            put!(c, true) # if it's true then it puts a value in the channel which triggers the loop above
        else
            take!(c) # if not, it takes a value which pauses the loop. THIS BREAKS THE WHOLE THING
        end
    end

    # display the frame
    imgplot = image!(ax, 1:w, 1:h, img)

    # just layout stuff
    rowsize!(layout, 1, Relative(1 - h_control))
    rowsize!(layout, 2, Relative(h_control))
    colsize!(layout, 1, Relative(0.2))
    colsize!(layout, 2, Relative(0.2))
    hidedecorations!(ax)
    tightlimits!(ax)

    # show current time stamp
    on(img) do _
        t = VideoIO.gettime(f)
        ct[] = string(Time(0) + Millisecond(round(Int, 1000t)))
    end

    # some mouse interactions
    mousestate = addmousestate!(ax.scene, imgplot)
    onmouseover(mousestate) do state
        coordinate = round.(Int, state.pos)
        cc[] = string(coordinate)
    end
    onmouseout(mousestate) do state
        cc[] = "-"
    end
    onmouseleftclick(mousestate) do state
        @async begin
            cl.color[] = :red
            sleep(2)
            cl.color[] = :white
        end
    end

    scene
end
