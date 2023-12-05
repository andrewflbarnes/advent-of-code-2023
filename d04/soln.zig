const std = @import("std");
const print = std.debug.print;

const max_cards = 256;

pub fn main() !void {
    try solve("d04/test1");
    try solve("d04/input");
}

fn solve(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buffer: [256]u8 = undefined;

    const alloc = std.heap.page_allocator;
    var cards = std.AutoArrayHashMap(u16, ScratchCard).init(alloc);
    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        var card = ScratchCard.from(line);
        try cards.put(card.id, card);
    }

    var total: u32 = 0;
    for (cards.values()) |card| {
        total += card.value();
    }
    print("Points: {d}\n", .{total});

    var total_card_count: u32 = 0;
    var card_counts = [_]u32{1} ** max_cards;

    for (cards.values()) |card| {
        const current_card_count = card_counts[card.id];
        total_card_count += current_card_count;
        const matched = card.matched();
        for (card.id + 1..card.id + 1 + matched) |i| {
            card_counts[i] += current_card_count;
        }
    }
    print("Tickets: {d}\n", .{total_card_count});
}

const ScratchCard = struct {
    id: u16,
    winning: [16]u8,
    have: [32]u8,
    fn matched(self: *const ScratchCard) usize {
        var count: usize = 0;
        for (self.winning) |winner| {
            if (winner == 0) {
                break;
            }
            for (self.have) |has| {
                if (has == 0) {
                    break;
                }
                if (has == winner) {
                    count += 1;
                }
            }
        }
        return count;
    }
    fn value(self: *const ScratchCard) u32 {
        var total: u32 = 0;
        for (self.winning) |winner| {
            if (winner == 0) {
                break;
            }
            for (self.have) |has| {
                if (has == 0) {
                    break;
                }
                if (has == winner) {
                    total = if (total == 0) 1 else total * 2;
                }
            }
        }
        return total;
    }
    fn from(card: []const u8) ScratchCard {
        var card_chunks = std.mem.split(u8, card, ": ");
        const card_id = card_chunks.next().?;
        var card_id_chunks = std.mem.split(u8, card_id, " ");
        var card_num: u16 = 0;
        while (card_id_chunks.next()) |card_id_chunk| {
            if (card_id_chunk.len > 0 and std.ascii.isDigit(card_id_chunk[0])) {
                card_num = std.fmt.parseInt(u16, card_id_chunk, 10) catch unreachable;
            }
        }

        const game = card_chunks.next().?;
        var game_chunks = std.mem.split(u8, game, " | ");

        var wins: [16]u8 = undefined;
        @memset(&wins, 0);
        var card_wins = std.mem.split(u8, game_chunks.next().?, " ");
        var idx: usize = 0;
        while (card_wins.next()) |winner| {
            if (winner.len > 0) {
                wins[idx] = std.fmt.parseInt(u8, winner, 10) catch unreachable;
                idx += 1;
            }
        }
        var haves: [32]u8 = undefined;
        @memset(&haves, 0);
        var card_haves = std.mem.split(u8, game_chunks.next().?, " ");
        idx = 0;
        while (card_haves.next()) |have| {
            if (have.len > 0) {
                haves[idx] = std.fmt.parseInt(u8, have, 10) catch unreachable;
                idx += 1;
            }
        }
        return ScratchCard{
            .id = card_num,
            .winning = wins,
            .have = haves,
        };
    }
};
