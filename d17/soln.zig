const std = @import("std");
const print = std.debug.print;
const gridutils = @import("../grid_utils.zig");
const Direction = gridutils.Direction;
const PointVec = gridutils.PointVec;

const Queue = std.TailQueue(PointVec);
const Node = Queue.Node;

pub fn main() !void {
    try solve("d17/test1");
    try solve("d17/input");
}

fn solve(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(.ok == gpa.deinit());
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    var allocator = arena.allocator();
    var buffer: [256]u8 = undefined;
    var height: usize = 0;
    var width: usize = 0;
    var map = std.ArrayList(PointStatus).init(allocator);
    defer map.deinit();

    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        // print("{s}\n", .{line});
        for (line) |c| {
            try map.append(.{ .heat_loss = @as(u4, @intCast(c - 48)) });
        }
        width = line.len;
        height += 1;
    }

    // dump(&map, width);
    var map_ultra = try map.clone();

    const start_dirs = std.EnumSet(Direction).initMany(&[_]Direction{ .south, .east });
    const lhl = try findLowestHeatLoss(allocator, &map, width, 0, start_dirs, width * height - 1, 1, 3);
    // try dumpPath(allocator, &map, width, height);
    print("Lowest heat loss: {}\n", .{lhl});
    const lhl_ultra = try findLowestHeatLoss(allocator, &map_ultra, width, 0, start_dirs, width * height - 1, 4, 10);
    // try dumpPath(allocator, &map_ultra, width, height);
    print("Lowest heat loss: {}\n", .{lhl_ultra});
}

fn dumpPath(allocator: std.mem.Allocator, map: *std.ArrayList(PointStatus), width: usize, height: usize) !void {
    var path_rev = std.ArrayList(usize).init(allocator);
    var node = map.getLast();
    var pos = map.items.len - 1;
    try path_rev.append(pos);
    var heat: u64 = node.heat_loss;
    var lh: LeastBacktrack = if (node.least_heat_ew.?.heat_loss > node.least_heat_ns.?.heat_loss) node.least_heat_ns.? else node.least_heat_ew.?;
    var entry_dir = lh.entry_dir;
    var rev_dir = entry_dir.opposite();
    while (pos > 0) {
        // print("Traverse from {},{} {} {} spaces\n", .{ pos % width, pos / width, rev_dir, lh.distance });
        for (0..lh.distance) |_| {
            // print("From {} {} to ", .{ pos, rev_dir });
            pos = rev_dir.moveFrom(pos, width, height) orelse unreachable;
            // print("{}\n", .{pos});
            try path_rev.append(pos);
            node = map.items[pos];
            heat += node.heat_loss;
        }
        lh = switch (entry_dir) {
            .north, .south => node.least_heat_ew.?,
            .east, .west => node.least_heat_ns.?,
        };
        entry_dir = lh.entry_dir;
        rev_dir = entry_dir.opposite();
    }

    // print("Traversal lhl: {}\n", .{heat});
    // while (path_rev.popOrNull()) |idx| {
    //     print("{}  {},{}\n", .{ idx, idx % width, idx / width });
    // }
    for (map.items, 0..) |*item, i| {
        if (i % width == 0) {
            print("\n", .{});
        }
        const char = if (std.mem.indexOfScalar(usize, path_rev.items, i)) |_| '.' else @as(u8, item.heat_loss) + 48;
        print("{c}", .{char});
    }
    print("\n\n", .{});
}

fn findLowestHeatLoss(allocator: std.mem.Allocator, map: *std.ArrayList(PointStatus), width: usize, start: usize, start_dirs: std.EnumSet(Direction), finish: usize, min_straight: usize, max_straight: usize) !u64 {
    const height = map.items.len / width;
    var queue = Queue{};
    var starts = start_dirs.iterator();
    while (starts.next()) |start_dir| {
        var node = try allocator.create(Node);
        node.* = .{ .data = .{ .position = start, .dir = start_dir } };
        queue.append(node);
        _ = map.items[0].updateLeastHeat(start_dir, 0, 0);
    }

    var lhl_bound: u64 = 0xFFFFFFFF;
    while (queue.pop()) |n| {
        // dfs so we get an early upper bound?
        // maybe bfs uses less memory?

        const init_pos: PointStatus = map.items[n.data.position];

        const next_dirs = next_dirs: {
            var others = std.EnumSet(Direction).initFull();
            others.remove(n.data.dir);
            others.remove(n.data.dir.opposite());
            break :next_dirs others;
        };
        var next_dirs_it = next_dirs.iterator();
        next_dir: while (next_dirs_it.next()) |next_dir| {
            var next_position: usize = n.data.position;
            var dir_heat_loss = init_pos.leastHeatFor(next_dir);
            for (1..min_straight) |_| {
                if (next_dir.moveFrom(next_position, width, height)) |new_pos| {
                    next_position = new_pos;
                    var next_status: *PointStatus = &map.items[next_position];
                    dir_heat_loss += next_status.heat_loss;
                } else {
                    continue :next_dir;
                }
            }
            for (min_straight..max_straight + 1) |dist| {
                if (next_dir.moveFrom(next_position, width, height)) |new_pos| {
                    next_position = new_pos;
                    var next_status: *PointStatus = &map.items[next_position];
                    dir_heat_loss += next_status.heat_loss;
                    if (dir_heat_loss > lhl_bound) {
                        continue :next_dir;
                    }
                    if (next_position == finish and dir_heat_loss < lhl_bound) {
                        lhl_bound = dir_heat_loss;
                    }
                    // print("Moved {} from {} to check new position {} with hl {}\n", .{ next_dir, n.data.position, new_pos, dir_heat_loss });
                    const updated = next_status.updateLeastHeat(next_dir, dist, dir_heat_loss);
                    // print("{} {} {any}\n", .{ updated, skip_append, next_status });
                    if (updated and next_position != finish) {
                        // print("Updated next pos, todo add to queue {any}\n", .{next_status});
                        // TODO should be able to optimise so we don't add if already processed in this direction,
                        // in that case we can use back tracking or some other method to rebuild all steps.
                        var next_node = try allocator.create(Node);
                        next_node.* = .{ .data = .{ .position = next_position, .dir = next_dir } };
                        queue.append(next_node);
                    }
                } else {
                    continue :next_dir;
                }
            }
        }
        allocator.destroy(n);
    }
    var lhns: u64 = map.getLast().least_heat_ns.?.heat_loss;
    var lhew: u64 = map.getLast().least_heat_ew.?.heat_loss;

    return if (lhns > lhew) lhew else lhns;
}

const PointStatus = struct {
    heat_loss: u4,
    // we track one east/west and one north/south since in our model these are functionally equivalent
    least_heat_ew: ?LeastBacktrack = null,
    least_heat_ns: ?LeastBacktrack = null,
    fn leastHeatFor(self: *const PointStatus, next_dir: Direction) u64 {
        return switch (next_dir) {
            .north, .south => if (self.least_heat_ew) |lh| lh.heat_loss else 0xFFFFFFFF,
            .east, .west => if (self.least_heat_ns) |lh| lh.heat_loss else 0xFFFFFFFF,
        };
    }
    fn updateLeastHeat(self: *PointStatus, entry_dir: Direction, dist: usize, heat_loss: u64) bool {
        const next = LeastBacktrack{ .entry_dir = entry_dir, .distance = dist, .heat_loss = heat_loss };
        switch (entry_dir) {
            .north, .south => {
                if (self.least_heat_ns) |lh| {
                    if (lh.heat_loss <= heat_loss) {
                        return false;
                    }
                }
                self.least_heat_ns = next;
            },
            .east, .west => {
                if (self.least_heat_ew) |lh| {
                    if (lh.heat_loss <= heat_loss) {
                        return false;
                    }
                }
                self.least_heat_ew = next;
            },
        }
        return true;
    }
};

const LeastBacktrack = struct {
    // this is the direction we were travelling on entry
    entry_dir: Direction,
    distance: usize,
    heat_loss: u64,
};

fn dump(map: *std.ArrayList(PointStatus), width: usize) void {
    for (map.items, 0..) |*item, i| {
        if (i % width == 0) {
            print("\n", .{});
        }

        print("{c}", .{@as(u8, item.heat_loss) + 48});
    }
    print("\n\n", .{});
}

test "lest heat" {
    const assert = std.debug.assert;
    var ps = PointStatus{
        .heat_loss = 0,
    };

    assert(ps.updateLeastHeat(.north, 1, 10));
    assert(ps.least_heat_ns.?.entry_dir == .north);
    assert(ps.least_heat_ns.?.heat_loss == 10);
    assert(ps.least_heat_ew == null);

    assert(ps.updateLeastHeat(.north, 1, 9));
    assert(ps.least_heat_ns.?.entry_dir == .north);
    assert(ps.least_heat_ns.?.heat_loss == 9);
    assert(ps.least_heat_ew == null);

    assert(!ps.updateLeastHeat(.north, 1, 10));
    assert(ps.least_heat_ns.?.entry_dir == .north);
    assert(ps.least_heat_ns.?.heat_loss == 9);
    assert(ps.least_heat_ew == null);

    assert(!ps.updateLeastHeat(.south, 1, 10));
    assert(ps.least_heat_ns.?.entry_dir == .north);
    assert(ps.least_heat_ns.?.heat_loss == 9);
    assert(ps.least_heat_ew == null);

    assert(ps.updateLeastHeat(.south, 1, 8));
    assert(ps.least_heat_ns.?.entry_dir == .south);
    assert(ps.least_heat_ns.?.heat_loss == 8);
    assert(ps.least_heat_ew == null);

    assert(ps.updateLeastHeat(.east, 1, 8));
    assert(ps.least_heat_ns.?.entry_dir == .south);
    assert(ps.least_heat_ns.?.heat_loss == 8);
    assert(ps.least_heat_ew.?.entry_dir == .east);
    assert(ps.least_heat_ew.?.heat_loss == 8);

    assert(!ps.updateLeastHeat(.west, 1, 8));
    assert(ps.least_heat_ns.?.entry_dir == .south);
    assert(ps.least_heat_ns.?.heat_loss == 8);
    assert(ps.least_heat_ew.?.entry_dir == .east);
    assert(ps.least_heat_ew.?.heat_loss == 8);

    assert(ps.updateLeastHeat(.west, 1, 7));
    assert(ps.least_heat_ns.?.entry_dir == .south);
    assert(ps.least_heat_ns.?.heat_loss == 8);
    assert(ps.least_heat_ew.?.entry_dir == .west);
    assert(ps.least_heat_ew.?.heat_loss == 7);

    assert(ps.updateLeastHeat(.north, 1, 7));
    assert(ps.least_heat_ns.?.entry_dir == .north);
    assert(ps.least_heat_ns.?.heat_loss == 7);
    assert(ps.least_heat_ew.?.entry_dir == .west);
    assert(ps.least_heat_ew.?.heat_loss == 7);
}
