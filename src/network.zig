const std = @import("std");
const Io = std.Io;
const net = std.Io.net;
const Socket = net.Socket;

pub fn printHello(writer: *Io.Writer) !void {
    try writer.print("Hello world!\n", .{});
    try writer.flush();
}

pub fn socketTest(io: Io, stdout: *Io.Writer) !void {
    const sockets = try net.Socket.createPair(io, .{});

    const socket_one = sockets[0];
    const socket_one_stream: net.Stream = .{ .socket = socket_one };
    // net.Stream{ .socket = socket_one });
    var socket_one_buffer: [1024]u8 = undefined;
    var socket_one_network_writer = socket_one_stream.writer(io, &socket_one_buffer);
    const socket_one_writer = &socket_one_network_writer.interface;

    const socket_two = sockets[1];
    const socket_two_stream: net.Stream = .{ .socket = socket_two };
    // const socket_two_stream = net.Stream(.{ .socket = socket_two });
    var socket_two_buffer: [1024]u8 = undefined;
    var socket_two_network_reader = socket_two_stream.reader(io, &socket_two_buffer);
    const socket_two_reader = &socket_two_network_reader.interface;

    try socket_one_writer.print("Hello world from socket one!\n", .{});
    try socket_one_writer.flush();

    const message = try socket_two_reader.takeDelimiter('\n');

    try stdout.print("Message recieved: {s}\n", .{message.?});
    try stdout.flush();

    //
    // try socket_one.send(io, )
    // const stream: net.Stream = .{ .socket =  }
}

pub fn socketTestTwo(io: Io, stdout: *Io.Writer) !void {
    const address_one: net.IpAddress = try .parse("127.0.0.1", 1111);
    const address_one_ptr: *const net.IpAddress = &address_one;
    // const socket_one = try net.IpAddress.listen(address_one_ptr, io, .{ .kernel_backlog = 1, .mode = .stream, .protocol = .tcp });
    const socket_one_stream = try net.IpAddress.connect(address_one_ptr, io, .{ .protocol = .tcp, .mode = .stream });
    // const socket_one_stream: net.Stream = .{ .socket = socket_one };
    var socket_one_buffer: [1024]u8 = undefined;
    var socket_one_network_writer = socket_one_stream.writer(io, &socket_one_buffer);
    const socket_one_writer = &socket_one_network_writer.interface;

    const address_two: net.IpAddress = try .parse("127.0.0.1", 1112);
    const address_two_ptr: *const net.IpAddress = &address_two;
    const socket_two = try net.IpAddress.listen(address_two_ptr, io, .{ .kernel_backlog = 1, .mode = .stream, .protocol = .tcp });
    const socket_two_stream: net.Stream = .{ .socket = socket_two };
    var socket_two_buffer: [1024]u8 = undefined;
    var socket_two_network_reader = socket_two_stream.reader(io, &socket_two_buffer);
    const socket_two_reader = &socket_two_network_reader.interface;

    try socket_one_writer.print("Hello world from socket one!\n", .{});
    try socket_one_writer.flush();

    const message = try socket_two_reader.takeDelimiter('\n');

    try stdout.print("Message recieved: {s}\n", .{message.?});
    try stdout.flush();
    try stdout.print("Hi from socket test two!\n", .{});
    try stdout.flush();
}
