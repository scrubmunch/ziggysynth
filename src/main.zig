// TODO
// MIDI or keyboard in to play notes
// ADSR

const std = @import("std");
const rl = @import("raylib");
const math = std.math;

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

const WaveForm = enum {
    sine,
    square,
    sawtooth,
    triangle,
};

const Oscillator = struct {
    frequency: f32,
    phase: f32,
    waveform: WaveForm = .sine,

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

        return sample;
    }
};

fn PolyOscillator(comptime voice_count: comptime_int) type {
    return struct {
        oscillators: [voice_count]Oscillator = undefined,

        pub fn initOSC(self: *@This()) void {
            self.oscillators = [_]Oscillator{Oscillator{
                .frequency = 0,
                .phase = 0,
                .waveform = .sine,
            }} ** voice_count;
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

    const FREQ_CHANGE_RATE: f32 = 1.0; // Hz per frame
    var selected_voice: usize = 0;
    var next_voice: usize = 0; // For round-robin voice allocation

    // Main loop
    while (!rl.windowShouldClose()) {
        // Check for note key presses
        for ([_]rl.KeyboardKey{
            .z, .s, .x, .d, .c, .v, .g, .b, .h, .n, .j, .m, .comma,
        }) |key| {
            if (rl.isKeyPressed(key)) {
                if (getKeyNote(key)) |note_idx| {
                    // Assign note to next available voice (round-robin)
                    global_poly.setFrequency(next_voice, NOTE_FREQUENCIES[note_idx]);
                    next_voice = (next_voice + 1) % 4; // Assuming 4 voices
                }
            }
        }

        // Adjust all frequencies
        if (rl.isKeyDown(rl.KeyboardKey.up)) {
            global_poly.adjustFrequencies(FREQ_CHANGE_RATE);
        }
        if (rl.isKeyDown(rl.KeyboardKey.down)) {
            global_poly.adjustFrequencies(-FREQ_CHANGE_RATE);
        }

        // Select voice
        if (rl.isKeyPressed(rl.KeyboardKey.one)) selected_voice = 0;
        if (rl.isKeyPressed(rl.KeyboardKey.two)) selected_voice = 1;
        if (rl.isKeyPressed(rl.KeyboardKey.three)) selected_voice = 2;
        if (rl.isKeyPressed(rl.KeyboardKey.four)) selected_voice = 3;

        // Adjust individual voice frequency
        if (rl.isKeyDown(rl.KeyboardKey.right)) {
            global_poly.adjustFrequency(selected_voice, FREQ_CHANGE_RATE);
        }
        if (rl.isKeyDown(rl.KeyboardKey.left)) {
            global_poly.adjustFrequency(selected_voice, -FREQ_CHANGE_RATE);
        }

        // Set selected voice to waveform
        if (rl.isKeyPressed(rl.KeyboardKey.s)) {
            global_poly.setWaveform(selected_voice, .sine);
        }
        if (rl.isKeyPressed(rl.KeyboardKey.q)) {
            global_poly.setWaveform(selected_voice, .square);
        }
        if (rl.isKeyPressed(rl.KeyboardKey.w)) {
            global_poly.setWaveform(selected_voice, .sawtooth);
        }
        if (rl.isKeyPressed(rl.KeyboardKey.t)) {
            global_poly.setWaveform(selected_voice, .triangle);
        }

        // Set all voices to same waveform with Shift key
        if (rl.isKeyDown(rl.KeyboardKey.left_shift)) {
            if (rl.isKeyPressed(rl.KeyboardKey.s)) {
                global_poly.setAllWaveforms(.sine);
            }
            if (rl.isKeyPressed(rl.KeyboardKey.q)) {
                global_poly.setAllWaveforms(.square);
            }
            if (rl.isKeyPressed(rl.KeyboardKey.w)) {
                global_poly.setAllWaveforms(.sawtooth);
            }
            if (rl.isKeyPressed(rl.KeyboardKey.t)) {
                global_poly.setAllWaveforms(.triangle);
            }
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
    }
}
