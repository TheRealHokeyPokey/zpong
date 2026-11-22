const std = @import("std");
const Io = std.Io;
const net = std.Io.net;
const Socket = net.Socket;

const assert = std.debug.assert;

const sdl = @import("main.zig").sdl;

const game = @import("game.zig");

const host_address_string = "12345";
const host_port = 1111;

fn connectToHost(io: Io) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_file_reader: Io.File.Reader = .init(.stdout(), io, &stdin_buffer);
    const stdin = &stdin_file_reader.interface;

    try stdout.print("Please enter host IPv4 address like \"address:port\": ", .{});
    try stdout.flush();
    const address_literal = try stdin.takeDelimiterInclusive('\n');
    const address: net.IpAddress = try .parseLiteral(address_literal);

    if (address.getPort() != 55555) {
        @panic("Wrong port");
    }

    const stream: net.Stream = try address.connect(io, .{
        .mode = .stream,
        .protocol = .tcp,
        .timeout = .{ .duration = .{ .raw = .fromSeconds(5) } },
    });
    defer stream.close(io);
    std.log.info("Connected to host", .{});

    var write_buffer: [1024]u8 = undefined;
    var stream_writer = stream.writer(io, &write_buffer);
    const writer: *Io.Writer = &stream_writer.interface;

    var read_buffer: [1024]u8 = undefined;
    var stream_reader = stream.reader(io, &read_buffer);
    const reader: *Io.Reader = &stream_reader.interface;

    // std.log.info("Client writing message", .{});
    // try writer.print("Server, do you copy?\n", .{});
    // try writer.flush();
    // std.log.info("Message written", .{});
    //
    // const response = try reader.takeDelimiterInclusive('\n');
    // std.log.info("Response read: {s}\n", .{response});
}

pub fn pollGameState(reader: *Io.Reader) !void {}
