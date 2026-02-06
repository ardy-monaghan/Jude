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
export beats2frames, beats2samples

"""
Convert a number of beats to the number of frames (audio buffer time).
"""
function beats2frames(beats)
    floor(beats * (60 / Jude.bpm[]) * Jude.fs[] / Jude.spf[])
end

"""
Convert a number of beats to the number of samples 
"""
function beats2samples(beats)
    floor(beats * (60 / Jude.bpm[]) * Jude.fs[])
end

nt = Dict([(:a3=>440.0), (:e3=>660.0)])

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

        t₁ = beats2frames(t₁_beats-1) + 1
        T = beats2frames(T_beats)

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

function sound!(buf::Vector{Float32}, wavefunction::Function, note_name::Symbol, note_dur, t::Int)

    note_dur_samples = ceil(Int, beats2samples(note_dur))
    start_idx = 1 + (t - 1) * Jude.spf[]
    end_idx   = min(t * Jude.spf[], note_dur_samples)
    start_idx > note_dur_samples && return nothing

    for (i, tᵢ) in enumerate(start_idx:end_idx)
        buf[i] += 0.1 * wavefunction(2π * (Jude.nt[note_name] / Jude.fs[]) .* (tᵢ-1))
    end
    return nothing
end

# ============================================================
# Synth generation playback
# ============================================================




# ============================================================
# Internal helpers
# ============================================================
_seq(sample, beat, len) =
    Sequence(1 + beat, len) do buf, t
        sound!(buf, sample, t)
    end

_seq(wavefunction, note_name, note_dur, beat, len) =
    Sequence(1 + beat, len) do buf, t
        sound!(buf, wavefunction, note_name, note_dur, t)
    end

# ============================================================
# Buffer initialisation
# ============================================================
buf_seq = Ref{Sequence}()

# ============================================================
# Macros
# ============================================================
export @setup, @stop, @sum, @seq, @mix, @synth
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

        # Buffer variables
        buf = zeros(Float32, Jude.spf[])
        Jude.buf_seq[] = Sequence() do buf, t
            fill!(buf, 0.0f0)
        end

        @async begin
            t = 0
            while Jude.running[]
                fill!(buf, 0f0)
                Base.invokelatest(query!, buf, Jude.buf_seq[], t)
                write(Jude.stream, buf)
                t += 1
            end
        end

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


"""
Create one or more sequences from a sample.

Usage:
    @seq samp at=0 len=4
    @seq samp at=(0, 1/2) len=4
"""
macro seq(sample, args...)
    sample = esc(sample)
    at_expr  = nothing
    len_expr = nothing

    for arg in args
        if arg isa Expr && arg.head === :(=)
            k, v = arg.args
            k === :at  && (at_expr  = v)
            k === :len && (len_expr = esc(v))
        end
    end

    at_expr === nothing  && error("@seq requires at=")
    len_expr === nothing && error("@seq requires len=")

    if !(at_expr isa Expr && at_expr.head === :tuple)
        return :(_seq($sample, $(esc(at_expr)), $len_expr))
    end

    seqs = [:(_seq($sample, $(esc(b)), $len_expr)) for b in at_expr.args]
    Expr(:macrocall, Symbol("@sum"), __source__, seqs...)
end

"""
Create one or more sequences from a synth signal.

Usage:
    @synth sin at=(0|a3|2) len=4
    @synth sin at=(0|a3|2, 2|e3|1) len=4
"""
macro synth(wavefn, args...)
    at  = nothing
    len = nothing

    for arg in args
        if arg isa Expr && arg.head === :(=)
            if arg.args[1] === :at
                at = arg.args[2]
            elseif arg.args[1] === :len
                len = arg.args[2]
            end
        end
    end

    at === nothing  && error("@synth requires at=...")
    len === nothing && error("@synth requires len=...")

    entries =
        at isa Expr && at.head === :tuple ? at.args :
        (at,)

    seqs = map(entries) do ex
        # expect offset | note | dur
        ex isa Expr && ex.head === :call && ex.args[1] === :| ||
            error("@synth expects offset|note|dur")

        left, dur = ex.args[2], ex.args[3]

        left isa Expr && left.head === :call && left.args[1] === :| ||
            error("@synth expects offset|note|dur")

        offset, note = left.args[2], left.args[3]

        :(_seq(
            $(esc(wavefn)),
            $(esc(note)),
            $(esc(dur)),
            $(esc(offset)),
            $(esc(len))
        ))
    end

    if length(seqs) == 1
        return seqs[1]
    else
        return Expr(:macrocall, Symbol("@sum"), __source__, seqs...)
    end
end

# macro synth(wavefunction, args...)

#     function parse_synth_atom(ex)
#         ex isa Expr && ex.head === :call && ex.args[1] === :| ||
#             error("@synth expects entries of the form offset|note|dur")

#         left, dur = ex.args[2], ex.args[3]

#         left isa Expr && left.head === :call && left.args[1] === :| ||
#             error("@synth expects offset|note|dur")

#         offset, note = left.args[2], left.args[3]

#         return offset, note, dur
#     end

#     wavefunction = esc(wavefunction)
#     at_expr  = nothing
#     len_expr = nothing

#     for arg in args
#         if arg isa Expr && arg.head === :(=)
#             k, v = arg.args
#             k === :at  && (at_expr  = v)
#             k === :len && (len_expr = esc(v))
#         end
#     end

#     at_expr === nothing  && error("@seq requires at=")
#     len_expr === nothing && error("@seq requires len=")

#     if !(at_expr isa Expr && at_expr.head === :tuple)
#         return :(_seq($wavefunction, $(esc(at_expr)), $len_expr))
#     end

#     seqs = [:(_seq($wavefunction, $(esc(b)), $len_expr)) for b in at_expr.args]
#     Expr(:macrocall, Symbol("@sum"), __source__, seqs...)
# end


"""
Assign sequences to buf_seq[] (live sequence).

- Single sequence: assigned directly
- Multiple: summed with @sum
"""
macro mix(args...)
    # If called as @mix(a, b, c) → args = (:(a, b, c),)
    if length(args) == 1 && args[1] isa Expr && args[1].head === :tuple
        args = args[1].args
    end


    if length(args) == 1
        return :(Jude.buf_seq[] = $(esc(args[1])))
    else
        return :(Jude.buf_seq[] =
            $(Expr(:macrocall, Symbol("@sum"), __source__, esc.(args)...)))
    end
end

end # module Jude
