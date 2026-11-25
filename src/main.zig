const std = @import("std");
const mem = std.mem;
const eql = mem.eql;
const startsWith = mem.startsWith;

const Io = std.Io;

const zpong = @import("zpong");
pub const sdl = @import("sdl3");

const game = @import("game.zig");
const GameType = game.GameType;
const Config = game.Config;
const ConfigError = game.ConfigError;

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);

    const io = init.io;
    //
    // var io_threaded: std.Io.Threaded = .init(init.gpa, .{});
    // defer io_threaded.deinit();
    // const io = io_threaded.io();
    //
    // try io.init(init.gpa, .{.sync_limit});
    // defer io.deinit();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(
        .stdout(),
        io,
        &stdout_buffer,
    );
    const stdout = &stdout_file_writer.interface;

    var config: Config = undefined;
    config.type = .local_multiplayer;
    config.host_port = null;
    config.use_local_host = null;
    config.host_ip_address = null;

    try handleArgs(args, stdout, &config);
    const valid_config = validateConfig(config);
    if (valid_config) {
        try stdout.print("Running with config: {}\n", .{config});
        try stdout.flush();

        switch (config.type) {
            .local_multiplayer => try game.runLocalMultiplayer(io),
            .client => try game.runClientLoop(io, config),
            .host => try game.runBasicHostLoop(io, config),
        }
    } else {
        std.log.err("Invalid config {}, exiting", .{config});
        @panic("");
    }
}

fn validateConfig(config: Config) bool {
    switch (config.type) {
        .local_multiplayer => {
            return (config.host_port == null and
                config.use_local_host == null and
                config.host_ip_address == null);
        },
        .client => {
            return config.host_port == null and
                config.use_local_host == null and
                config.host_ip_address != null;
        },
        .host => {
            return config.host_port != null and
                config.use_local_host != null and
                config.host_ip_address == null;
        },
    }
}

fn handleArgs(args: []const []const u8, stdout: *Io.Writer, config: *Config) !void {
    if (args.len == 1) {
        return;
    }
    const any_help = for (args[1..]) |arg| {
        if (eql(u8, arg, "--help")) {
            break true;
        }
    } else false;

    if (any_help) {
        try printHelp(stdout);
        std.process.exit(0);
    }

    for (args[1..]) |arg| {
        try handleArg(arg, stdout, config);
    }
}

fn handleArg(arg: []const u8, stdout: *Io.Writer, config: *Config) !void {
    if (startsWith(u8, arg, "--type=")) {
        const type_value = arg[7..];
        if (eql(u8, type_value, "host")) {
            config.type = .host;
            config.use_local_host = config.use_local_host orelse true;
        } else if (eql(u8, type_value, "client")) {
            config.type = .client;
        } else if (eql(u8, type_value, "singleplayer")) {
            config.type = .local_multiplayer;
        } else {
            std.log.err("unknown game type: {s}", .{type_value});
            try printHelp(stdout);
            @panic("");
        }
    } else if (startsWith(u8, arg, "--host-port=")) {
        config.host_port = try std.fmt.parseInt(u16, arg[12..], 10);
    } else if (eql(u8, arg, "--no-localhost")) {
        config.use_local_host = false;
    } else if (startsWith(u8, arg, "--host-ip=")) {
        config.host_ip_address = try std.Io.net.IpAddress.parseLiteral(
            arg[10..],
        );
    } else {
        std.log.err("unknown argument: {s}", .{arg});
        try printHelp(stdout);
        @panic("");
    }
    return;
}

fn printHelp(writer: *Io.Writer) !void {
    try writer.print(
        \\Usage zpong [options]:
        \\  --type=[host|client|singleplayer]    type of game to start, default singleplayer
        \\
        \\Host options:
        \\  --host-port=[port|null]              port for host to use, default null
        \\  --no-localhost                       host does not listen on localhost, default null or false
        \\                                       if type=host
        \\
        \\Client options:
        \\  --host-ip=[ip|null]                  IPv4 address for client to connect to, default null
        \\                                       X.X.X.X:<PORT>
        \\
    , .{});
    try writer.flush();
}
