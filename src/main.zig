// TODO
// variable frequency oscillators
// change frequencies on input
// different waveforms

const std = @import("std");
const rl = @import("raylib");
const math = std.math;

const SAMPLE_RATE: u32 = 48000;
const SAMPLE_DURATION: f32 = 1.0 / @as(f32, @floatFromInt(SAMPLE_RATE));
const TWO_PI: f32 = 2.0 * math.pi;

const Oscillator = struct {
    frequency: f32,
    phase: f32,

    pub fn getSample(self: *Oscillator) f32 {
        // Calculate the sine value
        const sample = @sin(self.phase * TWO_PI);

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
            self.oscillators = [_]Oscillator{Oscillator{ .frequency = 0, .phase = 0 }} ** voice_count;
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

// can probably use comptime to make this handle any number of voices
const Poly4Oscillator = struct {
    oscillators: [4]Oscillator = undefined,

    pub fn initOSC(self: *Poly4Oscillator) void {
        self.oscillators = [_]Oscillator{
            Oscillator{ .frequency = 0, .phase = 0 },
            Oscillator{ .frequency = 0, .phase = 0 },
            Oscillator{ .frequency = 0, .phase = 0 },
            Oscillator{ .frequency = 0, .phase = 0 },
        };
    }

    pub fn setFrequencies(self: *Poly4Oscillator, pitches: [4]f32) void {
        for (&self.oscillators, pitches) |*oscillator, pitch| {
            oscillator.frequency = pitch;
        }
    }

    pub fn getSample(self: *Poly4Oscillator) f32 {
        var sample: f32 = 0;
        for (&self.oscillators) |*oscillator| {
            sample += oscillator.getSample();
        }
        return sample / 4.0; // Normalize the output
    }
};

fn audioInputCallback(buffer: ?*anyopaque, frames: c_uint) callconv(.C) void {
    var samples: [*]f32 = @alignCast(@ptrCast(buffer.?));

    var i: c_uint = 0;
    while (i < frames) : (i += 1) {
        samples[i] = global_poly.getSample() * 0.5; // 0.5 for amplitude scaling
    }
}

const Poly4 = PolyOscillator(4); // 4-voice polyphonic oscillator
const Poly8 = PolyOscillator(8); // 8-voice polyphonic oscillator

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
    const pitches: [4]f32 = [4]f32{ 220, 330, 440, 110 };
    global_poly.setFrequencies(pitches);

    const FREQ_CHANGE_RATE: f32 = 1.0; // Hz per frame
    var selected_voice: usize = 0;

    // Main loop
    while (!rl.windowShouldClose()) {
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

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
    }
}
