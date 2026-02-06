module Jude

using Waveforms, PortAudio

const bpm = Ref{Float64}(120.0)
const spf = Ref{Int}(256)
const fs  = Ref{Int}(44100)

const running = Ref(true)
global stream::PortAudioStream

# ============================================================
# Utilities
# ============================================================
export beats2samples

"""
Convert a number of beats to the number of frames (audio buffer time).
"""
function beats2samples(beats)
    floor(beats * (60 / Jude.bpm[]) * Jude.fs[] / Jude.spf[])
end


# ============================================================
# Sequence abstraction
# ============================================================
export AbstractSequence, Sequence, query!

abstract type AbstractSequence end

"""
A time-indexed audio generator.

map!(buf, t) writes the audio for frame t into buf.
"""
struct Sequence <: AbstractSequence
    t₁::Int          # start frame
    T::Float64       # loop length in frames (a float so can handle Inf)
    map!::Function   # (buf, t) -> nothing

    function Sequence(map::Function, t₁_beats, T_beats)

        t₁ = beats2samples(t₁_beats-1) + 1
        T = beats2samples(T_beats)

        new(t₁, T, map)
    end
end

Sequence(map!::Function) =
    Sequence(map!, 1, Inf)

"""
Query a sequence at time t
"""
function query!(buf::Vector{Float32}, seq::Sequence, t::Int)
    mod_t = 1 +  round(Int, (t - 1) % seq.T)
    if mod_t ≥ seq.t₁
        seq.map!(buf, mod_t - seq.t₁ + 1)
    end
    return nothing
end

# ============================================================
# Sample playback
# ============================================================
export Sample, sound!

struct Sample
    data::Vector{Float32}
    T::Int
end

Sample(data::Vector{Float32}) =
    Sample(data, ceil(Int, length(data) / Jude.spf[]))

"""
Accumulate frame t of sample into buf.
"""
function sound!(buf::Vector{Float32}, sample::Sample, t::Int)
    start_idx = 1 + (t - 1) * Jude.spf[]
    end_idx   = min(t * Jude.spf[], length(sample.data))
    start_idx > length(sample.data) && return nothing

    @inbounds buf[1:(end_idx - start_idx + 1)] .+= sample.data[start_idx:end_idx]
    return nothing
end

# ============================================================
# Internal helpers
# ============================================================

_seq(sample, beat, len) =
    Sequence(1 + beat, len) do buf, t
        sound!(buf, sample, t)
    end


# ============================================================
# Macros
# ============================================================
export @setup, @stop, @sum
"""
    @setup

Import core packages and define global audio parameters.
"""
macro setup(args...)
    bpm_expr = nothing
    for arg in args
        if arg isa Expr && arg.head === :(=) && arg.args[1] === :bpm
            bpm_expr = esc(arg.args[2])
        end
    end

    quote
        # Update bpm at runtime
        $(bpm_expr === nothing ? nothing : :(Jude.bpm[] = $bpm_expr))

        # Initialize audio stream at runtime
        Jude.stream = PortAudioStream(0, 1; samplerate=Jude.fs[])

        # Mark running as true
        Jude.running[] = true
    end
end

macro stop()
    quote
        Jude.running[] = false
        close(Jude.stream)
        println("Audio stream stopped.")
    end
end

"""
Combine multiple sequences by summing their outputs.
"""
macro sum(seqs...)
    seqs_esc = esc.(seqs)
    calls = [:(query!(buf, $s, t)) for s in seqs_esc]
    quote
        Sequence() do buf, t
            $(Expr(:block, calls...))
        end
    end
end

end # module Jude
