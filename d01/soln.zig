const std = @import("std");
const print = std.debug.print;

const Replacement = struct {
    val: []const u8,
    with: []const u8,
    fn of(val: []const u8, with: []const u8) Replacement {
        return Replacement{
            .val = val,
            .with = with,
        };
    }
};

const replacements = [_]Replacement{
    Replacement.of("one", "1"),
    Replacement.of("two", "2"),
    Replacement.of("three", "3"),
    Replacement.of("fourteen", "14"),
    Replacement.of("fourty", "30"),
    Replacement.of("four", "4"),
    Replacement.of("five", "5"),
    Replacement.of("sixteen", "16"),
    Replacement.of("sixty", "60"),
    Replacement.of("six", "6"),
    Replacement.of("seventeen", "17"),
    Replacement.of("seventy", "70"),
    Replacement.of("seven", "7"),
    Replacement.of("eighteen", "18"),
    Replacement.of("eighty", "80"),
    Replacement.of("eight", "8"),
    Replacement.of("nineteen", "19"),
    Replacement.of("ninety", "90"),
    Replacement.of("nine", "9"),
    Replacement.of("ten", "10"),
    Replacement.of("eleven", "11"),
    Replacement.of("twelve", "12"),
    Replacement.of("thirteen", "13"),
    Replacement.of("fifteen", "15"),
    Replacement.of("twenty", "20"),
    Replacement.of("thirty", "30"),
    Replacement.of("hundred", "00"),
    Replacement.of("thousand", "00"),
    Replacement.of("million", "00"),
    Replacement.of("billion", "00"),
    Replacement.of("trillion", "00"),
    Replacement.of("quadrillion", "00"),
    Replacement.of("quintillion", "00"),
    Replacement.of("sexillion", "00"),
};

pub fn main() !void {
    try solve("d01/test1", false);
    try solve("d01/input", false);
    try solve("d01/test2", true);
    try solve("d01/input", true);
}

fn solve(filename: []const u8, replace: bool) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buffer: [256]u8 = undefined;
    var out_buffer: [256]u8 = undefined;
    var out_len: u8 = undefined;
    var first: i32 = undefined;
    var second: i32 = undefined;
    var total: i32 = 0;

    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        out_buffer[out_len] = 0;
        out_len = 0;
        for (line, 0..) |char, idx| {
            if (char >= 48 and char <= 57) {
                out_buffer[out_len] = char;
                out_len += 1;
            } else if (replace) {
                // TODO check for strings
                for (replacements) |repl| {
                    if (std.mem.eql(u8, buffer[idx..(idx + repl.val.len)], repl.val)) {
                        for (repl.with, out_len..) |repl_char, repl_idx| {
                            out_buffer[repl_idx] = repl_char;
                        }
                        out_len += @truncate(repl.with.len);
                        break;
                    }
                }
            }
        }
        first = -1;
        second = -1;
        for (out_buffer[0..out_len]) |char| {
            if (char >= 48 and char <= 57) {
                if (first < 0) {
                    first = char - 48;
                } else {
                    second = char - 48;
                }
            }
        }
        if (second < 0) {
            second = first;
        }
        total += 10 * first + second;
    }

    print("{d}\n", .{total});
}
