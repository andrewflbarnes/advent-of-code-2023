const std = @import("std");
const print = std.debug.print;
const utils = @import("../utils.zig");

pub fn main() !void {
    try solve("d11/test1");
    try solve("d11/input");
}

fn solve(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buffer = [_]u8{0} ** (256 * 256);
    var read_buffer: []u8 = buffer[0..];
    var universe_width: usize = 0;
    var universe_height: usize = 0;

    while (try in_stream.readUntilDelimiterOrEof(read_buffer, '\n')) |line| {
        read_buffer = read_buffer[line.len..];
        universe_width = line.len;
        universe_height += 1;
    }

    var universe = buffer[0..(universe_height * universe_width)];

    var universe_empty_rows = [_]usize{999} ** 256;
    var universe_empty_row_count: usize = 0;
    for (0..universe_height) |row| {
        if (utils.sliceEqualsAll(u8, universe[row * universe_width .. (row + 1) * universe_width], '.')) {
            universe_empty_rows[universe_empty_row_count] = row;
            universe_empty_row_count += 1;
        }
    }
    const uer: []usize = universe_empty_rows[0..universe_empty_row_count];
    var universe_empty_cols = [_]usize{999} ** 256;
    var universe_empty_col_count: usize = 0;
    for (0..universe_width) |col| {
        const empty = empty_check: for (0..universe_height) |row| {
            if (universe[row * universe_width + col] != '.') {
                break :empty_check false;
            }
        } else {
            break :empty_check true;
        };
        if (empty) {
            universe_empty_cols[universe_empty_col_count] = col;
            universe_empty_col_count += 1;
        }
    }
    const uec: []usize = universe_empty_cols[0..universe_empty_col_count];
    // print("Empty universe rows {any}\n", .{universe_empty_rows[0..universe_empty_row_count]});
    // print("Empty universe cols {any}\n", .{universe_empty_cols[0..universe_empty_col_count]});

    var galaxies_buf: [1024]Coord = undefined;
    var galaxy_count: usize = 0;
    for (universe, 0..) |loc, i| {
        if (loc == '#') {
            galaxies_buf[galaxy_count] = Coord.at(i, universe_width);
            galaxy_count += 1;
        }
    }

    const galaxies = galaxies_buf[0..galaxy_count];

    print("Total dist: {d}\n", .{total_distances(galaxies, uec, uer, 1)});
    print("Total big dist: {d}\n", .{total_distances(galaxies, uec, uer, 1000000)});
}

fn total_distances(galaxies: []Coord, universe_empty_cols: []usize, universe_empty_rows: []usize, distance_multiplier: usize) u64 {
    var total_dist: u64 = 0;
    for (galaxies[0 .. galaxies.len - 1], 0..) |g1, i| {
        for (galaxies[i + 1 ..]) |g2| {
            const dist = g1.manhattan_dist(&g2, universe_empty_cols, universe_empty_rows, distance_multiplier);
            total_dist += dist;
        }
    }
    return total_dist;
}

const Coord = struct {
    x: usize,
    y: usize,
    fn at(position: usize, width: usize) Coord {
        return Coord{
            .x = position % width,
            .y = position / width,
        };
    }
    fn manhattan_dist(self: *const Coord, other: *const Coord, empty_cols: []usize, empty_rows: []usize, dist_multiplier: u64) u64 {
        var dist: u64 = 0;
        var x_start = if (self.x > other.x) other.x else self.x;
        var x_end = if (self.x > other.x) self.x else other.x;
        var y_start = if (self.y > other.y) other.y else self.y;
        var y_end = if (self.y > other.y) self.y else other.y;
        dist += x_end - x_start;
        dist += y_end - y_start;
        const multi = @max(1, dist_multiplier - 1);
        dist += utils.rangeContains(usize, empty_cols, x_start, x_end) * multi;
        dist += utils.rangeContains(usize, empty_rows, y_start, y_end) * multi;
        return dist;
    }
};
