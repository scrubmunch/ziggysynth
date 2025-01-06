// MORE VOICES WITH DETUNE
// PROPER GUI
// VIBRATO
// MIDI IN

const std = @import("std");
const rl = @import("raylib");
const math = std.math;

const oscillators = @import("oscillators.zig");
const gui = @import("gui.zig");

const data = @import("data.zig");
const WaveForm = data.WaveForm;
const SAMPLE_RATE = data.SAMPLE_RATE;
const SAMPLE_DURATION = data.SAMPLE_DURATION;
const TWO_PI = data.TWO_PI;
const NOTE_KEYS = data.NOTE_KEYS;
const getKeyNote = data.getKeyNote;
const NOTE_FREQUENCIES = data.NOTE_FREQUENCIES;

const KNOB_RADIUS = 20;
const KNOB_SPACING_X = 100;
const KNOB_GROUP_SPACING = 160;
const OSC_SPACING_Y = 100;
const BASE_X = 100;
const BASE_Y = 50;

var osc1_waveform_switch = gui.WaveformSelector{
    .x = BASE_X / 2,
    .y = BASE_Y,
    .width = 120,
    .height = 40,
    .value = .sine,
    .label = "OSC 1",
};

var osc1_semitone_knob = gui.Knob{
    .x = BASE_X + 140,
    .y = BASE_Y,
    .radius = KNOB_RADIUS,
    .value = 0.5,
    .label = "Semi 1",
};

var osc1_fine_knob = gui.Knob{
    .x = BASE_X + 140 + KNOB_SPACING_X,
    .y = BASE_Y,
    .radius = KNOB_RADIUS,
    .value = 0.5,
    .label = "Fine 1",
};

var osc1_volume_knob = gui.Knob{
    .x = BASE_X + 140 + KNOB_SPACING_X * 2,
    .y = BASE_Y,
    .radius = KNOB_RADIUS,
    .value = 0.7,
    .label = "Vol 1",
};

var osc2_waveform_switch = gui.WaveformSelector{
    .x = BASE_X / 2,
    .y = BASE_Y + OSC_SPACING_Y,
    .width = 120,
    .height = 40,
    .value = .sine,
    .label = "OSC 2",
};

var osc2_semitone_knob = gui.Knob{
    .x = BASE_X + 140,
    .y = BASE_Y + OSC_SPACING_Y,
    .radius = KNOB_RADIUS,
    .value = 0.5,
    .label = "Semi 2",
};

var osc2_fine_knob = gui.Knob{
    .x = BASE_X + 140 + KNOB_SPACING_X,
    .y = BASE_Y + OSC_SPACING_Y,
    .radius = KNOB_RADIUS,
    .value = 0.5,
    .label = "Fine 2",
};

var osc2_volume_knob = gui.Knob{
    .x = BASE_X + 140 + KNOB_SPACING_X * 2,
    .y = BASE_Y + OSC_SPACING_Y,
    .radius = KNOB_RADIUS,
    .value = 0.7,
    .label = "Vol 2",
};

var osc3_waveform_switch = gui.WaveformSelector{
    .x = BASE_X / 2,
    .y = BASE_Y + OSC_SPACING_Y * 2,
    .width = 120,
    .height = 40,
    .value = .sine,
    .label = "OSC 3",
};

var osc3_semitone_knob = gui.Knob{
    .x = BASE_X + 140,
    .y = BASE_Y + OSC_SPACING_Y * 2,
    .radius = KNOB_RADIUS,
    .value = 0.5,
    .label = "Semi 3",
};

var osc3_fine_knob = gui.Knob{
    .x = BASE_X + 140 + KNOB_SPACING_X,
    .y = BASE_Y + OSC_SPACING_Y * 2,
    .radius = KNOB_RADIUS,
    .value = 0.5,
    .label = "Fine 3",
};

var osc3_volume_knob = gui.Knob{
    .x = BASE_X + 140 + KNOB_SPACING_X * 2,
    .y = BASE_Y + OSC_SPACING_Y * 2,
    .radius = KNOB_RADIUS,
    .value = 0.7,
    .label = "Vol 3",
};

var attack_knob = gui.Knob{
    .x = BASE_X + KNOB_GROUP_SPACING * 4,
    .y = BASE_Y,
    .radius = KNOB_RADIUS,
    .value = 0.1,
    .label = "Attack",
};

var decay_knob = gui.Knob{
    .x = BASE_X + KNOB_GROUP_SPACING * 4 + KNOB_SPACING_X,
    .y = BASE_Y,
    .radius = KNOB_RADIUS,
    .value = 0.1,
    .label = "Decay",
};

var sustain_knob = gui.Knob{
    .x = BASE_X + KNOB_GROUP_SPACING * 4 + KNOB_SPACING_X * 2,
    .y = BASE_Y,
    .radius = KNOB_RADIUS,
    .value = 0.7,
    .label = "Sustain",
};

var release_knob = gui.Knob{
    .x = BASE_X + KNOB_GROUP_SPACING * 4 + KNOB_SPACING_X * 3,
    .y = BASE_Y,
    .radius = KNOB_RADIUS,
    .value = 0.2,
    .label = "Release",
};

var cutoff_knob = gui.Knob{
    .x = BASE_X + KNOB_GROUP_SPACING * 4,
    .y = BASE_Y + OSC_SPACING_Y,
    .radius = KNOB_RADIUS,
    .value = 0.5,
    .label = "Cutoff",
};

var resonance_knob = gui.Knob{
    .x = BASE_X + KNOB_GROUP_SPACING * 4 + KNOB_SPACING_X,
    .y = BASE_Y + OSC_SPACING_Y,
    .radius = KNOB_RADIUS,
    .value = 0.5,
    .label = "Res",
};

var filter_env_knob = gui.Knob{
    .x = BASE_X + KNOB_GROUP_SPACING * 4 + KNOB_SPACING_X * 2,
    .y = BASE_Y + OSC_SPACING_Y,
    .radius = KNOB_RADIUS,
    .value = 0.5,
    .label = "F.Amount",
};

var master_gain_knob = gui.Knob{
    .x = BASE_X + KNOB_GROUP_SPACING * 4 + KNOB_SPACING_X * 3,
    .y = BASE_Y + OSC_SPACING_Y,
    .radius = KNOB_RADIUS,
    .value = 0.5,
    .label = "Gain",
};

var filter_attack_knob = gui.Knob{
    .x = BASE_X + KNOB_GROUP_SPACING * 4,
    .y = BASE_Y + OSC_SPACING_Y * 2,
    .radius = KNOB_RADIUS,
    .value = 0.1,
    .label = "F.Attack",
};

var filter_decay_knob = gui.Knob{
    .x = BASE_X + KNOB_GROUP_SPACING * 4 + KNOB_SPACING_X,
    .y = BASE_Y + OSC_SPACING_Y * 2,
    .radius = KNOB_RADIUS,
    .value = 0.1,
    .label = "F.Decay",
};

var filter_sustain_knob = gui.Knob{
    .x = BASE_X + KNOB_GROUP_SPACING * 4 + KNOB_SPACING_X * 2,
    .y = BASE_Y + OSC_SPACING_Y * 2,
    .radius = KNOB_RADIUS,
    .value = 0.5,
    .label = "F.Sustain",
};

var filter_release_knob = gui.Knob{
    .x = BASE_X + KNOB_GROUP_SPACING * 4 + KNOB_SPACING_X * 3,
    .y = BASE_Y + OSC_SPACING_Y * 2,
    .radius = KNOB_RADIUS,
    .value = 0.2,
    .label = "F.Release",
};

var osc1_pan_knob = gui.Knob{
    .x = BASE_X + 140 + KNOB_SPACING_X * 3,
    .y = BASE_Y,
    .radius = KNOB_RADIUS,
    .value = 0.5,
    .label = "Pan 1",
};

var osc2_pan_knob = gui.Knob{
    .x = BASE_X + 140 + KNOB_SPACING_X * 3,
    .y = BASE_Y + OSC_SPACING_Y,
    .radius = KNOB_RADIUS,
    .value = 0.5,
    .label = "Pan 2",
};

var osc3_pan_knob = gui.Knob{
    .x = BASE_X + 140 + KNOB_SPACING_X * 3,
    .y = BASE_Y + OSC_SPACING_Y * 2,
    .radius = KNOB_RADIUS,
    .value = 0.5,
    .label = "Pan 3",
};

fn audioInputCallback(buffer: ?*anyopaque, frames: c_uint) callconv(.C) void {
    var samples: [*]f32 = @alignCast(@ptrCast(buffer.?));

    var i: c_uint = 0;
    while (i < frames * 2) : (i += 2) {
        const osc1_sample = osc1_poly.getSample() * osc1_volume_knob.value;
        const osc2_sample = osc2_poly.getSample() * osc2_volume_knob.value;
        const osc3_sample = osc3_poly.getSample() * osc3_volume_knob.value;

        const osc1_pan = osc1_pan_knob.value;
        const osc2_pan = osc2_pan_knob.value;
        const osc3_pan = osc3_pan_knob.value;

        const osc1_left = osc1_sample * @sin((1.0 - osc1_pan) * std.math.pi / 2.0);
        const osc1_right = osc1_sample * @sin(osc1_pan * std.math.pi / 2.0);
        const osc2_left = osc2_sample * @sin((1.0 - osc2_pan) * std.math.pi / 2.0);
        const osc2_right = osc2_sample * @sin(osc2_pan * std.math.pi / 2.0);
        const osc3_left = osc3_sample * @sin((1.0 - osc3_pan) * std.math.pi / 2.0);
        const osc3_right = osc3_sample * @sin(osc3_pan * std.math.pi / 2.0);

        const left = (osc1_left + osc2_left + osc3_left) / 3.0;
        const right = (osc1_right + osc2_right + osc3_right) / 3.0;

        samples[i] = left * master_gain_knob.value * 2.0;
        samples[i + 1] = right * master_gain_knob.value * 2.0;
    }
}

const NUMBER_OF_VOICES = 8;
const Poly = oscillators.PolyOscillator(NUMBER_OF_VOICES);

var osc1_poly = Poly{};
var osc2_poly = Poly{};
var osc3_poly = Poly{};

pub fn main() void {
    rl.initWindow(1120, 340, "SYNTH");
    rl.setConfigFlags(.{ .msaa_4x_hint = true });
    defer rl.closeWindow();
    rl.setTargetFPS(60);
    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    const stream = rl.loadAudioStream(SAMPLE_RATE, 32, 2); // 32-bit float, mono
    defer rl.unloadAudioStream(stream);

    rl.setAudioStreamCallback(stream, audioInputCallback);
    rl.playAudioStream(stream);

    osc1_poly.initOSC();
    osc2_poly.initOSC();
    osc3_poly.initOSC();

    var key_voice_map1: [256]?usize = .{null} ** 256;
    var key_voice_map2: [256]?usize = .{null} ** 256;
    var key_voice_map3: [256]?usize = .{null} ** 256;

    while (!rl.windowShouldClose()) {

        // Note input
        for (NOTE_KEYS) |key| {
            const key_idx = @as(usize, @intCast(@intFromEnum(key)));

            if (rl.isKeyPressed(key)) {
                if (getKeyNote(key)) |note_idx| {
                    const freq = NOTE_FREQUENCIES[note_idx];

                    const voice1 = osc1_poly.findVoice();
                    const voice2 = osc2_poly.findVoice();
                    const voice3 = osc3_poly.findVoice();

                    osc1_poly.noteOn(voice1, freq);
                    osc2_poly.noteOn(voice2, freq);
                    osc3_poly.noteOn(voice3, freq);

                    key_voice_map1[key_idx] = voice1;
                    key_voice_map2[key_idx] = voice2;
                    key_voice_map3[key_idx] = voice3;
                }
            } else if (rl.isKeyReleased(key)) {
                if (key_voice_map1[key_idx]) |voice| {
                    osc1_poly.noteOff(voice);
                    key_voice_map1[key_idx] = null;
                }
                if (key_voice_map2[key_idx]) |voice| {
                    osc2_poly.noteOff(voice);
                    key_voice_map2[key_idx] = null;
                }
                if (key_voice_map3[key_idx]) |voice| {
                    osc3_poly.noteOff(voice);
                    key_voice_map3[key_idx] = null;
                }
            }
        }

        // Update controls
        attack_knob.update();
        decay_knob.update();
        sustain_knob.update();
        release_knob.update();
        cutoff_knob.update();
        resonance_knob.update();
        filter_attack_knob.update();
        filter_decay_knob.update();
        filter_sustain_knob.update();
        filter_release_knob.update();
        filter_env_knob.update();
        osc1_waveform_switch.update();
        osc1_semitone_knob.update();
        osc1_fine_knob.update();
        osc2_waveform_switch.update();
        osc2_semitone_knob.update();
        osc2_fine_knob.update();
        osc3_waveform_switch.update();
        osc3_semitone_knob.update();
        osc3_fine_knob.update();
        master_gain_knob.update();
        osc1_volume_knob.update();
        osc2_volume_knob.update();
        osc3_volume_knob.update();
        osc1_pan_knob.update();
        osc2_pan_knob.update();
        osc3_pan_knob.update();

        // Update synth
        osc1_poly.setWaveform(osc1_waveform_switch.value);
        osc1_poly.setSemitone(osc1_semitone_knob.value);
        osc1_poly.setFine(osc1_fine_knob.value);
        osc1_poly.setAttack(attack_knob.value);
        osc1_poly.setDecay(decay_knob.value);
        osc1_poly.setSustain(sustain_knob.value);
        osc1_poly.setRelease(release_knob.value);
        osc1_poly.setFilterCutoff(cutoff_knob.value);
        osc1_poly.setFilterResonance(resonance_knob.value);
        osc1_poly.setFilterEnv(filter_env_knob.value);
        osc1_poly.setFilterAttack(filter_attack_knob.value);
        osc1_poly.setFilterDecay(filter_decay_knob.value);
        osc1_poly.setFilterSustain(filter_sustain_knob.value);
        osc1_poly.setFilterRelease(filter_release_knob.value);

        osc2_poly.setWaveform(osc2_waveform_switch.value);
        osc2_poly.setSemitone(osc2_semitone_knob.value);
        osc2_poly.setFine(osc2_fine_knob.value);
        osc2_poly.setAttack(attack_knob.value);
        osc2_poly.setDecay(decay_knob.value);
        osc2_poly.setSustain(sustain_knob.value);
        osc2_poly.setRelease(release_knob.value);
        osc2_poly.setFilterCutoff(cutoff_knob.value);
        osc2_poly.setFilterResonance(resonance_knob.value);
        osc2_poly.setFilterEnv(filter_env_knob.value);
        osc2_poly.setFilterAttack(filter_attack_knob.value);
        osc2_poly.setFilterDecay(filter_decay_knob.value);
        osc2_poly.setFilterSustain(filter_sustain_knob.value);
        osc2_poly.setFilterRelease(filter_release_knob.value);

        osc3_poly.setWaveform(osc3_waveform_switch.value);
        osc3_poly.setSemitone(osc3_semitone_knob.value);
        osc3_poly.setFine(osc3_fine_knob.value);
        osc3_poly.setAttack(attack_knob.value);
        osc3_poly.setDecay(decay_knob.value);
        osc3_poly.setSustain(sustain_knob.value);
        osc3_poly.setRelease(release_knob.value);
        osc3_poly.setFilterCutoff(cutoff_knob.value);
        osc3_poly.setFilterResonance(resonance_knob.value);
        osc3_poly.setFilterEnv(filter_env_knob.value);
        osc3_poly.setFilterAttack(filter_attack_knob.value);
        osc3_poly.setFilterDecay(filter_decay_knob.value);
        osc3_poly.setFilterSustain(filter_sustain_knob.value);
        osc3_poly.setFilterRelease(filter_release_knob.value);

        // Draw stuff
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);

        attack_knob.draw();
        decay_knob.draw();
        sustain_knob.draw();
        release_knob.draw();
        cutoff_knob.draw();
        resonance_knob.draw();
        filter_attack_knob.draw();
        filter_decay_knob.draw();
        filter_sustain_knob.draw();
        filter_release_knob.draw();
        filter_env_knob.draw();
        osc1_waveform_switch.draw();
        osc1_semitone_knob.draw();
        osc1_fine_knob.draw();
        osc2_waveform_switch.draw();
        osc2_semitone_knob.draw();
        osc2_fine_knob.draw();
        osc3_waveform_switch.draw();
        osc3_semitone_knob.draw();
        osc3_fine_knob.draw();
        master_gain_knob.draw();
        osc1_volume_knob.draw();
        osc2_volume_knob.draw();
        osc3_volume_knob.draw();
        osc3_pan_knob.draw();
        osc1_pan_knob.draw();
        osc2_pan_knob.draw();
    }
}
