using PortAudio, Statistics, Waveforms, WAV, HTTP

@kwdef mutable struct Metronome
    bpm::Float64 = 60.0 # beats per minute
    sps::Float64 = 44100.0 # sampling frequency
    spf::Int = 256 # samples per frame
    fpb::Int64
end

function Metronome(; bpm::Float64=60.0, sps::Float64=44100.0, spf::Int=256)
    fpb = floor(Int, (sps / spf) * (60  / bpm))
    return Metronome(bpm, sps, spf, fpb)
end

mutable struct Sequence
    nf::Int
    fpb::Int
    events::Vector{Symbol}
end

function Sequence(events::Vector{Symbol}, met::Metronome, nb::Int=1)

    # num_frames(nf) = num_beats(nb) * (frames per beat) 
    nf = nb * met.fpb

    return Sequence(nf, met.fpb, events)
end


abstract type Modulations end

mutable struct Sample
    y::Float32
    idx::Int
    t₁::Int
    t₂::Int
    mod::Vector{<:Modulations}
end

mutable struct Permutation
end

function iterate_sequence(seq::Sequence, frame_count::Int)

    # Current frame in the sequence
    cf = mod(frame_count, seq.nf) + 1

    # Check if we are at an event
    if mod(cf, seq.fpb) == 0
        beat_idx = div(cf - 1, seq.fpb) + 1
        if beat_idx <= length(seq.events)
            return seq.events[beat_idx]
        end
    end

    return :rest
end

met = Metronome()

running = Ref(true)

freq = Ref(440.0)

sequences = Vector{Sequence}()

push!(sequences, Sequence([:hh], met, 1))

fs= 44100.0 # sampling frequency
spf = 256
stream = PortAudioStream(0, 1; samplerate=fs)


# Waveforms should be a sequence of note lengths -- then the underlying patterns should be the notes and so forth
# [1, 1, 2]
# sin 
#  - 100f
#  - [a, e, d]
#  - lfc
#  - reverb

# Begin audio stream in a separate task
@async begin

    # Initialise the frame count
    frame_count = 0 
   
    # Initialise the buffer
    buf = zeros(Float32, spf)

    # Check running flag
    while running[]

        # Empty the buffer
        fill!(buf, 0f0)

        # Loop over queued sequences
        #   Wait till first beat then push to live sequences

        # # Loop over every sequence
        # for seq in sequences

        #     # Iterate sequence
            
        # end

        # Loop over every alive sample
            # These all need to be frame dependent i.e. for glitchy stuff or just any internal permutations
 
        if frame_count % 20 == 0
            buf = squarewave.(2π * (freq[] / fs) * (0:spf-1)) .* 0.2
        end

        write(stream, buf)

        # Index the frame count
        frame_count += 1
    end
end

## Stop the audio stream
running[] = false
close(stream)