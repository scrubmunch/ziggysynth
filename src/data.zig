const std = @import("std");
const rl = @import("raylib");
const math = std.math;

pub const SAMPLE_RATE: u32 = 48000;
pub const SAMPLE_DURATION: f32 = 1.0 / @as(f32, @floatFromInt(SAMPLE_RATE));
pub const TWO_PI: f32 = 2.0 * math.pi;

pub const WaveForm = enum {
    sine,
    square,
    sawtooth,
    triangle,
};

pub const NOTE_FREQUENCIES = [_]f32{
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

pub fn getKeyNote(key: rl.KeyboardKey) ?usize {
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

pub const NOTE_KEYS = [_]rl.KeyboardKey{
    .z, .s, .x, .d, .c, .v, .g, .b, .h, .n, .j, .m, .comma,
};

pub const WAVEFORM_CONTROLS = struct {
    key: rl.KeyboardKey,
    waveform: WaveForm,
};

pub const WAVEFORM_KEYS = [_]WAVEFORM_CONTROLS{
    .{ .key = .q, .waveform = .sine },
    .{ .key = .w, .waveform = .square },
    .{ .key = .e, .waveform = .sawtooth },
    .{ .key = .r, .waveform = .triangle },
};

pub const ENV = struct {
    pub const ATTACK_MIN: f32 = 0.001;
    pub const ATTACK_MAX: f32 = 5.0;
    pub const DECAY_MIN: f32 = 0.001;
    pub const DECAY_MAX: f32 = 10.0;
    pub const SUSTAIN_MIN: f32 = 0.0;
    pub const SUSTAIN_MAX: f32 = 1.0;
    pub const RELEASE_MIN: f32 = 0.001;
    pub const RELEASE_MAX: f32 = 10.0;
};

pub const FILTER = struct {
    pub const CUTOFF_MIN: f32 = 20.0;
    pub const CUTOFF_MAX: f32 = 20000.0;
    pub const RESONANCE_MIN: f32 = 0.1;
    pub const RESONANCE_MAX: f32 = 4.0;
    pub const ENV_AMOUNT_MIN: f32 = 0.0;
    pub const ENV_AMOUNT_MAX: f32 = 5000.0;
};

pub const OSC = struct {
    pub const SEMITONE_MIN: f32 = -24.0;
    pub const SEMITONE_MAX: f32 = 24.0;
    pub const FINE_MIN: f32 = -100.0;
    pub const FINE_MAX: f32 = 100.0;
    pub const VOLUME_MIN: f32 = 0.0;
    pub const VOLUME_MAX: f32 = 1.0;
};

pub const MASTER = struct {
    pub const GAIN_MIN: f32 = 0.0;
    pub const GAIN_MAX: f32 = 2.0;
};

pub fn mapToRange(value: f32, min: f32, max: f32) f32 {
    return min + (value * (max - min));
}

pub fn mapToRangeCurve(value: f32, min: f32, max: f32, exponent: f32) f32 {
    const curved_value = std.math.pow(f32, value, exponent);
    return min + (curved_value * (max - min));
}

pub const CURVE_EXPONENT_DEFAULT = 1.5;
