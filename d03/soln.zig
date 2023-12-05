const std = @import("std");
const print = std.debug.print;
const isDigit = std.ascii.isDigit;

const max_supported_size = 256;
const max_supported_gears = 512;
const mem_size = max_supported_size * max_supported_size;

pub fn main() !void {
    try solve("d03/test1");
    try solve("d03/input");
}

fn solve(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    // be lazy and store in a flat buffer
    var mem: [mem_size]u8 = undefined;
    @memset(&mem, '.');

    var read_buffer: [max_supported_size]u8 = undefined;
    var buffer: []u8 = &mem;
    var line_size: usize = 0;

    while (try in_stream.readUntilDelimiterOrEof(&read_buffer, '\n')) |line| {
        if (line_size == 0) {
            // first line - we are going to ensure a bounding box of "." exists to make checks later easier
            // line size is 2 larger as we want a "." either side of the line
            line_size = line.len + 2;
            // any new information from the buffer needs to be aligned 1 byte in, first line is left as a bounding
            buffer = buffer[line_size + 1 ..];
        }
        std.mem.copy(u8, buffer, line[0..]);
        buffer = buffer[line_size..];
    }

    // ensure we have a final bounding line before placing the sentinel
    buffer[line_size - 1] = 0;
    buffer = &mem;

    try solve_parts(&buffer, line_size);
    // solve_gears(&buffer, line_size);
}

fn solve_parts(buf: *[]const u8, line_size: usize) !void {
    var gears: [max_supported_gears]usize = undefined;
    var another_gear: usize = 0;
    @memset(&gears, mem_size);
    var buffer = buf.*;
    var part_total: u32 = 0;
    var gear_ratio: u64 = 0;
    var ptr: usize = 0;
    var end_ptr: usize = 0;
    while (buffer[ptr] != 0) {
        if (!isDigit(buffer[ptr])) {
            ptr += 1;
            continue;
        }

        end_ptr = ptr + 1;
        while (isDigit(buffer[end_ptr]) and end_ptr % line_size != 0) {
            end_ptr += 1;
        }

        if (is_part(&buffer, ptr, end_ptr, line_size)) {
            const part = try std.fmt.parseInt(u32, buffer[ptr..end_ptr], 10);
            part_total += part;

            // look for any nearby gears, if found we only need to check for additional parts "ahead" of
            // the current part
            if (adjacent_gear(&buffer, ptr, end_ptr, line_size)) |gear_ptr| {
                for (gears) |gear| {
                    if (gear == mem_size) {
                        gears[another_gear] = gear_ptr;
                        another_gear += 1;
                        if (find_connected_part(&buffer, ptr, end_ptr, line_size, gear_ptr)) |connected_part| {
                            gear_ratio += part * connected_part;
                        }
                        break;
                    }
                    if (gear == gear_ptr) {
                        break;
                    }
                }
            }
        }

        ptr = end_ptr;
    }
    print("Parts total: {d}\n", .{part_total});
    print("Gear ratio: {d}\n", .{gear_ratio});
}

fn is_part(buffer: *[]const u8, ptr: usize, end_ptr: usize, line_size: usize) bool {
    // check line above
    for (ptr - line_size - 1..end_ptr - line_size + 1) |check_ptr| {
        if (is_symbol(buffer.*[check_ptr])) {
            return true;
        }
    }

    // check current line
    if (is_symbol(buffer.*[ptr - 1]) or is_symbol(buffer.*[end_ptr])) {
        return true;
    }

    // check line below
    for (ptr + line_size - 1..end_ptr + line_size + 1) |check_ptr| {
        if (is_symbol(buffer.*[check_ptr])) {
            return true;
        }
    }

    return false;
}

fn is_symbol(char: u8) bool {
    return char != '.' and !isDigit(char);
}

// returns the ptr of a gear, if it exists
fn adjacent_gear(buffer: *[]const u8, ptr: usize, end_ptr: usize, line_size: usize) ?usize {
    // any positions not checked below will have been found by a part
    // check top right
    if (buffer.*[end_ptr - line_size] == '*') {
        return end_ptr - line_size;
    }

    // check current line
    if (buffer.*[end_ptr] == '*') {
        return end_ptr;
    }
    if (buffer.*[ptr - 1] == '*') {
        return ptr - 1;
    }

    // check line below
    for (ptr + line_size - 1..end_ptr + line_size + 1) |check_ptr| {
        if (buffer.*[check_ptr] == '*') {
            return check_ptr;
        }
    }

    return null;
}

// returns a part number connected to a gear which hasn't already been processed,
fn find_connected_part(buffer: *[]const u8, ptr: usize, end_ptr: usize, line_size: usize, gear_ptr: usize) ?u32 {
    const is_above_right = end_ptr - line_size == gear_ptr;
    if (is_above_right) {
        // we only need to check below right of gear
        if (isDigit(buffer.*[gear_ptr + line_size + 1])) {
            return part_at(buffer, gear_ptr + line_size + 1);
        }
        return null;
    }
    const is_left = ptr - 1 == gear_ptr;
    const is_right = end_ptr == gear_ptr;
    const is_right_down = end_ptr + line_size == gear_ptr;
    // check immediately right of gear
    if (!is_left and isDigit(buffer.*[gear_ptr + 1])) {
        return part_at(buffer, gear_ptr + 1);
    }
    // check row below gear
    for (gear_ptr + line_size - 1..gear_ptr + line_size + 2) |check_ptr| {
        if (isDigit(buffer.*[check_ptr])) {
            return part_at(buffer, check_ptr);
        }
    }
    // check immediately left of gear
    if (!is_left and !is_right and isDigit(buffer.*[gear_ptr - 1])) {
        return part_at(buffer, gear_ptr - 1);
    }
    // check above right of gear
    if (is_right_down and isDigit(buffer.*[gear_ptr + 1 - line_size])) {
        return part_at(buffer, gear_ptr + 1 - line_size);
    }

    // no connected part
    return null;
}

fn part_at(buffer: *[]const u8, ptr: usize) u32 {
    var ptr_start = ptr;
    var ptr_end = ptr + 1;
    while (isDigit(buffer.*[ptr_start - 1])) {
        ptr_start -= 1;
    }
    while (isDigit(buffer.*[ptr_end])) {
        ptr_end += 1;
    }
    return std.fmt.parseInt(u32, buffer.*[ptr_start..ptr_end], 10) catch unreachable;
}
