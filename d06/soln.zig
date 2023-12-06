const std = @import("std");
const print = std.debug.print;

const max_races = 16;

pub fn main() !void {
    try solve("d06/test1");
    try solve("d06/input");
    // being lazy
    try solve("d06/test2");
    try solve("d06/input2");
}

fn solve(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buffer: [256]u8 = undefined;

    var count_races: usize = 0;
    var time_buffer: [max_races]u64 = undefined;
    var distance_buffer: [max_races]u64 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        print("{s}\n", .{line});
        var line_chunks = std.mem.split(u8, line, " ");
        _ = line_chunks.next();
        if (count_races == 0) {
            while (line_chunks.next()) |chunk| {
                if (chunk.len > 0) {
                    time_buffer[count_races] = try std.fmt.parseInt(u64, chunk, 10);
                    count_races += 1;
                }
            }
        } else {
            count_races = 0;
            while (line_chunks.next()) |chunk| {
                if (chunk.len > 0) {
                    distance_buffer[count_races] = try std.fmt.parseInt(u64, chunk, 10);
                    count_races += 1;
                }
            }
        }
    }
    const time = time_buffer[0..count_races];
    const distance = distance_buffer[0..count_races];

    var beat_range_prod: usize = 1;
    for (time, distance) |t, d| {
        var first_beat_time: usize = undefined;
        for (0..t) |press_time| {
            const this_dist = press_time * (t - press_time);
            if (this_dist > d) {
                first_beat_time = press_time;
                break;
            }
        }

        // past midway is just reflection e.g. for a 9ms race
        // - holding for 2ms -> 2 * (9-2) = 2 * 7 = 14
        // - holding for 7ms -> 7 * (9-7) = 7 * 2 = 14
        // so when we find where we first beat, we know we last
        // beat at the race time - first beat time

        const beat_range = t + 1 - 2 * first_beat_time;
        beat_range_prod *= beat_range;
    }

    print("Beat range product: {d}\n", .{beat_range_prod});
}
