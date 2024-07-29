const std = @import("std");
const vec = @import("vector.zig");

//TODO: Test all of this
pub const Mat4 = struct {
    r0: vec.Vector4,
    r1: vec.Vector4,
    r2: vec.Vector4,
    r3: vec.Vector4,

    pub fn multVector4(self: Mat4, v: vec.Vector4) vec.Vector4 {
        var out: vec.Vector3 = vec.Vector3.zero();

        out.x = self.r0.x * v.x + self.r1.x * v.y + self.r2.x * v.z + self.r3.x * v.w;
        out.y = self.r0.y * v.x + self.r1.y * v.y + self.r2.y * v.z + self.r3.y * v.w;
        out.z = self.r0.z * v.x + self.r1.z * v.y + self.r2.x * v.z + self.r3.z * v.w;
        out.w = self.r0.w * v.x + self.r1.w * v.y + self.r2.w * v.z + self.r3.w * v.w;

        return out;
    }

    pub fn identity() Mat4 {
        return .{
            .r0 = .{.x = 1.0, .y = 0.0, .z = 0.0, .w = 0.0},
            .r1 = .{.x = 0.0, .y = 1.0, .z = 0.0, .w = 0.0},
            .r2 = .{.x = 0.0, .y = 0.0, .z = 1.0, .w = 0.0},
            .r3 = .{.x = 0.0, .y = 0.0, .z = 0.0, .w = 1.0},
        };
    }

    //From https://en.wikipedia.org/wiki/Quaternions_and_spatial_rotation#Quaternion-derived_rotation_matrix
    pub fn fromQuat(q: vec.Vector4) Mat4 {
        return .{ //r=w, i=x, j=y, k=z
            .r0 = .{.x = 1.0-2*(q.y*q.y + q.z*q.z), .y = 2*(q.x*q.y - q.z*q.w),     .z = 2*(q.x*q.z + q.y*q.w),     .w = 0.0},
            .r1 = .{.x = 2*(q.x*q.y + q.z*q.w),     .y = 1.0-2*(q.x*q.x + q.z*q.z), .z = 2*(q.y*q.z - q.x*q.w),     .w = 0.0},
            .r2 = .{.x = 2*(q.x*q.z - q.y*q.w),     .y = 2*(q.y*q.z + q.x*q.w),     .z = 1.0-2*(q.x*q.x + q.y*q.y), .w = 0.0},
            .r3 = .{.x = 0.0,                       .y = 0.0,                       .z = 0.0,                       .w = 1.0},
        };
    }

    pub fn fromQuatAndPos(quat: vec.Vector4, pos: vec.Vector3) Mat4 {
        var out: Mat4 = fromQuat(quat);

        out.r0.w = pos.x;
        out.r1.w = pos.y;
        out.r2.w = pos.z;

        return out;
    }
};