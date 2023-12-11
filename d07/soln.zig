const std = @import("std");
const print = std.debug.print;

const max_hands = 1024;

pub fn main() !void {
    try solve("d07/test1");
    try solve("d07/input");
}

fn solve(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buffer: [256]u8 = undefined;

    var hands_buf: [max_hands]Hand = undefined;
    var hands_count: usize = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        const hand = try Hand.from(line);
        hands_buf[hands_count] = hand;
        hands_count += 1;
    }
    const hands = hands_buf[0..hands_count];

    std.mem.sort(Hand, hands, {}, struct {
        fn comp(ctx: void, h1: Hand, h2: Hand) bool {
            _ = ctx;
            return h1.compare(h2);
        }
    }.comp);

    var total_winnings: u64 = 0;
    for (hands, 0..) |hand, i| {
        total_winnings += hand.bid * (hands.len - i);
    }
    print("{d}\n", .{total_winnings});

    std.mem.sort(Hand, hands, {}, struct {
        fn comp(ctx: void, h1: Hand, h2: Hand) bool {
            _ = ctx;
            return h1.compare_joker(h2);
        }
    }.comp);

    total_winnings = 0;
    for (hands, 0..) |hand, i| {
        total_winnings += hand.bid * (hands.len - i);
    }
    print("{d}\n", .{total_winnings});
}

const Hand = struct {
    cards: [5]u8,
    vals: [5]u8,
    vals_sorted: [5]u8,
    bid: u64,
    ord: u64,
    joker_ord: u64,
    joker_vals: [5]u8,
    pub fn from(buf: []const u8) !Hand {
        var chunks = std.mem.split(u8, buf, " ");
        var card_buf = chunks.next().?;
        var cards: [5]u8 = undefined;
        var vals: [5]u8 = undefined;
        var vals_sorted: [5]u8 = undefined;
        for (card_buf, 0..) |card, i| {
            cards[i] = card;
            vals[i] = to_val(card);
            vals_sorted[i] = vals[i];
        }
        std.mem.sort(u8, &vals_sorted, {}, std.sort.desc(u8));

        const bid = try std.fmt.parseInt(u64, chunks.next().?, 10);

        const ord = ordinal(vals_sorted, false);
        const joker_ord = ordinal(vals_sorted, true);

        var joker_vals: [5]u8 = undefined;
        for (vals, 0..) |v, i| {
            joker_vals[i] = if (v == 11) 0 else v;
        }

        return Hand{
            .cards = cards,
            .vals = vals,
            .vals_sorted = vals_sorted,
            .bid = bid,
            .ord = ord,
            .joker_ord = joker_ord,
            .joker_vals = joker_vals,
        };
    }
    fn compare(self: Hand, other: Hand) bool {
        return _compare(self.ord, self.vals, other.ord, other.vals);
    }
    fn compare_joker(self: Hand, other: Hand) bool {
        return _compare(self.joker_ord, self.joker_vals, other.joker_ord, other.joker_vals);
    }
    fn _compare(h1_ord: u64, h1_vals: [5]u8, h2_ord: u64, h2_vals: [5]u8) bool {
        if (h1_ord > h2_ord) {
            return true;
        }
        if (h1_ord < h2_ord) {
            return false;
        }
        for (0..h1_vals.len) |i| {
            if (h1_vals[i] > h2_vals[i]) {
                return true;
            }
            if (h1_vals[i] < h2_vals[i]) {
                return false;
            }
        }
        return false;
    }
};

fn to_val(card: u8) u8 {
    return switch (card) {
        '2'...'9' => card - '2' + 2,
        'T' => 10,
        'J' => 11,
        'Q' => 12,
        'K' => 13,
        'A' => 14,
        else => unreachable,
    };
}

fn ordinal(vals: [5]u8, jokers: bool) u64 {
    var track = [_]u8{0} ** 5;
    var track_idx: usize = 0;
    var i: usize = 0;
    var j: usize = 0;
    var joker_count: u8 = 0;
    while (i < track.len) {
        while (j < track.len) {
            if (vals[i] == vals[j]) {
                if (vals[i] == 11) {
                    joker_count += 1;
                }
                if (!jokers or vals[i] != 11) {
                    track[track_idx] += 1;
                }
                j += 1;
            } else {
                break;
            }
        }
        i = j;
        if (!jokers or (i < vals.len and vals[i] != 11)) {
            track_idx += 1;
        }
    }
    std.mem.sort(u8, &track, {}, std.sort.desc(u8));
    if (jokers) {
        track[0] += joker_count;
    }
    var ord: u64 = 0;
    for (track, 1..) |t, ti| {
        ord += t * std.math.pow(u64, 10, track.len - ti);
    }
    return ord;
}

test "hand comparisons" {
    print("\n", .{});
    const h1 = try Hand.from("KK677 1");
    try std.testing.expect(h1.ord == 22100);
    try std.testing.expect(h1.joker_ord == 22100);

    const h2 = try Hand.from("KTJJT 2");
    try std.testing.expect(h2.ord == 22100);
    try std.testing.expect(h2.joker_ord == 41000);

    try std.testing.expect(h1.compare(h2));
    try std.testing.expect(!h2.compare(h1));

    try std.testing.expect(!h1.compare_joker(h2));
    try std.testing.expect(h2.compare_joker(h1));
}
