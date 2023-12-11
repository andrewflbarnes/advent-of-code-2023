const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    try solve("d09/test1");
    try solve("d09/input");
}

fn solve(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buffer: [1024]u8 = undefined;
    var oasis_prev: i64 = 0;
    var oasis_next: i64 = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        var chunks = std.mem.split(u8, line, " ");
        var readings_buf: [256]i64 = undefined;
        var readings_count: usize = 0;
        while (chunks.next()) |chunk| {
            readings_buf[readings_count] = try std.fmt.parseInt(i64, chunk, 10);
            readings_count += 1;
        }
        const readings = readings_buf[0..readings_count];
        var reading_deltas = [_]i64{0} ** 64;
        var last_delta = readings.len - 1;
        for (0..last_delta) |i| {
            reading_deltas[i] = readings[i + 1] - readings[i];
        }
        var first_vals = [_]i64{0} ** 64;
        first_vals[0] = readings[0];
        first_vals[1] = reading_deltas[0];
        var last_vals = [_]i64{0} ** 64;
        last_vals[0] = readings[readings.len - 1];
        last_vals[1] = reading_deltas[last_delta - 1];
        last_delta -= 1;
        var last_val_i: usize = 2;
        while (std.mem.min(i64, &reading_deltas) != 0 or std.mem.max(i64, &reading_deltas) != 0) {
            for (0..last_delta) |i| {
                reading_deltas[i] = reading_deltas[i + 1] - reading_deltas[i];
            }
            last_vals[last_val_i] = reading_deltas[last_delta - 1];
            first_vals[last_val_i] = reading_deltas[0];
            reading_deltas[last_delta] = 0;
            last_delta -= 1;
            last_val_i += 1;
        }
        var next: i64 = 0;
        for (0..last_val_i) |lvi| next += last_vals[lvi];
        oasis_next += next;
        var prev: i64 = first_vals[last_val_i - 1];
        for (1..last_val_i) |lvi| prev = first_vals[last_val_i - lvi - 1] - prev;
        oasis_prev += prev;
    }
    print("OASIS {d}..{d}\n", .{ oasis_prev, oasis_next });
}
