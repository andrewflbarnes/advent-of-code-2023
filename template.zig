const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    try solve("DAY/test1");
    try solve("DAY/input");
}

fn solve(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buffer: [256]u8 = undefined;

    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        print("{s}\n", .{line});
    }
}
