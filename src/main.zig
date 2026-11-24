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
    // if (args.len > 1) {
    //
    // }
    // const is_host = if (std.mem.eql(u8, args[1], "host")) true else false;
    // const is_host = args.len > 1;

    if (args.len > 1) {
        if (args[1].len > 7) {
            if (std.mem.eql(u8, args[1], "--type=singleplayer")) {
                try game.runGameLoop(io);
            } else if (std.mem.eql(u8, args[1], "--type=host")) {
                try game.runBasicHostLoop(io);
            } else if (std.mem.eql(u8, args[1], "--type=client")) {
                try game.runClientLoop(io);
            } else {
                std.log.err("Invalid argument: {s}", .{args[1]});
            }
        } else {
            std.log.err("Invalid argument: {s}", .{args[1]});
        }
    } else {
        std.log.err("No arguments found", .{});
    }

    // std.log.info("isHost: {}", .{is_host});
    //
    // if (is_host) {
    //     std.log.info("Running host loop", .{});
    //     try game.runBasicHostLoop(io);
    // } else {
    //     std.log.info("Running client loop", .{});
    //     try game.runClientLoop(io);
    // }
    //
    // try game.runGameLoop(io);
}
