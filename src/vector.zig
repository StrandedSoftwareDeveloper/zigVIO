const std = @import("std");

pub const Vector4 = struct {
    w: f32,
    x: f32,
    y: f32,
    z: f32,

    pub fn length(self: Vector4) f32 {
        return std.math.sqrt(self.length2());
    }

    pub fn length2(self: Vector4) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn lerp(min: Vector4, max: Vector4, k: Vector4) Vector4 {
        return .{ .x = std.math.lerp(min.x, max.x, k.x), .y = std.math.lerp(min.y, max.y, k.y), .z = std.math.lerp(min.z, max.z, k.z) };
    }

    pub fn multScalar(self: Vector4, scalar: f32) Vector4 {
        return .{ .x = self.x * scalar, .y = self.y * scalar, .z = self.z * scalar };
    }

    pub fn divideScalar(self: Vector4, scalar: f32) Vector4 {
        return .{ .x = self.x / scalar, .y = self.y / scalar, .z = self.z / scalar };
    }

    pub fn normalize(self: Vector4) Vector4 {
        return self.divideScalar(self.length());
    }

    pub fn add(a: Vector4, b: Vector4) Vector4 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vector4, b: Vector4) Vector4 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn cross(a: Vector4, b: Vector4) Vector4 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn dot(a: Vector4, b: Vector4) f32 {
        return a.w * b.w + a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn zero() Vector4 {
        return .{ .w = 0.0, .x = 0.0, .y = 0.0, .z = 0.0 };
    }
};

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

    pub fn zero() Vector3 {
        return .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }
};

pub fn Vector2(T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,

        pub fn length(self: Self) T {
            return std.math.sqrt(self.length2());
        }

        pub fn length2(self: Self) T {
            return self.x * self.x + self.y * self.y;
        }

        pub fn lerp(min: Self, maximum: Self, k: Self) Self {
            return .{ .x = std.math.lerp(min.x, maximum.x, k.x), .y = std.math.lerp(min.y, maximum.y, k.y) };
        }

        pub fn divideScalar(self: *const Self, scalar: T) Self {
            return .{ .x = self.x / scalar, .y = self.y / scalar };
        }

        pub fn multScalar(self: *const Self, scalar: T) Self {
            return .{ .x = self.x * scalar, .y = self.y * scalar };
        }

        pub fn max(a: Self, b: Self) Self {
            return .{ .x = @max(a.x, b.x), .y = @max(a.y, b.y) };
        }

        pub fn addScalar(self: *const Self, scalar: T) Self {
            return .{ .x = self.x + scalar, .y = self.y + scalar };
        }

        pub fn getAngle(self: *const Self) f32 {
            return std.math.atan2(self.y, self.x);
        }

        pub fn rotate(self: *const Self, angle: f32) Self {
            const startAngle: f32 = self.getAngle();
            const len: T = self.length();
            return .{ .x = std.math.cos(startAngle + angle) * len, .y = std.math.sin(startAngle + angle) * len };
        }

        pub fn dot(a: Self, b: Self) T {
            return a.x * b.x + a.y * b.y;
        }

        pub fn add(a: Self, b: Self) Self {
            return .{ .x = a.x + b.x, .y = a.y + b.y };
        }

        pub fn subtract(a: Self, b: Self) Self {
            return .{ .x = a.x - b.x, .y = a.y - b.y };
        }
    };
}
