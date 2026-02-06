using Waveforms, PortAudio

global const bpm = Ref{Float64}(120.0)
global const spf = Ref{Int64}(256)
global const fs = Ref{Int64}(44100)

function beats2samples(beats)
    return floor(beats * (60 / bpm[]) * fs[] / spf[])
end

abstract type AbstractSequence end

struct Sequence <: AbstractSequence
    t₁::Int64
    T::Float64
    map::Function 

    function Sequence(t₁_beats, T_beats, map::Function)

        t₁ = beats2samples(t₁_beats-1) + 1
        T = beats2samples(T_beats)

        new(t₁, T, map)
    end
end

function Sequence(map::Function)
    return Sequence(1, Inf, map)
end


function query(seq::Sequence, t::Int64)

    mod_t = 1 + round(Int, (t - 1) % seq.T)

    if mod_t ≥ seq.t₁
        rel_t = mod_t - seq.t₁ + 1

        
        return seq.map(rel_t)
    end

    return zeros(Float32, spf[])
end

(seq::Sequence)(t) = query(seq, t)

struct Sample
    data::Union{Vector{Float32}, Vector{Float64}}
    T::Int64
end

function Sample(data::Vector{Float32})
    return Sample(data, ceil(Int64, length(data) / spf[]))
end

function sound!(sample::Sample, tᵢ::Int64)

    start_idx = 1 + (tᵢ - 1) * spf[]
    end_idx = min(tᵢ * spf[], length(sample.data))

    if start_idx > length(sample.data)
        return zeros(Float32, spf[])
    end

    buf = zeros(Float32, spf[])
    buf[1:(end_idx - start_idx + 1)] .= sample.data[start_idx:end_idx]

    return buf

end


"""
    _seq(sample, beat, len)

Construct a Sequence starting at `beat` (in beats),
lasting `len` beats, playing `sample`.
"""
_seq(sample, beat, len) =
    Sequence(1 + beat, len, t -> sound!(sample, t))


y = squarewave.(2π * (440 / fs[]) .* (0:10_000)) .* 0.1
samp = Sample(y)

"""
    @sum seq1 seq2 ...

Combine sequences by summing their outputs pointwise in time.
"""
macro sum(seqs...)
    seqs_esc = esc.(seqs)

    body = reduce((a, b) -> :($a + $b),
                  [:( $s(t) ) for s in seqs_esc])

    return quote
        Sequence(t -> $body)
    end
end

"""
    @seq sample at=... len=...

Create one or more Sequences from `sample`.

Examples:
    @seq samp at=0 len=4
    @seq samp at=(0, 1/2) len=4
"""
macro seq(sample, args...)
    sample = esc(sample)

    at_expr  = nothing
    len_expr = nothing

    # -------------------------
    # Parse keyword arguments
    # -------------------------
    for arg in args
        if arg isa Expr && arg.head == :(=)
            key, val = arg.args
            if key === :at
                at_expr = val        
            elseif key === :len
                len_expr = esc(val)
            else
                error("Unknown keyword `$key` in @seq")
            end
        else
            error("Arguments to @seq must be keyword-style")
        end
    end

    at_expr === nothing  && error("@seq requires `at=`")
    len_expr === nothing && error("@seq requires `len=`")

    # -------------------------
    # Case 1: single beat
    # -------------------------
    if !(at_expr isa Expr && at_expr.head === :tuple)
        return :(_seq($sample, $(esc(at_expr)), $len_expr))
    end

    # -------------------------
    # Case 2: multiple beats → sum
    # -------------------------
    seqs = [
        :(_seq($sample, $(esc(b)), $len_expr))
        for b in at_expr.args
    ]

    return Expr(:macrocall, Symbol("@sum"), __source__, seqs...)
end

"""
    @jude seq1 [seq2 seq3 ...]

Assign sequences to `buf_seq[]`.

- Single argument: assigns directly
- Multiple arguments: assigns the sum via @sum
"""
macro jude(seqs...)
    if length(seqs) == 1
        return quote
            buf_seq[] = $(esc(seqs[1]))
        end
    else
        return quote
            buf_seq[] = @sum $(esc.(seqs)...)
        end
    end
end


"""
    @setup

Import core packages and define global audio parameters.
"""
macro setup()
    quote
        using Waveforms, PortAudio, Jude

        global const bpm = Ref{Float64}(120.0)
        global const spf = Ref{Int64}(256)
        global const fs  = Ref{Int64}(44100)

        global running = Ref(true)
        global stream = PortAudioStream(0, 1; samplerate=fs[])

        global buf_seq = Ref{Sequence}()
        buf_seq[] = Sequence(t -> zeros(Float32, spf[]))

        @async begin
            tᵢ = 0
            while running[]
                write(stream,Base.invokelatest(query, buf_seq[], tᵢ))
                tᵢ += 1
            end
        end
    end
end


# @seq samp (0, 1/2), 2
# 

# {samp, (0, 1/4), 4}
# @seq samp (0) 4 -> Sequence(1+0, 4, t -> sound!(samp, t))
# {samp, {1/4}, 4} -> Sequence(1+1/4, 4, t -> sound!(samp, t))
# {samp, (0, 1/2), 4} -> Sequence(t -> query(Sequence(1, 4, t -> sound!(samp, t)), t) + query(Sequence(1+1/2, 4, t -> sound!(samp, t))

# @gain @ADR(1/2, 3, 1/2) @seq samp (0) 4 
# Sequence(1+0, 4, t -> sound!(samp, t)) 


# Sequence(t -> gain(
# query( Sequence(1+0, 4, t -> sound!(samp, t)) ),
# query(t |> ADR(1/2, 3, 1/2))
# ))

# @gain[ADR(1/2, 3, 1/2)] < @lpf[const(0.4)] < @seq samp (0) 4 

# Sequence(t -> lpf(
# query( Sequence(1+0, 4, t -> sound!(samp, t-1)) ),
# query( Sequence(1+0, 4, t -> sound!(samp, t)) )
# query(@const(0.4))
# ))

# ADR(1/2, 3, 1/2)

# @chop rand() > @seq bjork

# @markov (:hh :pb) 0 1
# Sequence(1+0, 1, t -> sound!(
# query( @markovseq )
# , t))


# @seq samp (0, 1/2) 2

# @beat samp (0, 1/2) 2

# @sum seq1 seq2

# @seq 4 (0, 1/2) :hh -> @sum seq1 seq2




# Sequence(t -> query(Sequence(1, 4, t -> sound!(samp, t)), t) + query(Sequence(1+1/2, 4, t -> sound!(samp, t))

function gain(vec, gain_val)
    return vec .* gain_val
end

function lpf(vec, gain_val)
    return vec .* gain_val
end

# seq = Sequence(1, 4, )


abstract type AbstractEnvelope <: AbstractSequence end

struct ADR <: AbstractEnvelope
    map::Function
end





seq = Sequence(t -> query(Sequence(1, 4, t -> sound!(samp, t)), t) + query(Sequence(1+1/2, 4, t -> sound!(samp, t))
, t))

##

buf_seq = Ref{Sequence}()

##

@jude @seq samp at=(0, 1/3, 2/3) len=4

##
running = Ref(true)
stream = PortAudioStream(0, 1; samplerate=fs[])

##
@async begin
    tᵢ = 0
    while running[]
        write(stream,Base.invokelatest(query, buf_seq[], tᵢ))
        tᵢ += 1
    end
end



##
running[] = false
close(stream)
