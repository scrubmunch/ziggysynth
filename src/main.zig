// TODO
// MIDI or keyboard in to play notes
// ADSR

const std = @import("std");
const rl = @import("raylib");
const math = std.math;
const gui = @import("gui.zig");

const SAMPLE_RATE: u32 = 48000;
const SAMPLE_DURATION: f32 = 1.0 / @as(f32, @floatFromInt(SAMPLE_RATE));
const TWO_PI: f32 = 2.0 * math.pi;

const NOTE_FREQUENCIES = [_]f32{
    261.63, // C4
    277.18, // C#4
    293.66, // D4
    311.13, // D#4
    329.63, // E4
    349.23, // F4
    369.99, // F#4
    392.00, // G4
    415.30, // G#4
    440.00, // A4
    466.16, // A#4
    493.88, // B4
    523.25, // C5
};

fn getKeyNote(key: rl.KeyboardKey) ?usize {
    return switch (key) {
        .z => 0, // C4
        .s => 1, // C#4
        .x => 2, // D4
        .d => 3, // D#4
        .c => 4, // E4
        .v => 5, // F4
        .g => 6, // F#4
        .b => 7, // G4
        .h => 8, // G#4
        .n => 9, // A4
        .j => 10, // A#4
        .m => 11, // B4
        .comma => 12, // C5
        else => null,
    };
}

const NOTE_KEYS = [_]rl.KeyboardKey{
    .z, .s, .x, .d, .c, .v, .g, .b, .h, .n, .j, .m, .comma,
};

const WaveForm = enum {
    sine,
    square,
    sawtooth,
    triangle,
};

const WAVEFORM_CONTROLS = struct {
    key: rl.KeyboardKey,
    waveform: WaveForm,
};

const WAVEFORM_KEYS = [_]WAVEFORM_CONTROLS{
    .{ .key = .q, .waveform = .sine },
    .{ .key = .w, .waveform = .square },
    .{ .key = .e, .waveform = .sawtooth },
    .{ .key = .r, .waveform = .triangle },
};

const EnvelopeStage = enum {
    idle,
    attack,
    decay,
    sustain,
    release,
};

const Envelope = struct {
    stage: EnvelopeStage = .idle,
    attack_time: f32 = 0.5, // seconds
    decay_time: f32 = 2.5, // seconds
    sustain_level: f32 = 0.6, // 0.0 to 1.0
    release_time: f32 = 2, // seconds

    current_level: f32 = 0.0,
    stage_time: f32 = 0.0,

    pub fn trigger(self: *Envelope) void {
        self.stage = .attack;
        self.stage_time = 0;
    }

    pub fn release(self: *Envelope) void {
        if (self.stage != .idle) {
            self.stage = .release;
            self.stage_time = 0;
        }
    }

    pub fn process(self: *Envelope) f32 {
        self.stage_time += SAMPLE_DURATION;

        switch (self.stage) {
            .idle => {
                self.current_level = 0;
            },
            .attack => {
                self.current_level = self.stage_time / self.attack_time;
                if (self.current_level >= 1.0) {
                    self.current_level = 1.0;
                    self.stage = .decay;
                    self.stage_time = 0;
                }
            },
            .decay => {
                const decay_progress = self.stage_time / self.decay_time;
                self.current_level = 1.0 + (self.sustain_level - 1.0) * decay_progress;
                if (decay_progress >= 1.0) {
                    self.current_level = self.sustain_level;
                    self.stage = .sustain;
                }
            },
            .sustain => {
                self.current_level = self.sustain_level;
            },
            .release => {
                const release_progress = self.stage_time / self.release_time;
                self.current_level = self.sustain_level * (1.0 - release_progress);
                if (release_progress >= 1.0) {
                    self.current_level = 0;
                    self.stage = .idle;
                }
            },
        }

        return self.current_level;
    }
};

const Oscillator = struct {
    frequency: f32,
    phase: f32,
    waveform: WaveForm = .sine,
    envelope: Envelope = .{},
    is_playing: bool = false,

    pub fn noteOn(self: *Oscillator, freq: f32) void {
        self.frequency = freq;
        self.is_playing = true;
        self.envelope.trigger();
    }

    pub fn noteOff(self: *Oscillator) void {
        self.is_playing = false;
        self.envelope.release();
    }

    pub fn getSample(self: *Oscillator) f32 {
        var sample: f32 = undefined;

        switch (self.waveform) {
            .sine => {
                sample = @sin(self.phase * TWO_PI);
            },
            .square => {
                sample = if (self.phase < 0.5) 1.0 else -1.0;
            },
            .sawtooth => {
                sample = (2.0 * self.phase) - 1.0;
            },
            .triangle => {
                if (self.phase < 0.5) {
                    sample = 4.0 * self.phase - 1.0;
                } else {
                    sample = 3.0 - 4.0 * self.phase;
                }
            },
        }

        // Increment phase (0.0 to 1.0 range)
        self.phase += self.frequency * SAMPLE_DURATION;
        // Wrap phase precisely between 0 and 1
        self.phase = self.phase - @floor(self.phase);

        // Multiple by our envelope to get correct amplitude
        return sample * self.envelope.process();
    }
};

fn PolyOscillator(comptime voice_count: comptime_int) type {
    return struct {
        oscillators: [voice_count]Oscillator = undefined,
        next_voice: usize = 0,

        pub fn initOSC(self: *@This()) void {
            self.oscillators = [_]Oscillator{Oscillator{
                .frequency = 0,
                .phase = 0,
                .waveform = .sine,
            }} ** voice_count;
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

        pub fn findVoice(self: *@This()) usize {
            // First try to find an idle voice (envelope completely finished)
            for (self.oscillators, 0..) |osc, i| {
                if (osc.envelope.stage == .idle) return i;
            }
            // If no completely idle voices, look for ones that aren't actively playing
            for (self.oscillators, 0..) |osc, i| {
                if (!osc.is_playing) return i;
            }
            // If all voices are active, use round-robin
            const voice = self.next_voice;
            self.next_voice = (self.next_voice + 1) % voice_count;
            return voice;
        }

        // Add method to change waveform
        pub fn setWaveform(self: *@This(), voice: usize, waveform: WaveForm) void {
            if (voice < voice_count) {
                self.oscillators[voice].waveform = waveform;
            }
        }

        pub fn setAllWaveforms(self: *@This(), waveform: WaveForm) void {
            for (&self.oscillators) |*oscillator| {
                oscillator.waveform = waveform;
            }
        }

        pub fn setFrequencies(self: *@This(), pitches: [voice_count]f32) void {
            for (&self.oscillators, pitches) |*oscillator, pitch| {
                oscillator.frequency = pitch;
            }
        }

        pub fn getFrequencies(self: *@This()) [voice_count]f32 {
            var frequencies: [voice_count]f32 = undefined;
            for (&self.oscillators, 0..) |*oscillator, i| {
                frequencies[i] = oscillator.frequency;
            }
            return frequencies;
        }

        pub fn setFrequency(self: *@This(), voice: usize, frequency: f32) void {
            if (voice < voice_count) {
                self.oscillators[voice].frequency = frequency;
            }
        }

        pub fn adjustFrequencies(self: *@This(), delta: f32) void {
            for (&self.oscillators) |*oscillator| {
                oscillator.frequency = @max(0, oscillator.frequency + delta);
            }
        }

        pub fn adjustFrequency(self: *@This(), voice: usize, delta: f32) void {
            if (voice < voice_count) {
                self.oscillators[voice].frequency = @max(0, self.oscillators[voice].frequency + delta);
            }
        }

        pub fn getSample(self: *@This()) f32 {
            var sample: f32 = 0;
            for (&self.oscillators) |*oscillator| {
                sample += oscillator.getSample();
            }
            return sample / @as(f32, @floatFromInt(voice_count)); // Normalize the output
        }
    };
}

var attack_knob = gui.Knob{
    .x = 50,
    .y = 100,
    .radius = 20,
    .value = 0.1,
    .label = "Attack",
};

var decay_knob = gui.Knob{
    .x = 150,
    .y = 100,
    .radius = 20,
    .value = 0.1,
    .label = "Decay",
};

var sustain_knob = gui.Knob{
    .x = 250,
    .y = 100,
    .radius = 20,
    .value = 0.7,
    .label = "Sustain",
};

var release_knob = gui.Knob{
    .x = 350,
    .y = 100,
    .radius = 20,
    .value = 0.2,
    .label = "Release",
};

fn audioInputCallback(buffer: ?*anyopaque, frames: c_uint) callconv(.C) void {
    var samples: [*]f32 = @alignCast(@ptrCast(buffer.?));

    var i: c_uint = 0;
    while (i < frames) : (i += 1) {
        samples[i] = global_poly.getSample() * 0.5; // 0.5 for amplitude scaling
    }
}
const NUMBER_OF_VOICES = 4;
const Poly4 = PolyOscillator(NUMBER_OF_VOICES); // 4-voice polyphonic oscillator

var global_poly = Poly4{};

pub fn main() void {
    rl.initWindow(640, 480, "SYNTH");
    defer rl.closeWindow();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    rl.setTargetFPS(60);

    // Create audio stream
    const stream = rl.loadAudioStream(SAMPLE_RATE, 32, 1); // 32-bit float, mono
    defer rl.unloadAudioStream(stream);

    // Callback function for our audio
    rl.setAudioStreamCallback(stream, audioInputCallback);
    rl.playAudioStream(stream);

    global_poly.initOSC();
    var next_voice: usize = 0; // For round-robin voice allocation

    // Which key is assigned to which voice
    var key_voice_map: [256]?usize = .{null} ** 256;

    // Main loop
    while (!rl.windowShouldClose()) {
        // Handle note input
        for (NOTE_KEYS) |key| {
            const key_idx = @as(usize, @intCast(@intFromEnum(key)));

            if (rl.isKeyPressed(key)) {
                if (getKeyNote(key)) |note_idx| {
                    const voice = global_poly.findVoice();
                    global_poly.noteOn(voice, NOTE_FREQUENCIES[note_idx]);
                    key_voice_map[key_idx] = voice;
                    next_voice = (voice + 1) % NUMBER_OF_VOICES;
                }
            } else if (rl.isKeyReleased(key)) {
                if (key_voice_map[key_idx]) |voice| {
                    global_poly.noteOff(voice);
                    key_voice_map[key_idx] = null;
                }
            }
        }
        // Handle waveform changes
        for (WAVEFORM_KEYS) |control| {
            if (rl.isKeyPressed(control.key)) {
                global_poly.setAllWaveforms(control.waveform);
            }
        }

        // Update controls
        attack_knob.update();
        decay_knob.update();
        sustain_knob.update();
        release_knob.update();

        // Update envelope parameters
        for (&global_poly.oscillators) |*osc| {
            osc.envelope.attack_time = attack_knob.value * 2.0; // 0-2 seconds
            osc.envelope.decay_time = decay_knob.value * 1.0; // 0-1 seconds
            osc.envelope.sustain_level = sustain_knob.value; // 0-1
            osc.envelope.release_time = release_knob.value * 3.0; // 0-3 seconds
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        // Draw controls
        attack_knob.draw();
        decay_knob.draw();
        sustain_knob.draw();
        release_knob.draw();
    }
}
