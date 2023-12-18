pub const Direction = enum {
    north,
    south,
    east,
    west,
    pub fn opposite(self: *const Direction) Direction {
        return switch (self.*) {
            .north => .south,
            .south => .north,
            .east => .west,
            .west => .east,
        };
    }
    pub fn moveFrom(self: *const Direction, index: usize, width: usize, height: usize) ?usize {
        return switch (self.*) {
            .north => if (index < width) null else index - width,
            .south => if (index < (height - 1) * width) index + width else null,
            .east => if (index % width < width - 1) index + 1 else null,
            .west => if (index % width != 0) index - 1 else null,
        };
    }
};

pub const PointVec = struct {
    position: usize,
    dir: Direction,
    pub fn progress(self: *PointVec, width: usize, height: usize) bool {
        return self.progressN(width, height, 1);
    }
    pub fn progressN(self: *PointVec, width: usize, height: usize, dist: usize) bool {
        _ = dist; // TODO
        var next_pos: ?usize = switch (self.dir) {
            .north => if (self.position >= height) self.position - height else null,
            .south => if (self.position + height < width * height) self.position + height else null,
            .east => if ((self.position + 1) % width != 0) self.position + 1 else null,
            .west => if (self.position > 0 and self.position % width != 0) self.position - 1 else null,
        };

        if (next_pos) |np| {
            self.position = np;
            return true;
        }
        return false;
    }
};
