const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    try solve("d15/test1");
    try solve("d15/input");
}

fn solve(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    // Added as an aside so I can understand deiniting better instead of just relying on arena.deinit
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer std.debug.assert(.ok == gpa.deinit());
    // var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    // const allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Lenses = std.StringArrayHashMap(Lens);
    var steps = std.ArrayList(Lens).init(allocator);
    defer {
        for (steps.items) |*step| {
            step.deinit();
        }
        steps.deinit();
    }

    var boxes = std.AutoArrayHashMap(u8, Lenses).init(allocator);
    defer {
        var boxes_iter = boxes.iterator();
        while (boxes_iter.next()) |box| {
            box.value_ptr.deinit();
        }
        boxes.deinit();
    }

    var buffer: [256]u8 = undefined;

    var seq_hash: u64 = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buffer, ',')) |line| {
        const command = ascii_hash(line);
        seq_hash += command;
        try steps.append(try Lens.from(line, allocator));
    }

    print("Init step hash: {}\n", .{seq_hash});

    // for (steps.items) |item| {
    //     item.dump();
    // }

    for (steps.items) |step| {
        if (boxes.getPtr(step.box_num)) |lenses| {
            if (step.focal_length) |_| {
                try lenses.put(step.label, step);
            } else {
                _ = lenses.orderedRemove(step.label);
            }
        } else {
            if (step.focal_length) |_| {
                var lenses = Lenses.init(allocator);
                try lenses.put(step.label, step);
                try boxes.put(step.box_num, lenses);
            }
        }
    }

    var boxes_iter = boxes.iterator();
    var focal_power: u64 = 0;
    while (boxes_iter.next()) |box| {
        // print("{} =>\n", .{box.key_ptr.*});
        const box_val = @as(u64, box.key_ptr.*) + 1;
        for (box.value_ptr.*.values(), 0..) |lens, i| {
            focal_power += box_val * (i + 1) * lens.focal_length.?;
            // print("  ", .{});
            // lens.dump();
        }
    }

    print("Focal power: {}\n", .{focal_power});
}

fn ascii_hash(str: []const u8) u64 {
    var hash: u64 = 0;
    for (str) |c| {
        hash += c;
        hash *= 17;
        hash %= 256;
    }
    return hash;
}

const Lens = struct {
    label: []u8,
    box_num: u8,
    focal_length: ?u8,
    allocator: std.mem.Allocator,
    fn from(buf: []const u8, allocator: std.mem.Allocator) !Lens {
        var label: []const u8 = undefined;
        var focal_length: ?u8 = undefined;
        if (std.mem.indexOfScalar(u8, buf, '-')) |i| {
            label = buf[0..i];
            focal_length = null;
        } else if (std.mem.indexOfScalar(u8, buf, '=')) |i| {
            label = buf[0..i];
            focal_length = try std.fmt.parseInt(u8, buf[i + 1 ..], 10);
        }
        const box_num = ascii_hash(label);
        const self_label = try allocator.alloc(u8, label.len);
        @memcpy(self_label, label);
        return Lens{
            .label = self_label,
            .box_num = @intCast(box_num),
            .focal_length = focal_length,
            .allocator = allocator,
        };
    }
    fn toRemove(self: *const Lens) bool {
        return self.focal_length == null;
    }
    fn deinit(self: *Lens) void {
        self.allocator.free(self.label);
    }
    fn dump(self: *const Lens) void {
        print("{s}={?}\n", .{ self.label, self.focal_length });
    }
};
