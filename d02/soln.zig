const std = @import("std");
const print = std.debug.print;

const red_cubes = 12;
const green_cubes = 12;
const blue_cubes = 12;

const Game = struct {
    game_id: u32,
    valid: bool = true,
    r_min: u8 = 0,
    g_min: u8 = 0,
    b_min: u8 = 0,
    fn power(self: *const Game) u32 {
        return @as(u32, self.r_min) * @as(u32, self.g_min) * @as(u32, self.b_min);
    }
};

pub fn main() !void {
    try solve("d02/test1");
    try solve("d02/input");
}

fn solve(filename: []const u8) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buffer: [256]u8 = undefined;

    var total: u32 = 0;
    var total_power: u32 = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |game| {
        const game_info = try parse_game(game, red_cubes, green_cubes, blue_cubes);
        if (game_info.valid) {
            total += game_info.game_id;
        }
        total_power += game_info.power();
    }
    print("{d}\n", .{total});
    print("{d}\n", .{total_power});
}

fn parse_game(game_line: []const u8, r_max: u8, g_max: u8, b_max: u8) !Game {
    var game_chunks = std.mem.split(u8, game_line, ":");
    const game_id = try parse_game_id(game_chunks.next().?);

    var game = Game{
        .game_id = game_id,
    };

    var reveals = std.mem.split(u8, game_chunks.next().?, ";");
    while (reveals.next()) |reveal| {
        try update_game(&game, reveal, r_max, g_max, b_max);
    }
    return game;
}

fn parse_game_id(game_id_chunk: []const u8) !u32 {
    const game_id = game_id_chunk[std.mem.indexOf(u8, game_id_chunk, " ").? + 1 ..];
    return try std.fmt.parseInt(u32, game_id, 10);
}

fn update_game(game: *Game, reveal: []const u8, r_max: u8, g_max: u8, b_max: u8) !void {
    var reveal_chunks = std.mem.split(u8, reveal, ",");
    while (reveal_chunks.next()) |colour_count| {
        var colour_count_chunks = std.mem.split(u8, colour_count[1..], " ");
        var count = try std.fmt.parseInt(u8, colour_count_chunks.next().?, 10);
        var colour = colour_count_chunks.next().?;
        if (game.valid) {
            if (std.mem.eql(u8, "red", colour) and count > r_max) {
                game.valid = false;
            } else if (std.mem.eql(u8, "green", colour) and count > g_max) {
                game.valid = false;
            } else if (std.mem.eql(u8, "blue", colour) and count > b_max) {
                game.valid = false;
            }
        }
        if (std.mem.eql(u8, "red", colour) and count > game.r_min) {
            game.r_min = count;
        } else if (std.mem.eql(u8, "green", colour) and count > game.g_min) {
            game.g_min = count;
        } else if (std.mem.eql(u8, "blue", colour) and count > game.b_min) {
            game.b_min = count;
        }
    }
}
