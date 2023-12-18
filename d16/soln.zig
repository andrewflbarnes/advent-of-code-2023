const std = @import("std");
const print = std.debug.print;
const gridutils = @import("../grid_utils.zig");
const Dir = gridutils.Direction;
const PointVec = gridutils.PointVec;

pub fn main() !void {
    try solve("d16/test1");
    try solve("d16/input");
}

fn solve(filename: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var width: usize = 0;
    var height: usize = 0;
    var map = std.ArrayList(PointStatus).init(alloc);
    defer map.deinit();

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();
    var buffer: [128]u8 = undefined;

    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        for (line) |c| {
            var p = PointStatus{ .tileType = @as(TileType, @enumFromInt(c)) };
            try map.append(p);
        }
        width = line.len;
        height += 1;
    }

    // dump(map, width, height);
    const energised = try getEnergised(alloc, &map, width, height, .{ .position = 0, .dir = .east });
    print("Energised cells: {}\n", .{energised});

    var starts = std.ArrayList(PointVec).init(alloc);
    defer starts.deinit();
    var highest_energised: u64 = 0;
    const bottom_row_offset = height * (width - 1);
    for (0..width) |start_col| {
        try starts.append(.{ .position = start_col, .dir = .south });
        try starts.append(.{ .position = start_col + bottom_row_offset, .dir = .north });
    }
    for (0..height) |start_row| {
        try starts.append(.{ .position = start_row * width, .dir = .east });
        try starts.append(.{ .position = (start_row + 1) * width - 1, .dir = .west });
    }
    while (starts.popOrNull()) |start| {
        highest_energised = @max(highest_energised, try getEnergised(
            alloc,
            &map,
            width,
            height,
            start,
        ));
    }
    print("Highest energised cells: {}\n", .{highest_energised});
}

fn getEnergised(alloc: std.mem.Allocator, map_base: *const std.ArrayList(PointStatus), width: usize, height: usize, start: PointVec) !u64 {
    var map = std.ArrayList(PointStatus).init(alloc);
    defer map.deinit();
    for (map_base.items) |*item| {
        try map.append(item.*);
    }
    var resolve = std.ArrayList(PointVec).init(alloc);
    defer resolve.deinit();

    try resolve.append(start);

    while (resolve.items.len > 0) {
        var posvec = resolve.pop();
        var location = &map.items[posvec.position];

        // print("At {any} with {any}\n", .{ location, posvec });
        while (!location.visited(posvec.dir)) {
            // print("{any}\n", .{posvec});
            location.visit(posvec.dir);
            const next = location.tileType.handle(posvec.dir);
            // print("Next {any}\n", .{next});
            posvec.dir = next[0];
            if (next[1]) |split_dir| {
                var other = PointVec{ .position = posvec.position, .dir = split_dir };
                if (other.progress(width, height) and !map.items[other.position].visited(split_dir)) {
                    try resolve.append(other);
                }
            }

            if (!posvec.progress(width, height)) {
                break;
            }
            location = &map.items[posvec.position];
        }
    }
    var energised: u64 = 0;
    for (map.items) |*item| {
        if (item.isEnergised()) energised += 1;
    }
    return energised;
}

const DirTuple = struct { Dir, ?Dir };
const TileType = enum(u8) {
    none = '.',
    splitH = '-',
    splitV = '|',
    mirrorWestNorth = '\\',
    mirrorWestSouth = '/',
    fn handle(self: *const TileType, dir: Dir) DirTuple {
        return switch (self.*) {
            .none => .{ dir, null },
            .splitH => if (dir == .north or dir == .south) .{ .west, .east } else .{ dir, null },
            .splitV => if (dir == .east or dir == .west) .{ .north, .south } else .{ dir, null },
            .mirrorWestNorth => .{ switch (dir) {
                .north => .west,
                .south => .east,
                .east => .south,
                .west => .north,
            }, null },
            .mirrorWestSouth => .{ switch (dir) {
                .north => .east,
                .south => .west,
                .east => .north,
                .west => .south,
            }, null },
        };
    }
};

const PointStatus = struct {
    tileType: TileType,
    dirs: std.EnumSet(Dir) = std.EnumSet(Dir).initEmpty(),
    fn isEnergised(self: *const PointStatus) bool {
        return self.dirs.count() > 0;
    }
    fn energised(self: *const PointStatus) usize {
        return self.dirs.count();
    }
    fn visited(self: *PointStatus, dir: Dir) bool {
        return self.dirs.contains(dir);
    }
    fn visit(self: *PointStatus, dir: Dir) void {
        self.*.dirs.insert(dir);
    }
};

fn dump(map: std.ArrayList(PointStatus), width: usize, height: usize) void {
    print("\n", .{});
    for (0..height) |row| {
        for (0..width) |col| {
            print("{c}", .{@intFromEnum(map.items[row * width + col].tileType)});
        }
        print("\n", .{});
    }
    print("\n", .{});
}

fn dumpEnergised(map: *const std.ArrayList(PointStatus), width: usize, height: usize) void {
    print("\n", .{});
    for (0..height) |row| {
        for (0..width) |col| {
            var char: u8 = undefined;
            if (map.items[row * width + col].isEnergised()) {
                char = '#';
            } else {
                char = '.';
            }
            print("{c}", .{char});
            // print("{any}\n", .{map.items[row * width + col]});
        }
        print("\n", .{});
    }
    print("\n", .{});
}
