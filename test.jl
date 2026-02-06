using Jude, Waveforms

y = Float32.(squarewave.(2π * (400 / Jude.fs[]) .* (0:8_000)) .* 0.05)
x = Float32.(sin.(2π * (450 / Jude.fs[]) .* (0:10_000)) .* 0.1)
z = Float32.(sin.(2π * (1200 / Jude.fs[]) .* (0:6_000)) .* 0.1)
samp_x = Sample(x)
samp_y = Sample(y)
samp_z = Sample(z)

# @chop (asd) (@lpf (sad asd) (@synth sin at=(0|b3|1, 2|a3|1, 3|e4|1) len=4))),


# @synth sin at=(0|a3|1) len=4 >
# Synth() should return the sequence of all of the synth part
# tt = beats2samples(1+length) 
# freq = note_freq("a3")
# x = Float32.(sin.(2π * (freq / Jude.fs[]) .* (0:tt)) .* 0.1)
# samp_x = Sample(x)
# @seq samp_x at=(0) len=4

# @seq sin at=(0|:a3|1) len=4  ->
synth_test = Sequence(1, 4.0) do buf, t
    sound!(buf, sin, :e3, 1/4, t)
end

# Is this allocating? Yes, hm. I can do this without allocating by generating the values directly in the buffer by doing something like
# for t in indices
# buf[t] += synth_func(freq, t)

s1 = @seq samp_x at=(0, 2) len=4
s2 = @seq samp_y at=(1, 3) len=4
s3 = @seq samp_z at=(0, 1, 2, 3) len=4

##
@mix synth_test

##
@mix @seq samp_x at=(0, 2) len=4

##
@mix(
    (@seq samp_x at=(0) len=2),
    (@seq samp_y at=(1) len=4),
    (@seq samp_z at=(0) len=1/2)
);
# @setup bpm=104

# @setup bpm=130

##
@mix @seq samp_x at=(0) len=2
    @seq samp_y at=(1) len=4
    @seq samp_z at=(0) len=1/2

# @setup bpm=104

# @setup bpm=130

##
@mix(@seq samp_x at=(0) len=4, @seq samp_y at=(1, 3) len=4)