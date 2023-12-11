const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    try solve("d10/test1");
    try solve("d10/test2");
    try solve("d10/test3");
    try solve("d10/test4");
    try solve("d10/test5");
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

    const map = buf[0..(width * height)];
    const start = getStartIndex(map);
    const start_pipe = getStartPipe(map, width, start);
    buf[start] = start_pipe;
    const chase = Chase.from(start, map, width, height);
    try chase.findFurthest();
}

fn getStartIndex(buffer: []u8) usize {
    var start: usize = 0;
    while (buffer[start] != 'S') {
        start += 1;
    }
    return start;
}

fn getStartPipe(buffer: []u8, width: usize, start: usize) u8 {
    var conn_left = false;
    var conn_right = false;
    var conn_top = false;
    var conn_bottom = false;
    if (start > 0) {
        const left = buffer[start - 1];
        if (left == '-' or left == 'F' or left == 'L') {
            conn_left = true;
        }
    }
    if (start >= width) {
        const top = buffer[start - width];
        if (top == 'F' or top == '|' or top == '7') {
            conn_top = true;
        }
    }
    if (start < buffer.len - 1) {
        const right = buffer[start + 1];
        if (right == '-' or right == 'J' or right == '7') {
            conn_right = true;
        }
    }
    if (start < buffer.len - width) {
        const bottom = buffer[start + width];
        if (bottom == '|' or bottom == 'J' or bottom == 'L') {
            conn_bottom = true;
        }
    }
    if (conn_left) {
        if (conn_bottom) return '7';
        if (conn_right) return '-';
        if (conn_top) return 'J';
        unreachable;
    }
    if (conn_top) {
        if (conn_bottom) return '|';
        if (conn_right) return 'L';
        unreachable;
    }
    if (conn_right) {
        if (conn_bottom) return 'F';
        unreachable;
    }
    unreachable;
}

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
        if (self.start > 0) {
            if (self.checkLoc(self.start - 1, '-', 'L', 'F')) |point| left = point;
        }
        if (self.start < self.map.len - 1) {
            if (self.checkLoc(self.start + 1, '-', 'J', '7')) |point| {
                if (left == null) {
                    left = point;
                } else {
                    right = point;
                }
            }
        }
        if (self.start >= self.width) {
            if (self.checkLoc(self.start - self.width, '|', 'F', '7')) |point| {
                if (left == null) {
                    left = point;
                } else if (right == null) {
                    right = point;
                } else {
                    unreachable;
                }
            }
        }
        if (self.start < self.map.len - self.width) {
            if (self.checkLoc(self.start + self.width, '|', 'J', 'L')) |point| {
                if (left == null) {
                    left = point;
                } else if (right == null) {
                    right = point;
                } else {
                    unreachable;
                }
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
        var loop_buf = [_]usize{0} ** (256 * 256);
        loop_buf[0] = self.start;
        loop_buf[1] = l_idx;
        loop_buf[2] = r_idx;
        var loop_buf_i: usize = 3;
        while (l_idx != r_idx) {
            count += 1;
            last = l_idx;
            l_idx = self.next(l_last, l_idx);
            if (!sliceContains(usize, loop_buf[0..loop_buf_i], l_idx)) {
                loop_buf[loop_buf_i] = l_idx;
                loop_buf_i += 1;
            }
            l_last = last;
            last = r_idx;
            r_idx = self.next(r_last, r_idx);
            if (!sliceContains(usize, loop_buf[0..loop_buf_i], r_idx)) {
                loop_buf[loop_buf_i] = r_idx;
                loop_buf_i += 1;
            }
            r_last = last;
        }
        print("Steps {d} until same point\n", .{count});

        const enclosed = self.findEnclosed(loop_buf[0..loop_buf_i]);
        print("{d} enclosed tiles\n", .{enclosed});
    }
    fn checkLoc(self: *const Chase, point: usize, c1: u8, c2: u8, c3: u8) ?usize {
        if (point < 0 or point > self.map.len) return null;
        var check: u8 = self.map[point];
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
    fn findEnclosed(self: *const Chase, loop: []usize) u64 {
        var in = false;
        var count: u64 = 0;
        var last_corner: u8 = '.';
        for (self.map, 0..) |_, i| {
            const new_row = i % self.width == 0;
            if (new_row) {
                in = false;
            }
            const current = self.map[i];
            if (sliceContains(usize, loop, i)) {
                if (current == 'J') {
                    if (last_corner != 'L') {
                        in = !in;
                    }
                    last_corner = '.';
                } else if (current == '7') {
                    if (last_corner != 'F') {
                        in = !in;
                    }
                    last_corner = '.';
                } else if (current != '-' and current != 'F' and current != 'L') {
                    in = !in;
                }
                if (current == 'F' or current == 'L') {
                    last_corner = current;
                }
            } else if (in) {
                count += 1;
            }
        }
        return count;
    }
};

fn sliceContains(comptime T: type, slice: []T, val: T) bool {
    for (slice) |s| {
        if (s == val) {
            return true;
        }
    }
    return false;
}
