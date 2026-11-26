const std = @import("std");
const Io = std.Io;
const net = Io.net;

const assert = std.debug.assert;

const pi = std.math.pi;
const clock = Io.Clock.real;

const sdl = @import("main.zig").sdl;

const draw = @import("draw.zig");
const fillPaddleRect = draw.fillPaddleRect;
const drawObjects = draw.drawObjects;

const zpong = @import("zpong");
const convertSDLError = zpong.convertSDLError;

const FRect = sdl.SDL_FRect;
const Renderer = sdl.SDL_Renderer;

const setRenderDrawColorFloat = sdl.SDL_SetRenderDrawColorFloat;
const renderFillRect = sdl.SDL_RenderFillRect;
const getError = sdl.SDL_GetError;
const getKeyboardState = sdl.SDL_GetKeyboardState;

const scancode_w = sdl.SDL_SCANCODE_W;
const scancode_s = sdl.SDL_SCANCODE_S;
const scancode_up = sdl.SDL_SCANCODE_UP;
const scancode_down = sdl.SDL_SCANCODE_DOWN;

const speed: f32 = 0.007;
const width: f32 = 0.045;

const window_width_initial: c_int = 960;
const window_height_initial: c_int = 540;

const window_width_logical: u16 = 1920;
const window_height_logical: u16 = 1080;

const ns_between_frames = std.time.ns_per_s / 60;

pub const GameType = enum {
    host,
    client,
    local_multiplayer,
};

pub const Config = struct {
    type: GameType,
    use_local_host: ?bool,
    host_port: ?u16,
    host_ip_address: ?net.IpAddress,
};

const Player = enum {
    player_1,
    player_2,
};

const Move = enum(u8) {
    up,
    down,
    no_move,
};

pub const ObjectPosition = struct {
    x: f32,
    y: f32,
};

pub const ObjectRectangles = struct {
    p1_paddle_rect: *FRect,
    p2_paddle_rect: *FRect,
    ball_rect: *FRect,
};

const GameState = extern struct {
    p1_paddle: FRect,
    p2_paddle: FRect,
    ball: FRect,
};

pub fn runLocalMultiplayer(io: Io) !void {
    _ = sdl.SDL_SetAppMetadata(
        "Example Renderer Clear",
        "1.0",
        "com.example.renderer-clear",
    );

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.debug.panic("SDL_Init failed: {s}\n", .{sdl.SDL_GetError()});
        return sdl.SDL_APP_FAILURE;
    }
    defer sdl.SDL_Quit();

    std.debug.print(
        "video driver: {s}\n",
        .{sdl.SDL_GetCurrentVideoDriver() orelse @as([*c]const u8, "null")},
    );

    var window: ?*sdl.SDL_Window = null;
    var renderer: ?*sdl.SDL_Renderer = null;

    if (!sdl.SDL_CreateWindowAndRenderer(
        "examples/renderer/clear",
        window_width_initial,
        window_height_initial,
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
        &window,
        &renderer,
    )) {
        std.debug.panic(
            "Couldn't create window/renderer: {s}\n",
            .{sdl.SDL_GetError()},
        );
    }

    defer sdl.SDL_DestroyWindow(window);
    defer sdl.SDL_DestroyRenderer(renderer);

    {
        var display_width: c_int = undefined;
        var display_height: c_int = undefined;

        if (!sdl.SDL_GetRenderOutputSize(
            renderer,
            &display_width,
            &display_height,
        )) {
            std.debug.panic(
                "Couldn't get render output size: {s}\n",
                .{sdl.SDL_GetError()},
            );
        }

        if (!sdl.SDL_SetWindowSize(
            window,
            display_width,
            display_height,
        )) {
            std.debug.panic(
                "Couldn't set window size: {s}\n",
                .{sdl.SDL_GetError()},
            );
        }
    }

    if (!sdl.SDL_SetRenderLogicalPresentation(
        renderer,
        window_width_logical,
        window_height_logical,
        sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX,
    )) {
        std.debug.panic(
            "Couldn't set logical presentation: {s}\n",
            .{sdl.SDL_GetError()},
        );
    }

    var p1_paddle_pos: ObjectPosition = undefined;
    var p2_paddle_pos: ObjectPosition = undefined;

    var p1_paddle_rect: FRect = undefined;
    var p2_paddle_rect: FRect = undefined;
    var ball_rect: FRect = .{ .h = 0.0, .w = 0.0, .x = 0.0, .y = 0.0 };
    const object_rectangles: ObjectRectangles = .{
        .p1_paddle_rect = &p1_paddle_rect,
        .p2_paddle_rect = &p2_paddle_rect,
        .ball_rect = &ball_rect,
    };

    var ball_dx: f32 = speed;
    var ball_dy: f32 = speed;

    var frame_start: Io.Timestamp = std.Io.Clock.now(.real, io);

    var p1_score: u16 = 0;
    var p2_score: u16 = 0;

    while (true) {
        var event: sdl.SDL_Event = undefined;
        _ = sdl.SDL_PollEvent(&event);

        if (event.type == sdl.SDL_EVENT_QUIT) {
            std.process.cleanExit(io);
            return;
        }

        const p1_move = getPlayerMove(.player_1);
        const p1_paddle_dy = getPaddleVelocityFromMove(p1_move);

        const p2_move = getPlayerMove(.player_2);
        const p2_paddle_dy = getPaddleVelocityFromMove(p2_move);

        ball_rect.w = width * window_height_logical;
        ball_rect.h = ball_rect.w;

        updatePaddlePosition(
            &p1_paddle_pos,
            p1_paddle_dy,
            window_height_logical,
        );
        updateP2PaddlePosition(
            &p2_paddle_pos,
            p2_paddle_dy,
            window_height_logical,
            window_width_logical,
        );

        fillPaddleRect(p1_paddle_pos, window_height_logical, &p1_paddle_rect);
        fillPaddleRect(p2_paddle_pos, window_height_logical, &p2_paddle_rect);

        if (sdl.SDL_HasRectIntersectionFloat(
            @ptrCast(&ball_rect),
            @ptrCast(&p1_paddle_rect),
        )) {
            ball_dx = speed;
        } else if (sdl.SDL_HasRectIntersectionFloat(
            @ptrCast(&ball_rect),
            @ptrCast(&p2_paddle_rect),
        )) {
            ball_dx = -speed;
        } else {
            if (ball_rect.x + ball_rect.w > window_width_logical) {
                ball_dx = -@abs(ball_dx);
                p1_score += 1;
                std.log.info(
                    "P2 scored. P1 score: {}, P2 score: {}",
                    .{ p1_score, p2_score },
                );
            } else if (ball_rect.x <= 0) {
                ball_dx = @abs(ball_dx);
                p2_score += 1;
                std.log.info(
                    "P1 scored. P1 score: {}, P2 score: {}",
                    .{ p1_score, p2_score },
                );
            }
        }
        if (ball_rect.y + ball_rect.h > window_height_logical) {
            ball_dy = -@abs(ball_dy);
        } else if (ball_rect.y <= 0) {
            ball_dy = @abs(ball_dy);
        }

        ball_rect.x += ball_dx * window_height_logical;
        ball_rect.y += ball_dy * window_height_logical;

        const time_now: Io.Timestamp = .now(io, clock);
        const frame_duration = frame_start.durationTo(time_now);
        const ns_to_wait: i96 = @max(
            0,
            ns_between_frames - frame_duration.nanoseconds,
        );
        const duration_to_wait: Io.Duration = .{ .nanoseconds = ns_to_wait };
        try Io.sleep(io, duration_to_wait, clock);
        frame_start = time_now;

        try drawObjects(renderer, &object_rectangles);
    }
}

pub fn runBasicHostLoop(io: Io, config: Config) !void {
    const window_width_c_int = 1920;
    const window_height_c_int = 1080;
    _ = sdl.SDL_SetAppMetadata(
        "ZPong Host",
        "0.0",
        "",
    );

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.debug.panic("SDL_Init failed: {s}\n", .{sdl.SDL_GetError()});
        return sdl.SDL_APP_FAILURE;
    }
    defer sdl.SDL_Quit();

    std.debug.print(
        "video driver: {s}\n",
        .{sdl.SDL_GetCurrentVideoDriver() orelse @as([*c]const u8, "null")},
    );

    var window: ?*sdl.SDL_Window = null;
    var renderer: ?*sdl.SDL_Renderer = null;

    if (!sdl.SDL_CreateWindowAndRenderer(
        "zpong host window",
        window_width_c_int,
        window_height_c_int,
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
        &window,
        &renderer,
    )) {
        std.debug.panic(
            "Couldn't create window/renderer: {s}\n",
            .{sdl.SDL_GetError()},
        );
    }
    defer sdl.SDL_DestroyWindow(window);
    defer sdl.SDL_DestroyRenderer(renderer);

    var p1_paddle_pos: ObjectPosition = undefined;
    var p2_paddle_pos: ObjectPosition = undefined;

    var p1_paddle_rect: FRect = undefined;
    var p2_paddle_rect: FRect = undefined;
    var ball_rect: FRect = .{ .h = 0.0, .w = 0.0, .x = 0.0, .y = 0.0 };
    const object_rectangles: ObjectRectangles = .{
        .p1_paddle_rect = &p1_paddle_rect,
        .p2_paddle_rect = &p2_paddle_rect,
        .ball_rect = &ball_rect,
    };

    var ball_dx: f32 = speed;
    var ball_dy: f32 = speed;

    var frame_start: Io.Timestamp = std.Io.Clock.now(.real, io);

    var p1_score: u16 = 0;
    var p2_score: u16 = 0;

    const address = blk: {
        if (config.use_local_host.?) {
            break :blk try Io.net.IpAddress.parseIp4(
                "127.0.0.1",
                config.host_port.?,
            );
        } else {
            break :blk try Io.net.IpAddress.parseIp4(
                "0.0.0.0",
                config.host_port.?,
            );
        }
    };
    const connect_options: Io.net.IpAddress.ListenOptions = .{};

    // const udp_socket = try address.bind(io, .{ .protocol = .udp });

    std.log.info(
        "Server waiting for connection on {f}, port {}",
        .{ address.ip4, address.getPort() },
    );

    var server: Io.net.Server = try Io.net.IpAddress.listen(
        &address,
        io,
        connect_options,
    );
    defer server.deinit(io);
    std.log.info("Server running, waiting for client to connect", .{});

    // blocks until a client connects
    const stream = try server.accept(io);
    defer stream.close(io);
    std.log.info("Client connected", .{});

    var write_buffer: [1024]u8 = undefined;
    var stream_writer = stream.writer(io, &write_buffer);
    const writer: *Io.Writer = &stream_writer.interface;

    var read_buffer: [1024]u8 = undefined;
    var stream_reader = stream.reader(io, &read_buffer);
    const reader: *Io.Reader = &stream_reader.interface;

    var a_future = io.async(getClientMove, .{reader});
    defer _ = a_future.cancel(io) catch {};

    // var p1_move: Move = .no_move;
    // var p2_move: Move = .no_move;

    while (true) {
        var event: sdl.SDL_Event = undefined;
        _ = sdl.SDL_PollEvent(&event);

        if (event.type == sdl.SDL_EVENT_QUIT) {
            std.process.cleanExit(io);
            return;
        }

        // udp_socket.receiveTimeout(io, read_buffer, .{ .duration = .{ .clock =  } })
        const p1_move = getPlayerMove(.player_1);
        const p2_move = try a_future.await(io);

        const p1_paddle_dy = getPaddleVelocityFromMove(p1_move);
        // const p2_move = try getClientMove(reader);
        const p2_paddle_dy = getPaddleVelocityFromMove(p2_move);

        const window_width: f32 = @floatFromInt(window_width_c_int);
        const window_height: f32 = @floatFromInt(window_height_c_int);

        ball_rect.w = width * window_height;
        ball_rect.h = ball_rect.w;

        updatePaddlePosition(&p1_paddle_pos, p1_paddle_dy, window_height);
        updateP2PaddlePosition(&p2_paddle_pos, p2_paddle_dy, window_height, window_width);

        fillPaddleRect(p1_paddle_pos, window_height, &p1_paddle_rect);
        fillPaddleRect(p2_paddle_pos, window_height, &p2_paddle_rect);

        if (sdl.SDL_HasRectIntersectionFloat(
            @ptrCast(&ball_rect),
            @ptrCast(&p1_paddle_rect),
        )) {
            ball_dx = speed;
        } else if (sdl.SDL_HasRectIntersectionFloat(
            @ptrCast(&ball_rect),
            @ptrCast(&p2_paddle_rect),
        )) {
            ball_dx = -speed;
        } else {
            if (ball_rect.x + ball_rect.w > window_width) {
                ball_dx = -@abs(ball_dx);
                p1_score += 1;
                std.log.info("P2 scored. P1 score: {}, P2 score: {}", .{ p1_score, p2_score });
            } else if (ball_rect.x <= 0) {
                ball_dx = @abs(ball_dx);
                p2_score += 1;
                std.log.info("P1 scored. P1 score: {}, P2 score: {}", .{ p1_score, p2_score });
            }
        }
        if (ball_rect.y + ball_rect.h > window_height) {
            ball_dy = -@abs(ball_dy);
        } else if (ball_rect.y <= 0.0) {
            ball_dy = @abs(ball_dy);
        }

        ball_rect.x += ball_dx * window_height;
        ball_rect.y += ball_dy * window_height;

        const game_state: GameState = .{ .p1_paddle = p1_paddle_rect, .p2_paddle = p2_paddle_rect, .ball = ball_rect };

        const time_now: Io.Timestamp = .now(io, clock);
        const frame_duration = frame_start.durationTo(time_now);
        const ns_to_wait: i96 = @max(0, ns_between_frames - frame_duration.nanoseconds);
        const duration_to_wait: Io.Duration = .{ .nanoseconds = ns_to_wait };
        try Io.sleep(io, duration_to_wait, clock);
        frame_start = time_now;

        try writer.writeStruct(game_state, .big);
        try writer.flush();

        a_future = io.async(getClientMove, .{reader});

        try drawObjects(renderer, &object_rectangles);
    }
}

pub fn runClientLoop(io: Io, config: Config) !void {
    const window_width_c_int = 1920;
    const window_height_c_int = 1080;
    _ = sdl.SDL_SetAppMetadata(
        "ZPong Client",
        "0.0",
        "",
    );

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        std.debug.panic("SDL_Init failed: {s}\n", .{sdl.SDL_GetError()});
        return sdl.SDL_APP_FAILURE;
    }
    defer sdl.SDL_Quit();

    std.debug.print(
        "video driver: {s}\n",
        .{sdl.SDL_GetCurrentVideoDriver() orelse @as([*c]const u8, "null")},
    );

    var window: ?*sdl.SDL_Window = null;
    var renderer: ?*sdl.SDL_Renderer = null;

    if (!sdl.SDL_CreateWindowAndRenderer(
        "zpong client window",
        window_width_c_int,
        window_height_c_int,
        sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
        &window,
        &renderer,
    )) {
        std.debug.panic(
            "Couldn't create window/renderer: {s}\n",
            .{sdl.SDL_GetError()},
        );
    }
    defer sdl.SDL_DestroyWindow(window);
    defer sdl.SDL_DestroyRenderer(renderer);

    const address = config.host_ip_address.?;

    const stream: net.Stream = try address.connect(io, .{
        .mode = .stream,
        .protocol = .tcp,
        .timeout = .none,
    });
    defer stream.close(io);
    std.log.info("Connected to host", .{});

    var write_buffer: [1024]u8 = undefined;
    var stream_writer = stream.writer(io, &write_buffer);
    const writer: *Io.Writer = &stream_writer.interface;

    var read_buffer: [1024]u8 = undefined;
    var stream_reader = stream.reader(io, &read_buffer);
    const reader: *Io.Reader = &stream_reader.interface;

    var p1_paddle_rect: FRect = undefined;
    var p2_paddle_rect: FRect = undefined;
    var ball_rect: FRect = .{ .h = 0.0, .w = 0.0, .x = 0.0, .y = 0.0 };
    const object_rectangles: ObjectRectangles = .{
        .p1_paddle_rect = &p1_paddle_rect,
        .p2_paddle_rect = &p2_paddle_rect,
        .ball_rect = &ball_rect,
    };
    var a_future = io.async(getState2, .{ reader, .big });
    defer _ = a_future.cancel(io) catch {};
    while (true) {
        var event: sdl.SDL_Event = undefined;
        _ = sdl.SDL_PollEvent(&event);

        if (event.type == sdl.SDL_EVENT_QUIT) {
            std.process.cleanExit(io);
            return;
        }

        // var frame_start: Io.Timestamp = std.Io.Clock.now(.real, io);

        // const p1_paddle_rect_copy = p1_paddle_rect.*;
        // const p2_paddle_rect_copy = p2_paddle_rect.*;
        // const ball_rect_copy = ball_rect.*;
        // const s = extern struct { p1_paddle: p1_paddle_rect_copy, p2_paddle: p2_paddle_rect_copy, ball: ball_rect_copy };
        // try writer.writeStruct(s, .big);
        const move = getPlayerMove(.player_2);
        const move_int = @intFromEnum(move);
        try writer.writeInt(@TypeOf(move_int), move_int, .big);
        try writer.flush();

        // const game_state: GameState = try reader.takeStruct(GameState, .big);

        // var get_state = try io.async(reader.takeStruct, .{ GameState, .big });
        // defer get_state.cancel(io) catch {};
        // const game_state = try get_state.await(io);

        // var a_future = io.async(getState, .{ io, stream, .big });
        // defer _ = a_future.cancel(io) catch {};
        // const game_state = try a_future.await(io);

        const game_state = try a_future.await(io);

        object_rectangles.p1_paddle_rect.* = game_state.p1_paddle;
        object_rectangles.p2_paddle_rect.* = game_state.p2_paddle;
        object_rectangles.ball_rect.* = game_state.ball;

        // const time_now: Io.Timestamp = .now(io, clock);
        // const frame_duration = frame_start.durationTo(time_now);
        // const ns_to_wait: i96 = @max(0, ns_between_frames - frame_duration.nanoseconds);
        // const duration_to_wait: Io.Duration = .{ .nanoseconds = ns_to_wait };
        // try Io.sleep(io, duration_to_wait, clock);
        // frame_start = time_now;

        try drawObjects(renderer, &object_rectangles);
        a_future = io.async(getState2, .{ reader, .big });
    }
}

fn getState(io: Io, stream: net.Stream, endian: std.lang.Endian) !GameState {
    var read_buffer: [1024]u8 = undefined;
    var stream_reader = stream.reader(io, &read_buffer);
    const reader: *Io.Reader = &stream_reader.interface;
    return try reader.takeStruct(GameState, endian);
}

fn getState2(reader: *Io.Reader, endian: std.lang.Endian) !GameState {
    return try reader.takeStruct(GameState, endian);
}

fn getPlayerMove(player: Player) Move {
    const key_states: [*]const bool = getKeyboardState(null);
    if (player == .player_1) {
        if (key_states[scancode_w] and key_states[scancode_s]) {
            return .no_move;
        }
        if (key_states[scancode_w]) {
            return .up;
        }
        if (key_states[scancode_s]) {
            return .down;
        }
    } else {
        if (key_states[scancode_up] and key_states[scancode_down]) {
            return .no_move;
        }
        if (key_states[scancode_up]) {
            return .up;
        }
        if (key_states[scancode_down]) {
            return .down;
        }
    }
    return .no_move;
}

fn getPaddleVelocityFromMove(move: Move) f32 {
    switch (move) {
        .no_move => return 0.0,
        .up => return -speed,
        .down => return speed,
    }
}

fn getClientMove(reader: *Io.Reader) !Move {
    const move = try reader.takeEnum(Move, .big);
    return move;
}

fn updateP2PaddlePosition(
    paddle_pos: *ObjectPosition,
    paddle_dy: f32,
    window_height: f32,
    window_width: f32,
) void {
    // update x position
    const paddle_width = width * window_height;
    paddle_pos.x = window_width - paddle_width;

    updatePaddlePosition(paddle_pos, paddle_dy, window_height);
}

fn updatePaddlePosition(
    paddle_pos: *ObjectPosition,
    paddle_dy: f32,
    window_height: f32,
) void {
    // update y position, limit to screen border
    const next_paddle_y = paddle_pos.y + paddle_dy * window_height;
    const paddle_height = 6 * width * window_height;
    const paddle_y_limit = window_height - paddle_height;
    paddle_pos.y = @max(@min(next_paddle_y, paddle_y_limit), 0.0);
}

fn updateBallPosition(
    ball_pos: *ObjectPosition,
    ball_dx: f32,
    ball_dy: f32,
    window_height: f32,
) void {
    ball_pos.x += ball_dx * window_height;
    ball_pos.y += ball_dy * window_height;
}
