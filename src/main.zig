const std = @import("std");
const vec = @import("vector.zig");
const c = @cImport({
    @cDefine("CNFG_IMPLEMENTATION", {});
    @cInclude("rawdraw_sf.h");
    @cInclude("stb_image.h");
});

export var CNFGPenX: c_int = 0;
export var CNFGPenY: c_int = 0;
export var CNFGBGColor: u32 = 0;
export var CNFGLastColor: u32 = 0;
export var CNFGDialogColor: u32 = 0;

var mouseX: i32 = 0;
var mouseY: i32 = 0;
var justClicked: bool = false;
var playing: usize = 0;

const Image = struct {
    data: []u8,
    width: usize,
    height: usize,
    timestamp: u64,
};

const pointRad: usize = 2;

const KeyPoint = struct {
    pos: vec.Vector2(f32),
    stereoPos: vec.Vector2(f32),
    descriptor: [(pointRad * 2 + 1) * (pointRad * 2 + 1)]u8,
};

export fn HandleKey(keycode: c_int, bDown: c_int) void {
    if (bDown == 1) {
        if (keycode == ' ') {
            if (playing == 0) {
                playing = 1;
            } else if (playing == 1) {
                playing = 0;
            }
        } else if (keycode == 's') {
            playing = 2;
        }
    }
}

export fn HandleButton(x: c_int, y: c_int, button: c_int, bDown: c_int) void {
    if (bDown == 1) {
        if (button == 1) {
            justClicked = true;
        }
    }
    mouseX = x;
    mouseY = y;
}

export fn HandleMotion(x: c_int, y: c_int, mask: c_int) void {
    _ = mask;
    mouseX = x;
    mouseY = y;
}
export fn HandleDestroy() void {}

fn genUndistortMap(allocator: std.mem.Allocator, width: usize, height: usize) ![]vec.Vector2(f32) {
    const widthFloat: f32 = @as(f32, @floatFromInt(width));
    const heightFloat: f32 = @as(f32, @floatFromInt(height));
    const half_width: f32 = @as(f32, @floatFromInt(width)) * 0.5;
    const half_height: f32 = @as(f32, @floatFromInt(height)) * 0.5;

    const k = -0.28340811;

    var map: []vec.Vector2(f32) = try allocator.alloc(vec.Vector2(f32), width * height);
    for (0..height) |y| {
        for (0..width) |x| {
            var pos: vec.Vector2(f32) = .{ .x = @as(f32, @floatFromInt(x)) - half_width, .y = @as(f32, @floatFromInt(y)) - half_height };
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

fn subSampleNearest(img: []const u8, pos: vec.Vector2(f32), width: usize, height: usize) u8 {
    const x: usize = std.math.clamp(@as(usize, @intFromFloat(@floor(pos.x))), 0, width);
    const y: usize = std.math.clamp(@as(usize, @intFromFloat(@floor(pos.y))), 0, height);

    return img[y * width + x];
}

fn applyUndistortMap(inImg: []const u8, outImg: Image, map: []vec.Vector2(f32)) void {
    for (0..outImg.height) |y| {
        for (0..outImg.width) |x| {
            const i: usize = y * outImg.width + x;
            outImg.data[i] = subSampleNearest(inImg, map[i], outImg.width, outImg.height);
        }
    }
}

fn calcPointErr(img: Image, x: usize, y: usize, point: KeyPoint) usize {
    var totalError: usize = 0;
    for (0..pointRad * 2 + 1) |descY| {
        for (0..pointRad * 2 + 1) |descX| {
            const imgX: usize = @as(usize, @intCast(@as(i64, @intCast(x)) + (@as(i64, @intCast(descX)) - @as(i64, @intCast(pointRad)))));
            const imgY: usize = @as(usize, @intCast(@as(i64, @intCast(y)) + (@as(i64, @intCast(descY)) - @as(i64, @intCast(pointRad)))));

            const imgVal: i16 = img.data[imgY * img.width + imgX];
            const pointVal: i16 = point.descriptor[descY * (pointRad * 2 + 1) + descX];
            const pixelError: u16 = @abs(imgVal - pointVal);
            totalError += pixelError;
        }
    }

    return totalError;
}

//FIXME: if rightBound or bottomBound is less than pointRad, underflow occurs
fn findBestPointMatch(img: Image, point: KeyPoint, topBound: usize, bottomBound: usize, leftBound: usize, rightBound: usize) vec.Vector2(f32) {
    var minErr: usize = std.math.maxInt(usize);
    var minErrX: usize = 0;
    var minErrY: usize = 0;
    for (topBound + pointRad..bottomBound - pointRad) |y| {
        for (leftBound + pointRad..rightBound - pointRad) |x| {
            const err: usize = calcPointErr(img, x, y, point);
            if (err < minErr) {
                minErr = err;
                minErrX = x;
                minErrY = y;
            }
        }
    }

    return .{ .x = @as(f32, @floatFromInt(minErrX)), .y = @as(f32, @floatFromInt(minErrY)) };
}

fn trackPoints(img: Image, points: std.ArrayList(KeyPoint)) void {
    const widthFloat: f32 = @as(f32, @floatFromInt(img.width));
    const heightFloat: f32 = @as(f32, @floatFromInt(img.height));
    const rad: f32 = 15.0;
    for (0..points.items.len) |i| {
        const point: KeyPoint = points.items[i];

        std.debug.print("{d:.1} {d:.1}\n", .{ point.pos.x, point.pos.y });
        const topBound: usize = @as(usize, @intFromFloat(std.math.clamp(point.pos.y - rad, 0.0, heightFloat)));
        const bottomBound: usize = @as(usize, @intFromFloat(std.math.clamp(point.pos.y + (rad + 1), 0.0, heightFloat)));
        const leftBound: usize = @as(usize, @intFromFloat(std.math.clamp(point.pos.x - rad, 0.0, widthFloat)));
        const rightBound: usize = @as(usize, @intFromFloat(std.math.clamp(point.pos.x + (rad + 1), 0.0, widthFloat)));

        const newPos: vec.Vector2(f32) = findBestPointMatch(img, point, topBound, bottomBound, leftBound, rightBound);

        points.items[i].pos = newPos;
        //setPointDescription(img, &points.items[i], @as(i64, @intCast(minErrX)), @as(i64, @intCast(minErrY)));
    }
}

fn stereoMatch(otherImg: Image, point: KeyPoint) vec.Vector2(f32) {
    const widthFloat: f32 = @as(f32, @floatFromInt(otherImg.width));
    const heightFloat: f32 = @as(f32, @floatFromInt(otherImg.height));
    const vertRad: f32 = pointRad * 2 + 1;

    const topBound: usize = @as(usize, @intFromFloat(std.math.clamp(point.pos.y - vertRad, 0.0, heightFloat)));
    const bottomBound: usize = @as(usize, @intFromFloat(std.math.clamp(point.pos.y + (vertRad + 1), 0.0, heightFloat)));

    const leftBound: usize = @as(usize, @intFromFloat(std.math.clamp(20.0, 0.0, widthFloat)));
    const rightBound: usize = @as(usize, @intFromFloat(std.math.clamp(point.pos.x + 1.0, 0.0, widthFloat)));

    const newPos: vec.Vector2(f32) = findBestPointMatch(otherImg, point, topBound, bottomBound, leftBound, rightBound);
    return newPos;
}

fn setPointDescriptor(img: Image, point: *KeyPoint, x: i64, y: i64) void {
    const width: i64 = @intCast(img.width);
    const height: i64 = @intCast(img.height);

    for (0..pointRad * 2 + 1) |descY| {
        for (0..pointRad * 2 + 1) |descX| {
            //std.math.clamp(x + (descX - pointRad), 0, img.width);
            const descXi: i64 = @intCast(descX);
            const descYi: i64 = @intCast(descY);
            const pointRadi: i64 = @intCast(pointRad);

            const imgX: usize = @intCast(std.math.clamp(x + (descXi - pointRadi), 0, width));
            const imgY: usize = @intCast(std.math.clamp(y + (descYi - pointRadi), 0, height));

            const imgVal: u8 = img.data[imgY * img.width + imgX];
            point.descriptor[descY * (pointRad * 2 + 1) + descX] = imgVal;
        }
    }
}

fn displayGrayscaleImage(img: Image, points: []KeyPoint, frameNum: usize) void {
    var buffer: [1024 * 1024]u32 = undefined;
    for (0..img.width * img.height) |i| {
        const val: u32 = img.data[i];
        buffer[i] = val << 16 | val << 8 | val;
    }

    c.CNFGBlitImage(&buffer, 0, 0, @as(c_int, @intCast(img.width)), @as(c_int, @intCast(img.height)));

    if (frameNum % 2 == 0) {
        _ = c.CNFGColor(0xFF_00_00_00);
        for (points) |point| {
            const x: c_short = std.math.clamp(@as(c_short, @intFromFloat(@floor(point.pos.x))), 0, @as(c_short, @intCast(img.width)));
            const y: c_short = std.math.clamp(@as(c_short, @intFromFloat(@floor(point.pos.y))), 0, @as(c_short, @intCast(img.height)));
            c.CNFGTackRectangle(x - 2, y - 2, x + 2, y + 2);
        }
    } else {
        _ = c.CNFGColor(0x00_FF_00_00);
        for (points) |point| {
            const x: c_short = std.math.clamp(@as(c_short, @intFromFloat(@floor(point.stereoPos.x))), 0, @as(c_short, @intCast(img.width)));
            const y: c_short = std.math.clamp(@as(c_short, @intFromFloat(@floor(point.stereoPos.y))), 0, @as(c_short, @intCast(img.height)));
            c.CNFGTackRectangle(x - 2, y - 2, x + 2, y + 2);
        }
    }
}

fn loadImage(path: [*c]const u8, widthOut: *usize, heightOut: *usize) []u8 {
    var n: c_int = 0;
    var width: c_int = 0;
    var height: c_int = 0;
    const data: [*c]u8 = c.stbi_load(path, &width, &height, &n, 1);
    widthOut.* = @as(usize, @intCast(width));
    heightOut.* = @as(usize, @intCast(height));
    return data[0..std.mem.len(data)];
}

fn loadImages(allocator: std.mem.Allocator, dir: std.fs.Dir) !std.ArrayList(Image) {
    var images: std.ArrayList(Image) = std.ArrayList(Image).init(allocator);

    const imageList: std.fs.File = try dir.openFile("data.csv", .{});
    var listBr = std.io.bufferedReader(imageList.reader());
    const listReader = listBr.reader();
    while (images.items.len < 100) {
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
                const timestamp: u64 = try std.fmt.parseInt(u64, trimmedLine[0..index], 10);
                var relativePathBuf: [1024]u8 = std.mem.zeroes([1024]u8);
                const filePathRel = try std.fmt.bufPrint(&relativePathBuf, "data/{s}", .{trimmedLine[index + 1 .. trimmedLine.len - 1]});

                filePath = try dir.realpath(filePathRel, &filePathBuf);

                //var img = try zigimg.Image.fromFilePath(allocator, filePath);
                //defer img.deinit();

                var image: Image = .{ .data = undefined, .width = 0, .height = 0, .timestamp = timestamp };
                const finalPath: [:0]u8 = try allocator.dupeZ(u8, filePath);
                defer allocator.free(finalPath);
                image.data = loadImage(finalPath, &image.width, &image.height);

                try images.append(image);
            } else {
                continue; //I guess it's a comment or something
            }
        } else {
            break;
        }
    }

    return images;
}

fn unloadImages(images: std.ArrayList(Image)) void {
    for (images.items) |img| {
        c.stbi_image_free(img.data.ptr);
    }
    images.deinit();
}

pub fn main() !void {
    var timer: std.time.Timer = try std.time.Timer.start();

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
    defer dataDir.close();

    var leftCamDir: std.fs.Dir = try dataDir.openDir("cam0/", .{});
    defer leftCamDir.close();

    std.debug.print("Loading left images...\n", .{});
    const leftImages: std.ArrayList(Image) = try loadImages(allocator, leftCamDir);
    defer unloadImages(leftImages);
    const width: usize = leftImages.items[0].width;
    const height: usize = leftImages.items[0].height;

    std.debug.print("Loading right images...\n", .{});

    var rightCamDir: std.fs.Dir = try dataDir.openDir("cam1/", .{});
    defer rightCamDir.close();

    const rightImages: std.ArrayList(Image) = try loadImages(allocator, rightCamDir);
    defer unloadImages(rightImages);

    std.debug.print("Done loading!\n", .{});

    const undistortMap: []vec.Vector2(f32) = try genUndistortMap(allocator, width, height);
    defer allocator.free(undistortMap);

    var points: std.ArrayList(KeyPoint) = std.ArrayList(KeyPoint).init(allocator);
    defer points.deinit();

    _ = c.CNFGSetup("Raw draw template", @as(c_int, @intCast(width)), @as(c_int, @intCast(height)));

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    _ = stdout;

    const initTime: u64 = timer.read();
    std.debug.print("Initialization took {d:.2} seconds. Starting main loop...\n", .{@as(f64, @floatFromInt(initTime)) / std.time.ns_per_s});

    var frameTimer: std.time.Timer = try std.time.Timer.start();
    var frameNum: usize = 0;
    while (c.CNFGHandleInput() != 0 and frameNum < leftImages.items.len) {
        _ = frameTimer.reset();
        c.CNFGClearFrame();

        var frame: Image = leftImages.items[frameNum];
        if (frameNum % 2 == 1) {
            frame = rightImages.items[frameNum];
        }

        var buf: [1024 * 1024]u8 = undefined;
        const undistortedImg: Image = .{ .data = &buf, .width = frame.width, .height = frame.height, .timestamp = 0 };
        applyUndistortMap(frame.data, undistortedImg, undistortMap);

        if (justClicked) {
            justClicked = false;
            if (frameNum % 2 == 0) {
                var point: KeyPoint = .{ .pos = .{ .x = @as(f32, @floatFromInt(mouseX)), .y = @as(f32, @floatFromInt(mouseY)) }, .stereoPos = undefined, .descriptor = undefined };
                setPointDescriptor(undistortedImg, &point, mouseX, mouseY);
                //point.stereoPos = stereoMatch(rightImages.items[frameNum / 2], point);
                applyUndistortMap(rightImages.items[frameNum / 2].data, undistortedImg, undistortMap);

                displayGrayscaleImage(undistortedImg, points.items, frameNum);
                c.CNFGSwapBuffers();

                while (!justClicked) {
                    if (c.CNFGHandleInput() == 0) {
                        break;
                    }
                }
                justClicked = false;
                point.stereoPos.x = @as(f32, @floatFromInt(mouseX));
                point.stereoPos.y = @as(f32, @floatFromInt(mouseY));

                applyUndistortMap(frame.data, undistortedImg, undistortMap);
                //std.debug.print("{}\n", .{});
                try points.append(point);
            }
        }

        trackPoints(undistortedImg, points);

        displayGrayscaleImage(undistortedImg, points.items, frameNum);

        c.CNFGSwapBuffers();
        const frameTime = frameTimer.read();
        if (frameTime < 50_000_000) { //16_666_666) {
            std.time.sleep(50_000_000 - frameTime); //20 fpss
        }

        if (playing > 0) {
            frameNum += 1;
        }

        if (playing == 2) {
            playing = 0;
        }

        std.debug.print("{}\n", .{frameNum});
    }

    const totalTime: u64 = timer.read();
    const totalTimeSec: f64 = @as(f64, @floatFromInt(totalTime)) / std.time.ns_per_s;
    const loopTimeSec: f64 = @as(f64, @floatFromInt(totalTime - initTime)) / std.time.ns_per_s;
    std.debug.print("Main loop processed {} frames in {d:.2} seconds ({d:.2} fps). Total execution time was {d:.2} seconds.\n", .{ frameNum, loopTimeSec, @as(f64, @floatFromInt(frameNum)) / loopTimeSec, totalTimeSec });

    try bw.flush();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
