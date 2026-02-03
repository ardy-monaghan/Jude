using Waveforms

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

function Sample(data::Union{Vector{Float32}, Vector{Float64}})
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

y = squarewave.(2π * (440 / fs[]) .* (0:10_000)) .* 0.1
samp = Sample(y)

seq = Sequence(1, 1/4, t -> sound!(samp, t))

seq1 = Sequence(1, 4, t -> sound!(samp, t))
seq2 = Sequence(1+1/2, 4, t -> sound!(samp, t))


macro sayhello(name, trait)
    if typeof(eval(trait)) <: Tuple
        return quote println("Hello, ", $name) end
    else
        return quote println("Hi, ", $name) end
    end
end

"""
    @sum seq1 seq2 ...

Combine sequences by summing their outputs pointwise in time.
"""
macro sum(seqs...)
    seqs_esc = esc.(seqs)

    # build: t -> seq1(t) + seq2(t) + ...
    body = reduce((a, b) -> :($a + $b),
                  [:( $s(t) ) for s in seqs_esc])

    return quote
        Sequence(t -> $body)
    end
end

"""
    @seq sample beats length

Create a Sequence from `sample`.

Examples
--------
@seq samp 0 4
@seq samp (0, 1) 4
"""
macro seq(sample, beats, length)
    sample = esc(sample)
    length = esc(length)

    # Case 1: single beat offset
    if !(beats isa Expr && beats.head == :tuple)
        return quote
            Sequence(1 + $(esc(beats)), $length,
                     t -> sound!($sample, t))
        end
    end

    # Case 2: multiple beat offsets (tuple)
    # Build one Sequence per beat
    seqs = [
        :(Sequence(1 + $(esc(b)), $length,
                   t -> sound!($sample, t)))
        for b in beats.args
    ]

    # Delegate summation to @sum
    return Expr(:macrocall, Symbol("@sum"), __source__, seqs...)
end

@sayhello(
:Ross,
(4,)
)

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

