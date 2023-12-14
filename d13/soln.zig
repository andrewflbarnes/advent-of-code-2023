const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    // try solve("d13/testonly");
    try solve("d13/test1");
    try solve("d13/input");
}

fn solve(filename: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = false }){};
    defer std.debug.assert(.ok == gpa.deinit());
    var gpa_alloc = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    var alloc = arena.allocator();

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    var buffer: []u8 = buf[0..];
    var width: usize = 0;
    var height: usize = 0;

    var grids = std.ArrayList(Grid).init(alloc);
    defer {
        for (grids.items) |grid| {
            grid.deinit();
        }
        grids.deinit();
    }

    while (try in_stream.readUntilDelimiterOrEof(buffer, '\n')) |line| {
        if (line.len == 0) {
            try grids.append(try Grid.from(buf[0 .. width * height], width, height, &alloc));
            width = 0;
            height = 0;
            buffer = buf[0..];
            continue;
        }
        width = line.len;
        height += 1;
        buffer = buffer[line.len..];
    }
    try grids.append(try Grid.from(buf[0 .. width * height], width, height, &alloc));
    var symsum: u64 = 0;
    for (grids.items, 0..) |grid, i| {
        var sym_count: u8 = 0;
        if (try grid.findHorizontalSymmetry()) |sym_col| {
            // print("[{d}] Horizontal symmetry at column {d}\n", .{ i + 1, sym_col });
            symsum += sym_col;
            sym_count += 1;
        }

        if (try grid.findVerticalSymmetry()) |sym_row| {
            // print("[{d}] Vertical symmetry at row {d}\n", .{ i + 1, sym_row });
            symsum += sym_row * 100;
            sym_count += 1;
        }

        if (sym_count == 0) {
            print("[{d}] NO SYMMETRY!\n", .{i + 1});
        }

        if (sym_count == 2) {
            print("[{d}] DOUBLE SYMMETRY!\n", .{i + 1});
        }
    }
    print("Symmetry sum: {d}\n", .{symsum});
}

const Grid = struct {
    width: usize,
    height: usize,
    data: []u8,
    alloc: *std.mem.Allocator,
    fn from(buf: []u8, width: usize, height: usize, alloc: *std.mem.Allocator) !Grid {
        std.debug.assert(width * height == buf.len);
        const data = try alloc.alloc(u8, buf.len);
        @memcpy(data, buf);
        return Grid{
            .width = width,
            .height = height,
            .data = data,
            .alloc = alloc,
        };
    }
    fn deinit(self: *const Grid) void {
        self.alloc.free(self.data);
    }
    fn findVerticalSymmetry(self: *const Grid) !?usize {
        var data_t = try self.alloc.alloc(u8, self.data.len);
        defer self.alloc.free(data_t);
        // transpose from data to data_t
        for (0..self.height) |i| {
            for (0..self.width) |j| {
                data_t[j * self.height + i] = self.data[i * self.width + j];
            }
        }
        return findDataHorizontalSymmetry(self.alloc, &data_t, self.height);
    }
    fn findHorizontalSymmetry(self: *const Grid) !?usize {
        return findDataHorizontalSymmetry(self.alloc, &self.data, self.width);
    }
    fn dump(self: *const Grid) void {
        for (0..self.height) |j| {
            print("{s}\n", .{self.data[j * self.width .. (j + 1) * self.width]});
        }
    }
};

fn findDataHorizontalSymmetry(alloc: *std.mem.Allocator, data_ptr: *const []u8, width: usize) !?usize {
    const data = data_ptr.*;
    const cols = try alloc.alloc(usize, width - 1);
    defer alloc.free(cols);
    @memset(cols, 0);
    var col_count: usize = 0;
    // check first line for possible symmetry points then recurse
    for (1..width) |i| {
        var symmetric = hasLineSymmetryAt(data[0..width], i);

        // print("{s} {d}\n", .{ if (symmetric) "Success" else "Failed", i });
        if (symmetric) {
            cols[col_count] = i;
            col_count += 1;
        }
    }
    // axis of possible symmetry = aps
    var aps: []usize = cols[0..col_count];
    // print("{any}\n", .{aps});
    const height = data.len / width;
    for (1..height) |l| {
        const offset = l * width;
        const line = data[offset .. offset + width];
        // use a copy of the slice so we can modify it in the for loop
        var removed: usize = 0;
        for (0..aps.len) |a_idx| {
            const a = aps[a_idx - removed];
            if (!hasLineSymmetryAt(line, a)) {
                if (a_idx - removed < aps.len - removed) {
                    for (a_idx - removed..aps.len - removed - 1) |r| {
                        aps[r] = aps[r + 1];
                    }
                }
                removed += 1;
                // print("Line symmetry failed for position {d} on line {d} -> {d}\n", .{ a, l, aps[0 .. aps.len - removed] });
            }
        }
        aps = aps[0 .. aps.len - removed];
    }
    // print("{any}\n", .{aps});
    std.debug.assert(aps.len <= 1);
    return if (aps.len == 0) null else aps[0];
}

fn hasLineSymmetryAt(line: []u8, position: usize) bool {
    for (0..position) |j| {
        if (position < j + 1 or position + j >= line.len) {
            // no more checks from this point
            break;
        }
        const check_left = position - j - 1;
        const check_right = position + j;
        if (line[check_left] != line[check_right]) {
            return false;
        }
    }

    return true;
}
