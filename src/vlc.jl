abstract type VLCBackend <: AbstractVideoBackend end

export VLCBackend

function play(::Type{VLCBackend}, f::VideoIO.AVInput; flipx = false, flipy = false, pixelaspectratio = VideoIO.aspect_ratio(f))

    mktemp() do name, io

        run(pipeline(`vlc --verbose=0 $opts $(f.io)`, stderr = io); wait=true)

        close(io)

    end

end

# avf = VideoIO.testvideo("annie_oakley")
#
# play(VLCBackend, VideoIO.openvideo(avf))
#
# mktemp() do name, io
#
#     run(pipeline(`vlc --verbose=0 $(avf.io)`, stderr = io); wait=true)
#
#     close(io)
#
# end
