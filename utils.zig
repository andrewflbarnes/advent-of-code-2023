pub fn sliceContains(comptime T: type, slice: []T, val: T) bool {
    for (slice) |s| {
        if (s == val) {
            return true;
        }
    }
    return false;
}

pub fn sliceEqualsAll(comptime T: type, slice: []T, val: T) bool {
    for (slice) |s| {
        if (s != val) {
            return false;
        }
    }
    return true;
}

pub fn rangeContains(comptime T: type, slice: []T, start: T, end: T) u64 {
    var count: u64 = 0;
    for (slice) |s| {
        if (start < s and s < end) {
            count += 1;
        }
    }
    return count;
}
