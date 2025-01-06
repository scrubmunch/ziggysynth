const data = @import("data.zig");
const SAMPLE_DURATION = data.SAMPLE_DURATION;

pub const EnvelopeStage = enum {
    idle,
    attack,
    decay,
    sustain,
    release,
};

pub const Envelope = struct {
    stage: EnvelopeStage = .idle,
    attack_time: f32 = 0.5,
    decay_time: f32 = 2.5,
    sustain_level: f32 = 0.8,
    release_time: f32 = 2,
    current_level: f32 = 0.0,
    stage_time: f32 = 0.0,
    prev_level: f32 = 0.0,
    release_start_level: f32 = 0.0,
    interpolation_time: f32 = 0.05,

    pub fn trigger(self: *Envelope) void {
        self.prev_level = self.current_level;
        self.stage = .attack;
        self.stage_time = 0;
    }

    pub fn release(self: *Envelope) void {
        if (self.stage != .idle) {
            self.prev_level = self.current_level;
            self.release_start_level = self.current_level;
            self.stage = .release;
            self.stage_time = 0;
        }
    }

    pub fn interpolate(_: *Envelope, start: f32, end: f32, factor: f32) f32 {
        return start + (end - start) * factor;
    }

    pub fn process(self: *Envelope) f32 {
        self.stage_time += SAMPLE_DURATION;
        var target_level: f32 = undefined;

        switch (self.stage) {
            .idle => {
                target_level = 0;
            },
            .attack => {
                target_level = self.stage_time / self.attack_time;
                if (target_level >= 1.0) {
                    self.prev_level = self.current_level;
                    self.stage = .decay;
                    self.stage_time = 0;
                    target_level = 1.0;
                }
            },
            .decay => {
                const decay_progress = self.stage_time / self.decay_time;
                target_level = 1.0 + (self.sustain_level - 1.0) * decay_progress;
                if (decay_progress >= 1.0) {
                    self.prev_level = self.current_level;
                    self.stage = .sustain;
                    target_level = self.sustain_level;
                }
            },
            .sustain => {
                target_level = self.sustain_level;
            },
            .release => {
                const release_progress = self.stage_time / self.release_time;
                target_level = self.release_start_level * (1.0 - release_progress);
                if (release_progress >= 1.0) {
                    self.prev_level = self.current_level;
                    self.stage = .idle;
                    target_level = 0;
                }
            },
        }

        const blend = @min(self.stage_time / self.interpolation_time, 1.0);
        self.current_level = self.interpolate(self.prev_level, target_level, blend);
        return self.current_level;
    }
};
