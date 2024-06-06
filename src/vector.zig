const std = @import("std");

pub const Vector3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn length(self: Vector3) f32 {
        return std.math.sqrt(self.length2());
    }

    pub fn length2(self: Vector3) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn lerp(min: Vector3, max: Vector3, k: Vector3) Vector3 {
        return .{ .x = std.math.lerp(min.x, max.x, k.x), .y = std.math.lerp(min.y, max.y, k.y), .z = std.math.lerp(min.z, max.z, k.z) };
    }

    pub fn multScalar(self: Vector3, scalar: f32) Vector3 {
        return .{ .x = self.x * scalar, .y = self.y * scalar, .z = self.z * scalar };
    }

    pub fn divideScalar(self: Vector3, scalar: f32) Vector3 {
        return .{ .x = self.x / scalar, .y = self.y / scalar, .z = self.z / scalar };
    }

    pub fn normalize(self: Vector3) Vector3 {
        return self.divideScalar(self.length());
    }

    pub fn add(a: Vector3, b: Vector3) Vector3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vector3, b: Vector3) Vector3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn cross(a: Vector3, b: Vector3) Vector3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn dot(a: Vector3, b: Vector3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }
};

//Matrix is stored row-major
pub const Mat3 = struct {
    r0: Vector3,
    r1: Vector3,
    r2: Vector3,
};

pub const Vector2 = struct {
    x: f32,
    y: f32,

    pub fn length(self: Vector2) f32 {
        return std.math.sqrt(self.length2());
    }

    pub fn length2(self: Vector2) f32 {
        return self.x * self.x + self.y * self.y;
    }

    pub fn lerp(min: Vector2, maximum: Vector2, k: Vector2) Vector2 {
        return .{ .x = std.math.lerp(min.x, maximum.x, k.x), .y = std.math.lerp(min.y, maximum.y, k.y) };
    }

    pub fn divideScalar(self: *const Vector2, scalar: f32) Vector2 {
        return .{ .x = self.x / scalar, .y = self.y / scalar };
    }

    pub fn multScalar(self: *const Vector2, scalar: f32) Vector2 {
        return .{ .x = self.x * scalar, .y = self.y * scalar };
    }

    pub fn max(a: Vector2, b: Vector2) Vector2 {
        return .{ .x = @max(a.x, b.x), .y = @max(a.y, b.y) };
    }

    pub fn addScalar(self: *const Vector2, scalar: f32) Vector2 {
        return .{ .x = self.x + scalar, .y = self.y + scalar };
    }

    pub fn getAngle(self: *const Vector2) f32 {
        return std.math.atan2(self.y, self.x);
    }

    pub fn rotate(self: *const Vector2, angle: f32) Vector2 {
        const startAngle: f32 = self.getAngle();
        const len: f32 = self.length();
        return .{ .x = std.math.cos(startAngle + angle) * len, .y = std.math.sin(startAngle + angle) * len };
    }

    pub fn dot(a: Vector2, b: Vector2) f32 {
        return a.x * b.x + a.y * b.y;
    }

    pub fn add(a: Vector2, b: Vector2) Vector2 {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub fn subtract(a: Vector2, b: Vector2) Vector2 {
        return .{ .x = a.x - b.x, .y = a.y - b.y };
    }
};
