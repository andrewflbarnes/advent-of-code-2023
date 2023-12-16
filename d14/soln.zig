const std = @import("std");
const print = std.debug.print;
const utils = @import("../utils.zig");

pub fn main() !void {
    try solve("d14/test1");
    try solve("d14/input");
}

fn solve(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buf: [128 * 128]u8 = undefined;
    var buffer: []u8 = buf[0..];

    var width: usize = 0;
    var height: usize = 0;
    while (try in_stream.readUntilDelimiterOrEof(buffer, '\n')) |line| {
        buffer = buffer[line.len..];
        width = line.len;
        height += 1;
    }

    var map = buf[0 .. height * width];

    const sum = try tiltNorthSum(map, width, height);
    print("Tilt north sum: {}\n", .{sum});

    const spin_sum = try spinCycleSum(map, width, height);
    print("Spin sum: {}\n", .{spin_sum});
}

fn tiltNorthSum(map_original: []u8, width: usize, height: usize) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(.ok == gpa.deinit());
    const alloc = gpa.allocator();

    const map = try alloc.alloc(u8, map_original.len);
    defer alloc.free(map);
    @memcpy(map, map_original);

    tilt(map, width, height, .north);
    return rollSum(map, width, height);
}

fn rollSum(map: []const u8, width: usize, height: usize) u64 {
    var sum: u64 = 0;

    for (0..height) |row| {
        for (0..width) |col| {
            if (map[row * width + col] == 'O') {
                sum += height - row;
            }
        }
    }

    return sum;
}

fn spinCycleSum(map_original: []u8, width: usize, height: usize) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(.ok == gpa.deinit());
    const alloc = gpa.allocator();
    var cache = std.StringHashMap(u64).init(alloc);
    defer cache.deinit();
    var rev_cache = std.AutoHashMap(u64, [*]u8).init(alloc);
    defer rev_cache.deinit();
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const cache_alloc = arena.allocator();

    const map = try alloc.alloc(u8, map_original.len);
    defer alloc.free(map);
    @memcpy(map, map_original);
    var spun_map: []u8 = map[0..];

    const iters = 1000000000;
    for (0..iters) |it| {
        // print("rollsum after iter {}: {}\n", .{ it, rollSum(spun_map, width, height) });
        if (cache.get(spun_map)) |cached| {
            var iters_left = iters - it;
            const iter_loop_size = it - cached;
            iters_left = iters_left % iter_loop_size;
            print("Found cache after iteration {}->{}, {} left\n", .{ it, cached, iters_left });
            const final_iter = iters_left + cached;
            print("Final at it {}\n", .{final_iter});
            const final_map = rev_cache.get(final_iter).?[0 .. width * height];
            return rollSum(final_map, width, height);
        }
        try cache.put(spun_map, it);
        try rev_cache.put(it, spun_map.ptr);

        var to_spin_map = try cache_alloc.alloc(u8, map.len);
        @memcpy(to_spin_map, spun_map);
        spinCycle(to_spin_map, width, height);
        spun_map = to_spin_map;
    }
    unreachable;
}

fn spinCycle(map: []u8, width: usize, height: usize) void {
    tilt(map, width, height, .north);
    tilt(map, width, height, .west);
    tilt(map, width, height, .south);
    tilt(map, width, height, .east);
}

fn tilt(map: []u8, width: usize, height: usize, dir: TiltDirection) void {
    switch (dir) {
        .north, .south => {
            for (0..width) |col| {
                var last_free: ?usize = null;
                for (0..height) |row| {
                    const dir_row = if (.north == dir) row else height - row - 1;
                    last_free = iterTilt(
                        map,
                        width,
                        dir_row,
                        col,
                        last_free,
                        width,
                        .south == dir,
                    );
                }
            }
        },
        .west, .east => {
            for (0..height) |row| {
                var last_free: ?usize = null;
                for (0..width) |col| {
                    const dir_col = if (.west == dir) col else width - col - 1;
                    last_free = iterTilt(
                        map,
                        width,
                        row,
                        dir_col,
                        last_free,
                        1,
                        .east == dir,
                    );
                }
            }
        },
    }
}

fn iterTilt(map: []u8, width: usize, row: usize, col: usize, last_free: ?usize, next_free_inc: usize, next_free_rev: bool) ?usize {
    const pos = row * width + col;
    const m = map[pos];
    var next_free: ?usize = last_free;
    switch (m) {
        '#' => next_free = null,
        'O' => {
            if (last_free) |last_free_pos| {
                map[last_free_pos] = 'O';
                map[pos] = '.';
                var check: usize = if (next_free_rev) last_free_pos - next_free_inc else last_free_pos + next_free_inc;
                while ((!next_free_rev and check <= pos) or (next_free_rev and check >= pos)) {
                    if (map[check] == '.') {
                        next_free = check;
                        break;
                    }
                    check = if (next_free_rev) check - next_free_inc else check + next_free_inc;
                } else {
                    next_free = null;
                }
            }
        },
        '.' => next_free = if (last_free == null) pos else last_free,
        else => unreachable,
    }
    return next_free;
}

fn dump(map: []const u8, height: usize, width: usize) void {
    for (0..height) |row| {
        print("{s}\n", .{map[row * width .. (row + 1) * width]});
    }
    print("\n", .{});
}

const TiltDirection = enum {
    north,
    west,
    south,
    east,
};
