const data = @import("data.zig");
const envelopes = @import("envelopes.zig");
const Envelope = envelopes.Envelope;
const SAMPLE_RATE = data.SAMPLE_RATE;
const SAMPLE_DURATION = data.SAMPLE_DURATION;
const TWO_PI = data.TWO_PI;

pub const Lowpass = struct {
    base_cutoff: f32 = 1000.0,
    current_cutoff: f32 = 1000.0,
    resonance: f32 = 0.707,
    envelope: Envelope = .{},
    env_amount: f32 = 1000.0,
    a1: f32 = 0.0,
    a2: f32 = 0.0,
    b0: f32 = 0.0,
    b1: f32 = 0.0,
    b2: f32 = 0.0,
    x1: f32 = 0.0,
    x2: f32 = 0.0,
    y1: f32 = 0.0,
    y2: f32 = 0.0,

    pub fn init(cutoff: f32, resonance: f32) Lowpass {
        var lowpass = Lowpass{
            .base_cutoff = cutoff,
            .current_cutoff = cutoff,
            .resonance = resonance,
            .envelope = .{},
        };
        lowpass.calculateCoefficients();
        return lowpass;
    }

    pub fn process(self: *Lowpass, input: f32) f32 {
        const env_value = self.envelope.process();
        self.current_cutoff = self.base_cutoff + (self.env_amount * env_value);
        self.calculateCoefficients();

        const output = self.b0 * input +
            self.b1 * self.x1 +
            self.b2 * self.x2 -
            self.a1 * self.y1 -
            self.a2 * self.y2;

        self.x2 = self.x1;
        self.x1 = input;
        self.y2 = self.y1;
        self.y1 = output;

        return output;
    }

    pub fn calculateCoefficients(self: *Lowpass) void {
        const omega = TWO_PI * self.current_cutoff / @as(f32, @floatFromInt(SAMPLE_RATE));
        const alpha = @sin(omega) / (2.0 * self.resonance);
        const cosw = @cos(omega);

        const a0 = 1.0 + alpha;
        self.b0 = (1.0 - cosw) / (2.0 * a0);
        self.b1 = (1.0 - cosw) / a0;
        self.b2 = (1.0 - cosw) / (2.0 * a0);
        self.a1 = (-2.0 * cosw) / a0;
        self.a2 = (1.0 - alpha) / a0;
    }

    pub fn setCutoff(self: *Lowpass, cutoff: f32) void {
        self.base_cutoff = cutoff;
        self.calculateCoefficients();
    }

    pub fn setResonance(self: *Lowpass, resonance: f32) void {
        self.resonance = resonance;
        self.calculateCoefficients();
    }

    pub fn setEnvAmount(self: *Lowpass, amount: f32) void {
        self.env_amount = amount;
    }
};
