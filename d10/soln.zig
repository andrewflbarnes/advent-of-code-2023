const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    try solve("d10/test1");
    try solve("d10/test2");
    try solve("d10/test3");
    try solve("d10/input");
}

fn solve(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buf = [_]u8{0} ** (256 * 256);
    var buffer: []u8 = buf[0..];

    var width: usize = undefined;
    var height: usize = 0;
    while (try in_stream.readUntilDelimiterOrEof(buffer, '\n')) |line| {
        height += 1;
        width = line.len;
        buffer = buffer[line.len..];
    }

    const start = getStartIndex(buf[0..]);
    const chase = Chase.from(start, buf[0..], width, height);
    try chase.findFurthest();
}

fn getStartIndex(buffer: []u8) usize {
    var start: usize = 0;
    while (buffer[start] != 'S') {
        start += 1;
    }
    return start;
}

// const Coord = struct {
//     x: usize,
//     y: usize,
//     fn at(buf_pos: usize, width: usize) Coord {
//         return Coord{
//             .x = buf_pos % width,
//             .y = buf_pos / width,
//         };
//     }
//     fn of(x: usize, y: usize) Coord {
//         return Coord{
//             .x = x,
//             .y = y,
//         };
//     }
// };

const Chase = struct {
    start: usize,
    map: []u8,
    width: usize,
    height: usize,
    fn from(start: usize, map: []u8, width: usize, height: usize) Chase {
        return Chase{
            .start = start,
            .map = map,
            .width = width,
            .height = height,
        };
    }
    fn findFurthest(self: *const Chase) !void {
        var left: ?usize = null;
        var right: ?usize = null;
        if (self.checkLoc(self.start - 1, '-', 'L', 'F')) |point| {
            left = point;
        }
        if (self.checkLoc(self.start + 1, '-', 'J', '7')) |point| {
            if (left == null) {
                left = point;
            } else {
                right = point;
            }
        }
        if (self.checkLoc(self.start - self.width, '|', 'F', '7')) |point| {
            if (left == null) {
                left = point;
            } else if (right == null) {
                right = point;
            } else {
                unreachable;
            }
        }
        if (self.checkLoc(self.start + self.width, '|', 'J', 'L')) |point| {
            if (left == null) {
                left = point;
            } else if (right == null) {
                right = point;
            } else {
                unreachable;
            }
        }
        if (right == null) {
            unreachable;
        }

        var count: u64 = 1;
        var l_last = self.start;
        var l_idx = left.?;
        var r_last = self.start;
        var r_idx = right.?;
        var last: usize = 0;
        while (l_idx != r_idx) {
            count += 1;
            last = l_idx;
            l_idx = self.next(l_last, l_idx);
            l_last = last;
            last = r_idx;
            r_idx = self.next(r_last, r_idx);
            r_last = last;
        }
        print("Steps {d} until same point\n", .{count});
    }
    fn checkLoc(self: *const Chase, point: usize, c1: u8, c2: u8, c3: u8) ?usize {
        if (point < 0 or point > self.map.len) return null;
        var check: u8 = self.map[point];
        // print("Checking point {d}({c}) for {c}{c}{c}\n", .{ point, check, c1, c2, c3 });
        return if (check == c1 or check == c2 or check == c3) point else null;
    }
    fn next(self: *const Chase, last: usize, current: usize) usize {
        if (current > 0 and last == current - 1) {
            return switch (self.map[current]) {
                '-' => current + 1,
                'J' => current - self.width,
                '7' => current + self.width,
                else => unreachable,
            };
        }
        if (current < self.map.len - 1 and last == current + 1) {
            return switch (self.map[current]) {
                '-' => current - 1,
                'L' => current - self.width,
                'F' => current + self.width,
                else => unreachable,
            };
        }
        if (current >= self.width and last == current - self.width) {
            return switch (self.map[current]) {
                '|' => current + self.width,
                'L' => current + 1,
                'J' => current - 1,
                else => unreachable,
            };
        }
        if (current < self.map.len - self.width and last == current + self.width) {
            return switch (self.map[current]) {
                '|' => current - self.width,
                'F' => current + 1,
                '7' => current - 1,
                else => unreachable,
            };
        }
        unreachable;
    }
};
