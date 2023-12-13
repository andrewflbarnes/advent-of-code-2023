const std = @import("std");
const print = std.debug.print;
const Map = std.StringHashMap(u64);

pub fn main() !void {
    try solve("d12/test1");
    try solve("d12/input");
}
fn solve(filename: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = false }){};
    defer std.debug.assert(.ok == gpa.deinit());
    var gpa_alloc = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    var alloc = arena.allocator();

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buffer: [256]u8 = undefined;
    var conditions = std.ArrayList(SpringConditions).init(alloc);
    defer conditions.deinit();

    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        try conditions.append(try SpringConditions.from(line, &alloc));
    }

    defer for (conditions.items) |c| c.deinit();

    var arrangements: u64 = 0;
    for (conditions.items, 0..) |c, i| {
        _ = i;
        const arr = try c.countArrangements(1);
        // print("######## {d} -> {d}\n", .{ i, arr });
        arrangements += arr;
    }
    print("Arrangements: {d}\n", .{arrangements});

    arrangements = 0;
    for (conditions.items, 0..) |c, i| {
        _ = i;
        const arr = try c.countArrangements(5);
        // print("######## {d} -> {d}\n", .{ i, arr });
        arrangements += arr;
    }
    print("Large arrangements: {d}\n", .{arrangements});
}

const SpringConditions = struct {
    alloc: *std.mem.Allocator,
    status: []const u8,
    damaged: []u8,
    count_damaged: usize,
    total_damaged: u8,
    count_unknown: usize,
    fn from(buf: []u8, alloc: *std.mem.Allocator) !SpringConditions {
        var chunks = std.mem.splitSequence(u8, buf, " ");
        const status_chunk = chunks.next().?;
        const status = try alloc.alloc(u8, status_chunk.len);
        @memcpy(status, status_chunk);
        const damaged = chunks.next().?;
        const damaged_groups = d: {
            var i: u8 = 1;
            for (damaged) |c| {
                if (c == ',') i += 1;
            }
            break :d i;
        };
        const damaged_vals = try alloc.alloc(u8, damaged_groups);
        var damaged_chunks = std.mem.splitSequence(u8, damaged, ",");
        {
            var i: u8 = 0;
            while (damaged_chunks.next()) |chunk| {
                const val = try std.fmt.parseInt(u8, chunk, 10);
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
    fn countArrangements(self: *const SpringConditions, size: u8) !u64 {
        const single_mask_size = self.total_damaged + self.damaged.len - 1;
        const mask = try self.alloc.alloc(u8, size * (1 + single_mask_size) + 1);
        defer self.alloc.free(mask);
        @memset(mask, '#');
        for (0..size + 1) |i| {
            mask[i * (1 + single_mask_size)] = '.';
        }
        var placements = try self.alloc.alloc([]const u8, self.damaged.len * size);
        defer self.alloc.free(placements);
        for (0..size) |s| {
            var i: usize = s * (single_mask_size + 1);
            const placement_offset = s * self.damaged.len;
            for (self.damaged[0 .. self.damaged.len - 1], 0..) |d, ii| {
                mask[i + d + 1] = '.';
                placements[placement_offset + ii] = mask[i .. i + d + 2];
                i += d + 1;
            }
            placements[placement_offset + self.damaged.len - 1] = mask[i .. 1 + (s + 1) * (single_mask_size + 1)];
        }
        const big_status = try self.alloc.alloc(u8, size * (self.status.len + 1) + 1);
        defer self.alloc.free(big_status);
        for (0..size) |s| {
            const start = 1 + s * (self.status.len + 1);
            @memcpy(big_status[start .. start + self.status.len], self.status[0..self.status.len]);
            if (s < size - 1) {
                big_status[start + self.status.len] = '?';
            }
        }
        big_status[0] = '.';
        big_status[big_status.len - 1] = '.';

        var cache = Map.init(self.alloc.*);
        defer cache.deinit();
        return try self.countPlacements(placements, mask.len, big_status[0..], &cache, 0);
    }
    fn countPlacements(self: *const SpringConditions, placements: [][]const u8, placement_fit: usize, status: []const u8, cache: *Map, blen: u8) !u64 {
        var cache_key = try std.fmt.allocPrint(self.alloc.*, "{any}{s}", .{ placements, status });
        if (cache.get(cache_key)) |v| {
            return v;
        }
        var obuf = try self.alloc.alloc(u8, blen);
        defer self.alloc.free(obuf);
        @memset(obuf, ' ');
        const placement = placements[0];
        const rest = placements[1..];
        const placement_tests = status.len - placement_fit + 1;
        const placement_size = placement.len;
        var valid_locations: u64 = 0;
        // print("{s}Checking placements {s} into {s} for {d} positions\n", .{ obuf, placement, status, placement_tests });
        var position: usize = 0;
        while (position < placement_tests) {
            // print("{s} Checking placement {s} into position {d}: {s}\n", .{ obuf, placement, position, status[position .. position + placement_size] });
            if (position > 0 and status[position] == '#') {
                // print("{s}  Invalid - spring left behind\n", .{obuf});
                break;
            }
            if (rest.len == 0) {
                if (std.mem.indexOf(u8, status[position + placement_size ..], "#") != null) {
                    // print("{s}  Invalid - remaining springs\n", .{obuf});
                    position += 1;
                    continue;
                }
            }
            const status_check = status[position .. position + placement_size];
            if (self.isValid(placement, status_check)) {
                // print("{s}  Valid\n", .{obuf});
                if (rest.len == 0) {
                    // print("{s}   INCREMENT\n", .{obuf});
                    valid_locations += 1;
                } else {
                    // note - we need to adjust values, to "reuse" the '.' terminator on the end
                    valid_locations += try self.countPlacements(
                        rest,
                        placement_fit - placement_size + 1,
                        status[position + placement_size - 1 ..],
                        cache,
                        blen + 3,
                    );
                }
            } else {
                // print("{s}  Invalid\n", .{obuf});
            }
            position += 1;
        }
        try cache.put(cache_key, valid_locations);
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
