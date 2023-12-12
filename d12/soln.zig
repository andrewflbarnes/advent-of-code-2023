const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    try solve("d12/test1");
    // try solve("d12/test2");
    try solve("d12/input");
}
var check_ops: u64 = undefined;
fn solve(filename: []const u8) !void {
    check_ops = 0;
    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = false }){};
    defer std.debug.assert(.ok == gpa.deinit());
    const alloc = gpa.allocator();
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buffer: [256]u8 = undefined;
    var conditions = std.ArrayList(SpringConditions).init(alloc);
    defer conditions.deinit();

    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        try conditions.append(SpringConditions.from(line, &alloc));
        // break;
    }

    defer for (conditions.items) |c| c.deinit();

    var arrangements: u64 = 0;
    for (conditions.items, 0..) |c, i| {
        _ = i;
        const arr = try c.countArrangements();
        // print("{d} -> {d}\n", .{ i, arr });
        arrangements += arr;
    }
    print("{d} in {d} checks\n", .{ arrangements, check_ops });
}

const SpringConditions = struct {
    alloc: *const std.mem.Allocator,
    status: []const u8,
    damaged: []u8,
    count_damaged: usize,
    total_damaged: u8,
    count_unknown: usize,
    fn from(buf: []u8, alloc: *const std.mem.Allocator) SpringConditions {
        var chunks = std.mem.splitSequence(u8, buf, " ");
        const status_chunk = chunks.next().?;
        const status = alloc.alloc(u8, status_chunk.len) catch unreachable;
        @memcpy(status, status_chunk);
        const damaged = chunks.next().?;
        const damaged_groups = d: {
            var i: u8 = 1;
            for (damaged) |c| {
                if (c == ',') i += 1;
            }
            break :d i;
        };
        const damaged_vals = alloc.alloc(u8, damaged_groups) catch unreachable;
        var damaged_chunks = std.mem.splitSequence(u8, damaged, ",");
        {
            var i: u8 = 0;
            while (damaged_chunks.next()) |chunk| {
                const val = std.fmt.parseInt(u8, chunk, 10) catch unreachable;
                damaged_vals[i] = val;
                i += 1;
            }
        }
        const total_damaged = total_damaged: {
            var i: u8 = 0;
            for (damaged_vals) |v| i += v else break :total_damaged i;
        };
        const count_damaged = std.mem.count(u8, status, "#");
        const count_unknown = std.mem.count(u8, status, "?");
        return SpringConditions{
            .status = status,
            .damaged = damaged_vals,
            .alloc = alloc,
            .total_damaged = total_damaged,
            .count_unknown = count_unknown,
            .count_damaged = count_damaged,
        };
    }
    fn deinit(self: *const SpringConditions) void {
        self.alloc.free(self.damaged);
        self.alloc.free(self.status);
    }
    fn countArrangements(self: *const SpringConditions) !u64 {
        const bit_set = try self.alloc.alloc(bool, self.count_unknown);
        defer self.alloc.free(bit_set);
        @memset(bit_set, false);
        return try self.countArrangementsRec(bit_set, 0);
    }
    fn countArrangementsRec(self: *const SpringConditions, bit_set: []bool, next_bit: u8) !u64 {
        check_ops += 1;
        const bits_set: u8 = bits_set: {
            var i: u8 = 0;
            for (bit_set) |b| {
                if (b) i += 1;
            } else break :bits_set i;
        };

        const unknown_left = self.count_unknown - next_bit;
        const damaged_left = self.total_damaged - bits_set - self.count_damaged;
        if (unknown_left < damaged_left) {
            return 0;
        }

        if (self.total_damaged < bits_set + self.count_damaged) {
            return 0;
        }

        if (self.total_damaged == bits_set + self.count_damaged) {
            return try self.isValid(bit_set);
        }

        if (next_bit >= bit_set.len) {
            return 0;
        }

        bit_set[next_bit] = true;
        var arrangements: u64 = try self.countArrangementsRec(bit_set, next_bit + 1);

        bit_set[next_bit] = false;
        arrangements += try self.countArrangementsRec(bit_set, next_bit + 1);

        return arrangements;
    }

    fn isValid(self: *const SpringConditions, bit_set: []bool) !u64 {
        const test_status = try self.alloc.alloc(u8, self.status.len);
        defer self.alloc.free(test_status);
        @memcpy(test_status, self.status);
        var bit_idx: usize = 0;
        // print("Check validity of {s} -> ", .{test_status});
        for (test_status, 0..) |t, i| {
            if (t == '?') {
                if (bit_set[bit_idx]) {
                    test_status[i] = '#';
                } else {
                    test_status[i] = '.';
                }
                bit_idx += 1;
            }
        }
        // print("{s}\n", .{test_status});
        var chunks = std.mem.splitScalar(u8, test_status, '.');
        var check_index: usize = 0;
        while (chunks.next()) |chunk| {
            if (chunk.len > 0 and chunk[0] == '#') {
                if (chunk.len != self.damaged[check_index]) {
                    return 0;
                }
                check_index += 1;
            }
        }
        return if (check_index == self.damaged.len) 1 else 0;
    }
};
