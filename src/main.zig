const std = @import("std");
const Io = std.Io;

const zpong = @import("zpong");
pub const sdl = @import("sdl3");
const game = @import("game.zig");

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);
    const io = init.io;

    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    const is_host = if (std.mem.eql(u8, args[1], "host")) true else false;
    std.log.info("isHost: {}", .{is_host});

    try game.runGameLoop(io);
}
