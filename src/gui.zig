const std = @import("std");
const rl = @import("raylib");
const math = std.math;

pub const Knob = struct {
    x: i32,
    y: i32,
    radius: i32,
    value: f32, // 0.0 to 1.0
    label: [*:0]const u8,
    is_dragging: bool = false,
    last_mouse_y: i32 = 0,

    pub fn draw(self: *Knob) void {
        // Draw knob background
        rl.drawCircle(self.x, self.y, @as(f32, @floatFromInt(self.radius)), rl.Color.gray);

        // Draw indicator line
        // Changed angle calculation: -45 to 225 degrees (rotated 90° counterclockwise)
        const angle = self.value * 270.0 - 225.0; // Changed from -135.0
        const rad_angle = angle * math.pi / 180.0;
        const line_end_x = self.x + @as(i32, @intFromFloat(@cos(rad_angle) * @as(f32, @floatFromInt(self.radius))));
        const line_end_y = self.y + @as(i32, @intFromFloat(@sin(rad_angle) * @as(f32, @floatFromInt(self.radius))));
        rl.drawLine(self.x, self.y, line_end_x, line_end_y, rl.Color.white);

        // Draw label
        const text_width = rl.measureText(self.label, 20);
        rl.drawText(self.label, self.x - @divFloor(text_width, 2), self.y + self.radius + 5, 20, rl.Color.white);
    }

    pub fn update(self: *Knob) void {
        const mouse_pos = rl.getMousePosition();
        const mouse_x = @as(i32, @intFromFloat(mouse_pos.x));
        const mouse_y = @as(i32, @intFromFloat(mouse_pos.y));

        // Check if mouse is over knob
        const dist_sq = (mouse_x - self.x) * (mouse_x - self.x) +
            (mouse_y - self.y) * (mouse_y - self.y);
        const is_over = dist_sq <= self.radius * self.radius;

        if (rl.isMouseButtonPressed(rl.MouseButton.left) and is_over) {
            self.is_dragging = true;
            self.last_mouse_y = mouse_y;
        } else if (rl.isMouseButtonReleased(rl.MouseButton.left)) {
            self.is_dragging = false;
        }

        if (self.is_dragging) {
            const delta_y = self.last_mouse_y - mouse_y;
            self.value = @min(1.0, @max(0.0, self.value + @as(f32, @floatFromInt(delta_y)) * 0.01));
            self.last_mouse_y = mouse_y;
        }
    }
};

// pub const Switch = struct {
//     x: i32,
//     y: i32,
//     width: i32,
//     height: i32,
//     is_on: bool = false,
//     label: []const u8,

//     pub fn draw(self: *Switch) void {
//         const color = if (self.is_on) rl.Color.green else rl.Color.darkGray;
//         rl.drawRectangle(self.x, self.y, self.width, self.height, color);

//         // Draw label
//         const text_width = rl.measureText(self.label, 20);
//         rl.drawText(self.label, self.x + @divFloor(self.width - text_width, 2), self.y + self.height + 5, 20, rl.Color.white);
//     }

//     pub fn update(self: *Switch) void {
//         const mouse_pos = rl.getMousePosition();
//         const mouse_x = @as(i32, @intFromFloat(mouse_pos.x));
//         const mouse_y = @as(i32, @intFromFloat(mouse_pos.y));

//         if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
//             if (mouse_x >= self.x and mouse_x <= self.x + self.width and
//                 mouse_y >= self.y and mouse_y <= self.y + self.height)
//             {
//                 self.is_on = !self.is_on;
//             }
//         }
//     }
// };
