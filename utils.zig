pub inline fn sliceContains(comptime T: type, slice: []T, val: T) bool {
    for (slice) |s| {
        if (s == val) {
            return true;
        }
    }
    return false;
}

pub inline fn sliceEqualsAll(comptime T: type, slice: []T, val: T) bool {
    for (slice) |s| {
        if (s != val) {
            return false;
        }
    }
    return true;
}

pub inline fn rangeContains(comptime T: type, slice: []T, start: T, end: T) u64 {
    var count: u64 = 0;
    for (slice) |s| {
        if (start < s and s < end) {
            count += 1;
        }
    }
    return count;
}

pub inline fn transpose(comptime T: type, dest: []T, src: []T, width: u64, height: u64) void {
    for (0..height) |i| {
        for (0..width) |j| {
            dest[j * height + i] = src[i * width + j];
        }
    }
}
