using PortAudio, Statistics, Waveforms, WAV, HTTP

spf = 256
running = Ref(true)
fs = 44100
stream = PortAudioStream(0, 1; samplerate=fs)

struct Sample
    data::Vector{Float32}
    T::Int64
end

function Sample(data::Matrix, spf::Int64)
    return Sample(convert(Vector{Float32}, vec(data)), ceil(Int64, length(data) / spf))
end


struct Sequence
    t₁::Int64
    T::Int64
    sample::Sample # this should be a func... that takes only ti as an arg and returns a vec (eventually)
end

function query_sequence(t::Int64, sequence::Sequence)
    if t ≥ sequence.t₁ && t < sequence.t₁ + sequence.T
        return sequence
    end
    return nothing
end

exp_sq = Sequence(0, 100, t -> query_sequence(t, another_sq))

# use |+ to add values
# use |> to send as an argument

{:bd, 1, 4}


{{:bd, 1, 4}  |>  {mask}} ::: t -> mask(query_sequence(t, {:bd, 1, 4}), t)

{{:bd, 1, 4}  |>  {mask()}} ::: t -> mask!(query_sequence(t, {:bd, 1, 4}), query_sequence(t, {}), t)


|+ ::: t -> query_sequence(t, {:bd, 1, 4}) + query_sequence(t, {:hh, 1, 4})

{{{shuffle!(:hh, :bp)}, 1, 1} |+ {{:bd, 1, 4}}  |>  {mask}}

{:hh |> lpf |> mask(seq(rand()))} |> adsr(0.01, 0.1, 0.8, 0.2)

# Everything in {} is a sequence, a length, start time, and a function that takes ti as an arg and returns a vec

# we are viewing mask(seq(rand())) as a sequence via mask(buf, tᵢ) as the fnc

:bjork . chop(seq(rand()))

--->

hh_seq = ...
bjork_seq = ...

tmp_buf = zeros(Float32, spf)

function exam(tᵢ, buf)

    zero!(tmp_buf)

    if tᵢ ...
        tmp_buf = :hh[t]
    else
        tmp_buf = zeros(Float32, spf)
    end

    lpf!(tmp_buf)

    buf += tmp_buf

    mask!(tmp_buf) > 
        if query_seq(tᵢ, seq)
            tmp_buf .*= 0.0
        end

    # bjork
    if tᵢ ...
        tmp_buf .= :bjork[seq[tᵢ]]
    end
        

    buf += tmp_buf
end


##
@async begin
    tᵢ = 0 
    buf = zeros(Float32, spf)

    while running[]

        write(stream, buf)

        tᵢ += 1

        @invokelatest generate_buf!(buf, spf)
    end
end


##
function generate_buf!(buf, n)
    buf .= squarewave.(2π * (880 / 44100) .* (0:n-1)) .* 0.1
end


##
running[] = false
close(stream)
