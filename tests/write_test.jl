using PortAudio, Statistics, Waveforms, WAV, HTTP

n = 256*24
running = Ref(true)
stream = PortAudioStream(0, 1; samplerate=44100)

times = zeros(Float64, 2000)
idx = Ref(1)    
max_callbacks = length(times)

freq = Ref(440.0)

# mutable struct Sample



# end

# Do cycles per minute

#  {:bd :sn} is a cycle
#  {:bh :cp} is another cycle -- if we wanted to combine them we would do
#  {{:bd :sn} {:bh :cp}} 
#  each sequence defines a 


# Maybe also nice to work with samples...

# A sequence is just a vector with a length, a unit-converter, timestamp, and a state.
    # You give it a time, and it will tell you the output at that time.
    # The unit-converter converted from frame time (our discrete time) to whatever time the sequence is in.

# Try and make everything a sequence -- i.e. the freq could be a sequence (normally it would just be the constant sequence)
    # 

# Vector of live samples
    # Each sound is a function which takes in a freq and outputs a sample
    # Effectively a waveform mulitplied by an envelope

# Vector of sequences
    # Each sequence is just a set containing which beat to add a sound to the live samples, and that sample. Then there is an index that loops to keep re-adding.

# Loop over all sequences
    # If at beat, push that sound into live sample



# 1) Define all samples
# 2) Define a sequence
    #  s = :hh -> every 2 beats
# 3) If we change a seq i.e. make it every 4 beats, we want to remove it from the live sequence and replace it -- but don't want to miss a beat or say we add a lpf.

# 




# file_location = "https://github.com/tidalcycles/Dirt-Samples/tree/master/808bd/BD0000.WAV"
# y, fs = wavread(file_location)

# download audio data from GitHub
url = "https://github.com/tidalcycles/Dirt-Samples/raw/refs/heads/master/808bd/BD0000.WAV"
data = HTTP.get(url).body

# load WAV from memory
io = IOBuffer(data)
y, fs = wavread(io)


##
using PortAudio, Statistics, Waveforms, WAV, HTTP

n = 256*24
running = Ref(true)
stream = PortAudioStream(0, 1; samplerate=44100)

##
const _generate_ref = Ref{Function}()

##
function generate_buf(n)
    return  squarewave.(2π * (880 / 44100) * (0:n-1)) .* 0.2
end


##
_generate_ref[] = generate_buf()


##
@async begin
    frame_count = 0 
    buf = zeros(Float32, n)
    last_t = time()

    while running[]

        write(stream, buf)

        frame_count += 1

        if frame_count % 20 == 0
            # buf = _generate_ref[](y)
            # buf = @invokelatest generate_buf(n)
            
        else 
            buf = zeros(Float32, n)
        end

    end
end

##
running[] = false
close(stream)

# Δt = times[2:end-1]
# @show mean(Δt)
# @show std(Δt)


##
using PortAudio, Statistics, Waveforms, WAV, HTTP

n = 256*24
running = Ref(true)
stream = PortAudioStream(0, 1; samplerate=44100)

const _generate_ref = Ref{Function}()

function generate_buf_v1(n)
    squarewave.(2π * (440 / 44100) .* (0:n-1)) .* 0.2
end

_generate_ref[] = generate_buf_v1

function generate_buf_v2(n)
    squarewave.(2π * (880 / 44100) .* (0:n-1)) .* 0.2
end

##

function generate_buf_v3(n)
    squarewave.(2π * (1100 / 44100) .* (0:n-1)) .* 0.2
end

##

function generate_buf_v5(n)
    squarewave.(2π * (2200 / 44100) .* (0:n-1)) .* 0.2
end

##
@async begin
    frame_count = 0 
    buf = zeros(Float32, n)
    last_t = time()

    while running[]

        write(stream, buf)

        frame_count += 1

        if frame_count % 20 == 0
            # buf = _generate_ref[](y)
            # buf = @invokelatest generate_buf(n)
            buf = _generate_ref[](n)
        else 
            buf = zeros(Float32, n)
        end

    end
end

##
running[] = false
close(stream)

# Δt = times[2:end-1]
# @show mean(Δt)
# @show std(Δt)


