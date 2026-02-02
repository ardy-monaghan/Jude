using Waveforms

global const spf = Ref{Int64}(256)
global const fs = Ref{Int64}(44100)

struct Sequence
    t₁::Int64
    T::Float64
    map::Function 
end

function Sequence(map::Function)
    return Sequence(1, Inf, map)
end

function Sequence(t₁::Int64, T::Int64, map::Function)

    

    return Sequence(t₁, T, map)
end

function query(seq::Sequence, t::Int64)

    mod_t = 1 + round(Int, (t - 1) % seq.T)

    if mod_t ≥ seq.t₁
        return seq.map(mod_t)
    end

    return nothing
end

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

seq = Sequence(2, 4, t -> sound!(samp, t))
