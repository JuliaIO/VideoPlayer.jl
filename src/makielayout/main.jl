using AbstractPlotting, GLMakie, MakieLayout, VideoIO, Dates, Observables



file = "a.mp4"
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


@enum MovieState begin
    PAUSE
    PLAY
    STEP
end

const FRAME_CHANNEL = Channel{typeof(rotr90(buff))}(1) # could buffer frames?
const STATE_CHANNEL = Channel{MovieState}(1)

push!(STATE_CHANNEL, PAUSE)

function movie_controller()
    state = PAUSE
    while true
        if isready(STATE_CHANNEL)
            state = take!(STATE_CHANNEL)
            while state == PAUSE
                state = take!(STATE_CHANNEL)
            end
        end
        frame = take!(FRAME_CHANNEL)
        img[] = frame
        if state == PLAY
            sleep(fr)
        elseif state == STEP
            push!(STATE_CHANNEL, PAUSE)
        else
            @warn state
        end
    end
end

function frame_producer()
    while true
        read!(f, buff)
        v = rotr90(buff)
        push!(FRAME_CHANNEL, v)
    end
end

@async movie_controller()
@async frame_producer()


h_control = 0.1 # relative height of the controlers
scene, layout = layoutscene(0, resolution = (Float64(w), h/(1 - h_control)), backgroundcolor = :yellow)
ax = layout[1, 1:5] = LAxis(scene, aspect = DataAspect(), backgroundcolor = :yellow)
layout[2, 1] = LText(scene, ct, textsize = 30, color = :white)
cl = layout[2, 2] = LText(scene, cc, textsize = 30, color = :white)
sl = layout[2, 3] = LSlider(scene, range = range(0, stop = duration, length = min(1000, round(Int, duration/fr))), startvalue = 0)

# slider seeks
sl2 = async_latest(sl.value, 1)
# sl2 = sl.value
on(sl2) do t
    take!(FRAME_CHANNEL)
    seek(f, t)
    push!(STATE_CHANNEL, STEP)
    # stepone!(f, buff, img)
end

# button stepone one frame forward
bt = layout[2,4] = LButton(scene, label = "⊵")
on(bt.clicks) do _
    # stepone!(f, buff, img)
    push!(STATE_CHANNEL, STEP)
end



# the toggle button for the playing
pl = layout[2, 5] = LToggle(scene)
on(pl.active) do p
    push!(STATE_CHANNEL, p ? PLAY : PAUSE)
end

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




