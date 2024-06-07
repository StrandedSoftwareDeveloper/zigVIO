const std = @import("std");
const zigimg = @import("zigimg");
const vec = @import("vector.zig");
const c = @cImport({
    @cDefine("CNFG_IMPLEMENTATION", {});
    @cInclude("rawdraw_sf.h");
});

export var CNFGPenX: c_int = 0;
export var CNFGPenY: c_int = 0;
export var CNFGBGColor: u32 = 0;
export var CNFGLastColor: u32 = 0;
export var CNFGDialogColor: u32 = 0;

var mouseX: i32 = 0;
var mouseY: i32 = 0;

const Image = struct {
    data: []u8,
    width: usize,
    height: usize,
    timestamp: u64,
};

export fn HandleKey(keycode: c_int, bDown: c_int) void {
    _ = bDown;
    _ = keycode;
}

export fn HandleButton(x: c_int, y: c_int, button: c_int, bDown: c_int) void {
    _ = bDown;
    _ = button;
    _ = y;
    _ = x;
}

export fn HandleMotion(x: c_int, y: c_int, mask: c_int) void {
    _ = mask;
    mouseX = x;
    mouseY = y;
}
export fn HandleDestroy() void {}

fn genUndistortMap(allocator: std.mem.Allocator, width: usize, height: usize) ![]vec.Vector2 {
    const widthFloat: f32 = @as(f32, @floatFromInt(width));
    const heightFloat: f32 = @as(f32, @floatFromInt(height));
    const half_width: f32 = @as(f32, @floatFromInt(width)) * 0.5;
    const half_height: f32 = @as(f32, @floatFromInt(height)) * 0.5;

    const k = -0.28340811;

    var map: []vec.Vector2 = try allocator.alloc(vec.Vector2, width * height);
    for (0..height) |y| {
        for (0..width) |x| {
            var pos: vec.Vector2 = .{ .x = @as(f32, @floatFromInt(x)) - half_width, .y = @as(f32, @floatFromInt(y)) - half_height };
            pos.x /= widthFloat;
            pos.y /= heightFloat;

            var rad: f32 = pos.length();
            var theta: f32 = std.math.atan(pos.y / pos.x);
            if (pos.x < 0.0) {
                theta += std.math.pi;
            }

            rad = rad * (1.0 + k * (rad * rad));

            pos.x = std.math.cos(theta) * rad;
            pos.y = std.math.sin(theta) * rad;

            pos.x *= widthFloat;
            pos.y *= heightFloat;
            pos.x = std.math.clamp(pos.x + half_width, 0.0, widthFloat - 1.0);
            pos.y = std.math.clamp(pos.y + half_height, 0.0, heightFloat - 1.0);
            map[y * width + x] = pos;
        }
    }
    return map;
}

//Assumes that 0 <= t <= 1
fn u8lerp(a: u8, b: u8, t: f32) u8 {
    const aFloat: f32 = @floatFromInt(a);
    const bFloat: f32 = @floatFromInt(b);
    const out: f32 = std.math.lerp(aFloat, bFloat, t);
    return @as(u8, @intFromFloat(@round(out)));
}

fn subSampleLinear(img: []const u8, pos: vec.Vector2, width: usize, height: usize) u8 {
    //0 1
    //2 3
    const x0: usize = std.math.clamp(@as(usize, @intFromFloat(@floor(pos.x))), 0, width);
    const y0: usize = std.math.clamp(@as(usize, @intFromFloat(@floor(pos.y))), 0, height);

    const x1: usize = std.math.clamp(@as(usize, @intFromFloat(@ceil(pos.x))), 0, width);
    const y1: usize = std.math.clamp(@as(usize, @intFromFloat(@floor(pos.y))), 0, height);

    const x2: usize = std.math.clamp(@as(usize, @intFromFloat(@floor(pos.x))), 0, width);
    const y2: usize = std.math.clamp(@as(usize, @intFromFloat(@ceil(pos.y))), 0, height);

    const x3: usize = std.math.clamp(@as(usize, @intFromFloat(@ceil(pos.x))), 0, width);
    const y3: usize = std.math.clamp(@as(usize, @intFromFloat(@ceil(pos.y))), 0, height);

    const s0: u8 = img[y0 * width + x0];
    const s1: u8 = img[y1 * width + x1];
    const s2: u8 = img[y2 * width + x2];
    const s3: u8 = img[y3 * width + x3];

    const t0: u8 = u8lerp(s0, s1, std.math.modf(pos.x).fpart);
    const t1: u8 = u8lerp(s2, s3, std.math.modf(pos.x).fpart);

    return u8lerp(t0, t1, std.math.modf(pos.y).fpart);
}

fn subSampleNearest(img: []const u8, pos: vec.Vector2, width: usize, height: usize) u8 {
    const x: usize = std.math.clamp(@as(usize, @intFromFloat(@floor(pos.x))), 0, width);
    const y: usize = std.math.clamp(@as(usize, @intFromFloat(@floor(pos.y))), 0, height);

    return img[y * width + x];
}

fn applyUndistortMap(inImg: []const u8, outImg: Image, map: []vec.Vector2) void {
    for (0..outImg.height) |y| {
        for (0..outImg.width) |x| {
            const i: usize = y * outImg.width + x;
            outImg.data[i] = subSampleNearest(inImg, map[i], outImg.width, outImg.height);
        }
    }
}

fn displayGrayscaleImage(img: Image) void {
    var buffer: [1024 * 1024]u32 = undefined;
    for (0..img.width * img.height) |i| {
        const val: u32 = img.data[i];
        buffer[i] = val << 16 | val << 8 | val;
    }
    c.CNFGBlitImage(&buffer, 0, 0, @as(c_int, @intCast(img.width)), @as(c_int, @intCast(img.height)));
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        _ = gpa.deinit();
    }

    // Parse args into string array (error union needs 'try')
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var dirPath: []const u8 = "in.png";
    if (args.len > 1) {
        dirPath = args[1];
    }

    std.debug.print("Opening \"{s}\"...\n", .{dirPath});

    var dataDir: std.fs.Dir = try std.fs.openDirAbsolute(dirPath, .{});

    const imageList: std.fs.File = try dataDir.openFile("cam0/data.csv", .{});
    var listBr = std.io.bufferedReader(imageList.reader());
    const listReader = listBr.reader();

    const startFilePath: []const u8 = try dataDir.realpathAlloc(allocator, "reenc/cam0/data/1403636579763555584.png");
    defer allocator.free(startFilePath);

    var startImg = try zigimg.Image.fromFilePath(allocator, startFilePath);
    defer startImg.deinit();
    std.debug.print("Pixel format: {}\n", .{startImg.pixelFormat()});

    const undistortMap: []vec.Vector2 = try genUndistortMap(allocator, startImg.width, startImg.height);
    defer allocator.free(undistortMap);

    _ = c.CNFGSetup("Raw draw template", @as(c_int, @intCast(startImg.width)), @as(c_int, @intCast(startImg.height)));

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    _ = stdout;

    var frameTimer: std.time.Timer = try std.time.Timer.start();
    var frameNum: usize = 0;
    while (c.CNFGHandleInput() != 0) {
        _ = frameTimer.reset();
        c.CNFGClearFrame();

        var filePathBuf: [1024]u8 = std.mem.zeroes([1024]u8);

        var lineBuf: [1024]u8 = std.mem.zeroes([1024]u8);
        var filePath: []const u8 = undefined;
        const lineOptional = try listReader.readUntilDelimiterOrEof(&lineBuf, '\n');
        if (lineOptional) |line| {
            const trimmedLine: []const u8 = std.mem.trim(u8, line, " ");
            if (trimmedLine[0] == '#') {
                continue;
            }

            if (std.mem.indexOf(u8, trimmedLine, ",")) |index| {
                const timeStamp: u64 = try std.fmt.parseInt(u64, trimmedLine[0..index], 10);
                _ = timeStamp;
                var relativePathBuf: [1024]u8 = std.mem.zeroes([1024]u8);
                const filePathRel = try std.fmt.bufPrint(&relativePathBuf, "reenc/cam0/data/{s}", .{trimmedLine[index + 1 .. trimmedLine.len - 1]});

                filePath = try dataDir.realpath(filePathRel, &filePathBuf);
            } else {
                continue; //I guess it's a comment or something
            }
        } else {
            break;
        }

        var img = try zigimg.Image.fromFilePath(allocator, filePath);
        defer img.deinit();

        var buf: [1024 * 1024]u8 = undefined;
        const undistortedImg: Image = .{ .data = &buf, .width = img.width, .height = img.height, .timestamp = 0 };
        applyUndistortMap(img.rawBytes(), undistortedImg, undistortMap);
        displayGrayscaleImage(undistortedImg);

        c.CNFGSwapBuffers();
        const frameTime = frameTimer.read();
        if (frameTime < 16_666_666) {
            std.time.sleep(16_666_666 - frameTime);
        }
        frameNum += 1;
        std.debug.print("{}\n", .{frameNum});
    }

    try bw.flush();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
