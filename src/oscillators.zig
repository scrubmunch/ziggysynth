const std = @import("std");
const data = @import("data.zig");
const envelopes = @import("envelopes.zig");
const filters = @import("filters.zig");
const Envelope = envelopes.Envelope;
const WaveForm = data.WaveForm;
const SAMPLE_DURATION = data.SAMPLE_DURATION;
const TWO_PI = data.TWO_PI;

const Oscillator = struct {
    frequency: f32,
    base_frequency: f32 = 0.0,
    phase: f32,
    waveform: WaveForm = .sine,
    envelope: Envelope = .{},
    filter: filters.Lowpass = filters.Lowpass.init(1000.0, 0.707),
    is_playing: bool = false,
    semitone_offset: f32 = 0.0,
    fine_offset: f32 = 0.0,

    pub fn updatePitch(self: *Oscillator) void {
        const semitone_multiplier = std.math.pow(f32, 2.0, self.semitone_offset / 12.0);
        const fine_multiplier = std.math.pow(f32, 2.0, self.fine_offset / 1200.0);
        self.frequency = self.base_frequency * semitone_multiplier * fine_multiplier;
    }

    pub fn noteOn(self: *Oscillator, freq: f32) void {
        self.base_frequency = freq;
        self.updatePitch();
        self.is_playing = true;
        self.envelope.trigger();
        self.filter.envelope.trigger();
    }

    pub fn noteOff(self: *Oscillator) void {
        self.is_playing = false;
        self.envelope.release();
        self.filter.envelope.release();
    }

    fn polyBlep(self: *Oscillator, t: f32) f32 {
        const dt = self.frequency * SAMPLE_DURATION;

        if (t < dt) {
            // Start of waveform
            const t2 = t / dt;
            return t2 * t2 / 2.0 - t2 + 1.0;
        } else if (t > 1.0 - dt) {
            // End of waveform
            const t2 = (t - 1.0) / dt;
            return t2 * t2 / 2.0 + t2 + 1.0;
        }
        return 0.0;
    }

    pub fn getSample(self: *Oscillator) f32 {
        var sample: f32 = undefined;
        const dt = self.frequency * SAMPLE_DURATION;

        switch (self.waveform) {
            .sine => {
                sample = @sin(self.phase * TWO_PI);
            },
            .square => {
                sample = if (self.phase < 0.5) 1.0 else -1.0;
                sample += self.polyBlep(self.phase);
                sample -= self.polyBlep(@mod(self.phase + 0.5, 1.0));
            },
            .sawtooth => {
                sample = 2.0 * self.phase - 1.0;
                sample -= self.polyBlep(self.phase);
            },
            .triangle => {
                if (self.phase < 0.5) {
                    sample = 4.0 * self.phase - 1.0;
                } else {
                    sample = 3.0 - 4.0 * self.phase;
                }
            },
        }

        self.phase += dt;
        self.phase = self.phase - @floor(self.phase);

        sample = sample * self.envelope.process();
        return self.filter.process(sample);
    }
};

pub fn PolyOscillator(comptime voice_count: comptime_int) type {
    return struct {
        oscillators: [voice_count]Oscillator = undefined,
        next_voice: usize = 0,

        pub fn initOSC(self: *@This()) void {
            for (&self.oscillators) |*osc| {
                osc.* = Oscillator{
                    .frequency = 0,
                    .phase = 0,
                    .waveform = .sine,
                };
            }
        }

        pub fn noteOn(self: *@This(), voice: usize, frequency: f32) void {
            if (voice < voice_count) {
                self.oscillators[voice].noteOn(frequency);
            }
        }

        pub fn noteOff(self: *@This(), voice: usize) void {
            if (voice < voice_count) {
                self.oscillators[voice].noteOff();
            }
        }

        pub fn getSample(self: *@This()) f32 {
            var sample: f32 = 0;
            for (&self.oscillators) |*osc| {
                sample += osc.getSample();
            }
            return sample / @as(f32, @floatFromInt(voice_count));
        }

        pub fn findVoice(self: *@This()) usize {
            // try to find an idle voice
            for (self.oscillators, 0..) |osc, i| {
                if (osc.envelope.stage == .idle and
                    osc.filter.envelope.stage == .idle)
                {
                    return i;
                }
            }

            // try to find a voice that's not playing
            for (self.oscillators, 0..) |osc, i| {
                if (!osc.is_playing) {
                    return i;
                }
            }

            // else use round robin
            const voice = self.next_voice;
            self.next_voice = (self.next_voice + 1) % voice_count;
            return voice;
        }

        pub fn setSemitone(self: *@This(), value: f32) void {
            for (&self.oscillators) |*osc| {
                osc.semitone_offset = (value * 48.0) - 24.0;
            }
        }

        pub fn setFine(self: *@This(), value: f32) void {
            for (&self.oscillators) |*osc| {
                osc.fine_offset = (value * 200.0) - 100.0;
            }
        }

        pub fn setWaveform(self: *@This(), value: WaveForm) void {
            for (&self.oscillators) |*osc| {
                osc.waveform = value;
            }
        }

        pub fn setAttack(self: *@This(), value: f32) void {
            for (&self.oscillators) |*osc| {
                osc.envelope.attack_time = data.mapToRangeCurve(value, data.ENV.ATTACK_MIN, data.ENV.ATTACK_MAX, data.CURVE_EXPONENT_DEFAULT);
            }
        }

        pub fn setDecay(self: *@This(), value: f32) void {
            for (&self.oscillators) |*osc| {
                osc.envelope.decay_time = data.mapToRangeCurve(value, data.ENV.DECAY_MIN, data.ENV.DECAY_MAX, data.CURVE_EXPONENT_DEFAULT);
            }
        }

        pub fn setSustain(self: *@This(), value: f32) void {
            for (&self.oscillators) |*osc| {
                osc.envelope.sustain_level = data.mapToRangeCurve(value, data.ENV.SUSTAIN_MIN, data.ENV.SUSTAIN_MAX, data.CURVE_EXPONENT_DEFAULT);
            }
        }

        pub fn setRelease(self: *@This(), value: f32) void {
            for (&self.oscillators) |*osc| {
                osc.envelope.release_time = data.mapToRangeCurve(value, data.ENV.RELEASE_MIN, data.ENV.RELEASE_MAX, data.CURVE_EXPONENT_DEFAULT);
            }
        }

        pub fn setFilterCutoff(self: *@This(), value: f32) void {
            for (&self.oscillators) |*osc| {
                osc.filter.setCutoff(data.mapToRangeCurve(value, data.FILTER.CUTOFF_MIN, data.FILTER.CUTOFF_MAX, data.CURVE_EXPONENT_DEFAULT));
            }
        }

        pub fn setFilterResonance(self: *@This(), value: f32) void {
            for (&self.oscillators) |*osc| {
                osc.filter.setResonance(data.mapToRange(value, data.FILTER.RESONANCE_MIN, data.FILTER.RESONANCE_MAX));
            }
        }

        pub fn setFilterEnv(self: *@This(), value: f32) void {
            for (&self.oscillators) |*osc| {
                osc.filter.setEnvAmount(data.mapToRange(value, data.FILTER.ENV_AMOUNT_MIN, data.FILTER.ENV_AMOUNT_MAX));
            }
        }

        pub fn setFilterAttack(self: *@This(), value: f32) void {
            for (&self.oscillators) |*osc| {
                osc.filter.envelope.attack_time = data.mapToRangeCurve(value, data.ENV.ATTACK_MIN, data.ENV.ATTACK_MAX, data.CURVE_EXPONENT_DEFAULT);
            }
        }

        pub fn setFilterDecay(self: *@This(), value: f32) void {
            for (&self.oscillators) |*osc| {
                osc.filter.envelope.decay_time = data.mapToRangeCurve(value, data.ENV.DECAY_MIN, data.ENV.DECAY_MAX, data.CURVE_EXPONENT_DEFAULT);
            }
        }

        pub fn setFilterSustain(self: *@This(), value: f32) void {
            for (&self.oscillators) |*osc| {
                osc.filter.envelope.sustain_level = data.mapToRangeCurve(value, data.ENV.SUSTAIN_MIN, data.ENV.SUSTAIN_MAX, data.CURVE_EXPONENT_DEFAULT);
            }
        }

        pub fn setFilterRelease(self: *@This(), value: f32) void {
            for (&self.oscillators) |*osc| {
                osc.filter.envelope.release_time = data.mapToRangeCurve(value, data.ENV.RELEASE_MIN, data.ENV.RELEASE_MAX, data.CURVE_EXPONENT_DEFAULT);
            }
        }
    };
}
