const std = @import("std");
const print = std.debug.print;

const max_seeds: u8 = 32;
const max_steps: u8 = 16;
const max_ranges: u8 = 64;

pub fn main() !void {
    try solve("d05/test1");
    try solve("d05/input");
}

fn solve(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buffer: [256]u8 = undefined;

    var steps = [_][max_ranges]?RangeMap{[_]?RangeMap{null} ** max_ranges} ** max_steps;
    var seeds = [_]u64{0} ** max_seeds;
    var step_count: ?usize = null;
    var range_step: u8 = undefined;
    var ignore = false;
    var first = true;
    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        if (ignore) {
            ignore = false;
            continue;
        }
        if (first) {
            var step_chunks = std.mem.split(u8, line, ": ");
            _ = step_chunks.next();
            var seed_chunks = std.mem.split(u8, step_chunks.next().?, " ");
            var i: usize = 0;
            while (seed_chunks.next()) |seed| {
                seeds[i] = try std.fmt.parseInt(u64, seed, 10);
                i += 1;
            }
            first = false;
        } else if (line.len == 0) {
            ignore = true;
            range_step = 0;
            step_count = if (step_count) |s| s + 1 else 0;
        } else if (!ignore) {
            const rm = try RangeMap.from(line);
            steps[step_count.?][range_step] = rm;

            range_step += 1;
        }
    }

    var lowest = get_lowest(&seeds, false, &steps, step_count.?);
    print("lowest location is {d}\n", .{lowest});

    lowest = get_lowest(&seeds, true, &steps, step_count.?);
    print("lowest location over range is {d}\n", .{lowest});
}

fn get_lowest(seeds: []u64, as_range: bool, steps: *[max_steps][max_ranges]?RangeMap, step_count: usize) u64 {
    if (as_range) {
        for (0..0xffffffff) |lowest| {
            const seed = map_seed(lowest, steps, step_count, true);
            var i: usize = 0;
            while (seeds[i] > 0) {
                if (seed >= seeds[i] and seed <= seeds[i] + seeds[i + 1]) {
                    return lowest;
                }
                i += 2;
            }
        }
        unreachable;
    }

    // naive implemention preerved for history
    var lowest: u64 = 0xffffffff;
    for (seeds) |seed| {
        if (seed > 0) {
            const current = map_seed(seed, steps, step_count, false);
            if (current < lowest) {
                lowest = current;
            }
        } else {
            break;
        }
    }
    return lowest;
}

fn map_seed(seed: u64, steps: *[max_steps][max_ranges]?RangeMap, step_count: usize, reverse: bool) u64 {
    var current = seed;
    for (0..step_count + 1) |i| {
        const step_idx = if (reverse) step_count - i else i;
        for (steps[step_idx]) |range_map| {
            if (range_map) |rm| {
                const maybe_next = if (reverse) rm.dst_map(current) else rm.map(current);
                if (maybe_next) |next| {
                    current = next;
                    break;
                }
            }
        }
    }
    return current;
}

const RangeMap = struct {
    src_start: u64,
    src_end: u64,
    dst_start: u64,
    dst_end: u64,
    pub fn is_contained(self: *const RangeMap, src: u64) bool {
        return (src >= self.src_start and src <= self.src_end);
    }
    pub fn map(self: *const RangeMap, src: u64) ?u64 {
        if (!self.is_contained(src)) {
            return null;
        }
        return src - self.src_start + self.dst_start;
    }
    pub fn dst_is_contained(self: *const RangeMap, dst: u64) bool {
        return (dst >= self.dst_start and dst <= self.dst_end);
    }
    pub fn dst_map(self: *const RangeMap, dst: u64) ?u64 {
        if (!self.dst_is_contained(dst)) {
            return null;
        }
        return dst - self.dst_start + self.src_start;
    }
    pub fn from(buf: []const u8) !RangeMap {
        var range_chunks = std.mem.split(u8, buf, " ");
        const dst = range_chunks.next().?;
        const dst_start = try std.fmt.parseInt(u64, dst, 10);
        const src = range_chunks.next().?;
        const src_start = try std.fmt.parseInt(u64, src, 10);
        const range = range_chunks.next().?;
        const size = try std.fmt.parseInt(u64, range, 10);
        return RangeMap{
            .src_start = src_start,
            .src_end = src_start + size,
            .dst_start = dst_start,
            .dst_end = dst_start + size,
        };
    }
};
