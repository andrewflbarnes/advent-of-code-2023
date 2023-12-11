const std = @import("std");
const print = std.debug.print;

const cache_level = 10;

pub fn main() !void {
    try solve("d08/test1");
    try solve("d08/test2");
    try solve("d08/test3");
    try solve("d08/input");
}

fn solve(file: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){};
    defer std.debug.assert(.ok == gpa.deinit());
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    var allocator = arena.allocator();

    const f = try std.fs.cwd().openFile(file, .{});
    defer f.close();

    var buf_read = std.io.bufferedReader(f.reader());
    var in_stream = buf_read.reader();

    var buffer = [_]u8{0} ** 1024;
    var step_buffer = [_]u8{0} ** 1024;
    var steps: []u8 = undefined;
    var node_buf: [1024]Node = undefined;
    var node_count: usize = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        if (step_buffer[0] == 0) {
            @memcpy(&step_buffer, &buffer);
            steps = step_buffer[0..line.len];
        } else if (line.len > 0) {
            const node = Node.from(&buffer);
            node_buf[node_count] = node;
            node_count += 1;
        }
    }

    const nodes = node_buf[0..node_count];
    var node_map = std.StringArrayHashMap(Node).init(allocator);
    for (nodes) |*node| {
        try node_map.put(&node.id, node.*);
    }

    const step_count = try solveAtoZ(steps, node_map);
    print("Camel {d}\n", .{step_count});

    try solveAsToZs(steps, node_map);
}

fn solveAtoZ(steps: []u8, node_map: std.StringArrayHashMap(Node)) !u64 {
    var step_count: u64 = 0;
    var current = node_map.get("AAA").?.id;

    var step_idx: usize = 0;
    while (!std.mem.eql(u8, &current, "ZZZ")) {
        const next = node_map.get(&current).?;

        if (steps[step_idx] == 'R') {
            current = next.right;
        } else {
            current = next.left;
        }
        step_idx += 1;
        if (step_idx == steps.len) {
            step_idx = 0;
        }
        step_count += 1;
    }
    return step_count;
}

fn solveAsToZs(steps: []u8, node_map: std.StringArrayHashMap(Node)) !void {
    var starts: [][]const u8 = undefined;
    var finishes: [][]const u8 = undefined;
    var nodes_buffer: [16][]const u8 = undefined;
    {
        var i: usize = 0;
        for (node_map.keys()) |k| {
            if (k[2] == 'A') {
                nodes_buffer[i] = k;
                i += 1;
            }
        }
        starts = nodes_buffer[0..i];
        i = 0;
        for (node_map.keys()) |k| {
            if (k[2] == 'Z') {
                nodes_buffer[starts.len + i] = k;
                i += 1;
            }
        }
        finishes = nodes_buffer[starts.len .. starts.len + i];
    }

    var lcm: u64 = 1;
    for (starts) |start| {
        var step_count: u64 = 0;
        var current = node_map.get(start).?.id;
        var step_idx: usize = 0;
        while (current[2] != 'Z') {
            const next = node_map.get(&current).?;

            if (steps[step_idx] == 'R') {
                current = next.right;
            } else {
                current = next.left;
            }
            step_idx += 1;
            if (step_idx == steps.len) {
                step_idx = 0;
            }
            step_count += 1;
        }
        lcm = lcm * step_count / std.math.gcd(lcm, step_count);
        // print("Ghost from {s} to {s} in {d}\n", .{ start, current, step_count });
    }
    print("Ghost {d}\n", .{lcm});
}

const Node = struct {
    id: [3]u8,
    left: [3]u8,
    right: [3]u8,
    pub fn from(buf: [*]const u8) Node {
        var id: [3]u8 = undefined;
        @memcpy(id[0..3], buf[0..3]);
        var left: [3]u8 = undefined;
        @memcpy(left[0..3], buf[7..10]);
        var right: [3]u8 = undefined;
        @memcpy(right[0..3], buf[12..15]);
        return Node{
            .id = id,
            .left = left,
            .right = right,
        };
    }
};
