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
        const arr = try c.countArrangements();
        print("######## {d} -> {d}\n", .{ i, arr });
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
        // include a buffer "." either side for checks
        const status = alloc.alloc(u8, status_chunk.len + 2) catch unreachable;
        @memcpy(status[1 .. status_chunk.len + 1], status_chunk);
        status[0] = '.';
        status[status.len - 1] = '.';
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
        // include a buffer "." either side for checks
        const mask = try self.alloc.alloc(u8, self.total_damaged + self.damaged.len + 1);
        defer self.alloc.free(mask);
        @memset(mask, '#');
        mask[0] = '.';
        mask[mask.len - 1] = '.';
        var placements = try self.alloc.alloc([]const u8, self.damaged.len);
        defer self.alloc.free(placements);
        var i: usize = 0;
        for (self.damaged[0 .. self.damaged.len - 1], 0..) |d, ii| {
            mask[i + d + 1] = '.';
            placements[ii] = mask[i .. i + d + 2];
            i += d + 1;
        }
        // print("{s}\n", .{self.status});
        // print("{s}\n", .{mask});
        placements[placements.len - 1] = mask[i..mask.len];
        // for (placements) |p| {
        //     print("p {s}\n", .{p});
        // }
        return self.countPlacements(placements, mask.len, self.status[0..], 0);

        // print("{s} for {any}\n", .{ mask, self.damaged });
        // print("{s}\n", .{self.status});

        // var tokens = std.mem.tokenize(u8, self.status, ".");
        // while (tokens.next()) |token| {
        //     print("{s} ", .{token});
        // }
        // print("\n", .{});

        // return 1;
        // // return try self.countArrangementsRec(bit_set, 0);
    }
    fn countPlacements(self: *const SpringConditions, placements: [][]const u8, placement_fit: usize, status: []const u8, blen: u8) u64 {
        var obuf = self.alloc.alloc(u8, blen) catch unreachable;
        defer self.alloc.free(obuf);
        @memset(obuf, ' ');
        const placement = placements[0];
        const rest = placements[1..];
        const placement_tests = status.len - placement_fit + 1;
        const placement_size = placement.len;
        var valid_locations: u64 = 0;
        // print("{s}Checking placements {s} into {s} for {d} positions\n", .{ obuf, placement, status, placement_tests });
        for (0..placement_tests) |position| {
            // print("{s} Checking placement {s} into position {d}: {s}\n", .{ obuf, placement, position, status[position .. position + placement_size] });
            if (position > 0 and status[position] == '#') {
                // print("{s}  Invalid - spring left behind\n", .{obuf});
                break;
            }
            if (rest.len == 0) {
                if (std.mem.indexOf(u8, status[position + placement_size ..], "#") != null) {
                    // print("{s}  Invalid - remaining springs\n", .{obuf});
                    continue;
                }
            }
            if (self.isValid(placement, status[position .. position + placement_size])) {
                // print("{s}  Valid\n", .{obuf});
                if (rest.len == 0) {
                    // print("{s}   INCREMENT\n", .{obuf});
                    valid_locations += 1;
                } else {
                    // note - we need to adjust values, to "reuse" the '.' terminator on the end
                    valid_locations += self.countPlacements(
                        rest,
                        placement_fit - placement_size + 1,
                        status[position + placement_size - 1 ..],
                        blen + 3,
                    );
                }
            } else {
                // print("{s}  Invalid\n", .{obuf});
            }
        }
        return valid_locations;
    }
    fn isValid(self: *const SpringConditions, placement: []const u8, status: []const u8) bool {
        _ = self;
        for (placement, 0..) |p, i| {
            if (p == '#' and status[i] == '.') {
                return false;
            }
            if (p == '.' and status[i] == '#') {
                return false;
            }
        }
        return true;
    }
};
