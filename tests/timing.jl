using PortAudio, Statistics

fs = 44100
n = 256                     # frames per callback

max_callbacks = 2000
timestamps = Vector{Float64}(undef, max_callbacks)
idx = Ref(1)
last_t = Ref(time())


function cb(_, outbuf, nframes, framepos)
    t = time()
    i = idx[]
    if i ≤ max_callbacks
        timestamps[i] = t - last_t[]
        idx[] = i + 1
    end
    last_t[] = t
    fill!(outbuf, 0f0)
    return nframes
end

stream = PortAudioStream(cb;
    input_channels=0,
    output_channels=1,
    samplerate=fs,
    frames_per_buffer=n)

start(stream)
sleep(5)                    # run for a few seconds
close(stream)

Δt = timestamps[2:idx[]-1]
@show mean(Δt)
@show std(Δt)