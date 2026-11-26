const std = @import("std");
const Io = std.Io;
const net = Io.net;

const assert = std.debug.assert;

const pi = std.math.pi;
const clock = Io.Clock.real;

const sdl = @import("main.zig").sdl;

const draw = @import("draw.zig");
const getPaddleRect = draw.getPaddleRect;
const getBallRect = draw.getPaddleRect;
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

pub const window_width_logical: u16 = 1920;
pub const window_height_logical: u16 = 1080;

const ns_between_frames = std.time.ns_per_s / 60;
const paddle_width: f32 = width * window_height_logical;
const paddle_height: f32 = 6 * paddle_width;
const ball_width: f32 = width * window_height_logical;

pub const GameType = enum {
    host,
    client,
    local_multiplayer,
};

pub const Config = struct {
    game_type: GameType,
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

pub const ObjectPosition = extern struct {
    x: f32,
    y: f32,
};

pub const ObjectPositions = extern struct {
    p1_paddle_position: ObjectPosition,
    p2_paddle_position: ObjectPosition,
    ball_position: ObjectPosition,
};

const Scores = struct {
    p1: u16,
    p2: u16,
};

pub const ObjectRectangles = struct {
    p1_paddle: *FRect,
    p2_paddle: *FRect,
    ball: *FRect,
};

pub fn runGame(io: Io, config: Config) !void {
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
    switch (config.game_type) {
        .local_multiplayer => try runLocal(io, &renderer),
        .host => try runHost(io, &renderer, config),
        .client => try runClient(io, &renderer, config),
    }
}

fn runLocal(io: Io, renderer_ptr: *?*sdl.SDL_Renderer) !void {
    const renderer = renderer_ptr.*;

    const paddle_y_initial: f32 = (window_height_logical - paddle_height) / 2.0;
    var p1_paddle_rect: FRect = .{
        .x = 0.0,
        .y = paddle_y_initial,
        .h = paddle_height,
        .w = paddle_width,
    };
    const p2_paddle_x: f32 = window_width_logical - paddle_width;
    var p2_paddle_rect: FRect = .{
        .x = p2_paddle_x,
        .y = paddle_y_initial,
        .h = paddle_height,
        .w = paddle_width,
    };
    var ball_rect: FRect = .{
        .x = (window_width_logical - ball_width) / 2.0,
        .y = (window_height_logical - ball_width) / 2.0,
        .h = ball_width,
        .w = ball_width,
    };
    const game_state: ObjectRectangles = .{
        .p1_paddle = &p1_paddle_rect,
        .p2_paddle = &p2_paddle_rect,
        .ball = &ball_rect,
    };

    var ball_dx: f32 = speed;
    var ball_dy: f32 = speed;

    var frame_start: Io.Timestamp = std.Io.Clock.now(.real, io);

    var scores: Scores = .{
        .p1 = 0,
        .p2 = 0,
    };

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

        updatePaddle(&p1_paddle_rect, p1_paddle_dy);
        updatePaddle(&p2_paddle_rect, p2_paddle_dy);

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
                scores.p1 += 1;
                std.log.info(
                    "P2 scored. P1 score: {}, P2 score: {}",
                    .{ scores.p1, scores.p2 },
                );
            } else if (ball_rect.x <= 0) {
                ball_dx = @abs(ball_dx);
                scores.p2 += 1;
                std.log.info(
                    "P1 scored. P1 score: {}, P2 score: {}",
                    .{ scores.p1, scores.p2 },
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

        try drawObjects(renderer, &game_state);
    }
}

fn runHost(io: Io, renderer_ptr: *?*sdl.SDL_Renderer, config: Config) !void {
    const renderer = renderer_ptr.*;

    const paddle_y_initial: f32 = (window_height_logical - paddle_height) / 2.0;
    var p1_paddle_rect: FRect = .{
        .x = 0.0,
        .y = paddle_y_initial,
        .h = paddle_height,
        .w = paddle_width,
    };
    const p2_paddle_x: f32 = window_width_logical - paddle_width;
    var p2_paddle_rect: FRect = .{
        .x = p2_paddle_x,
        .y = paddle_y_initial,
        .h = paddle_height,
        .w = paddle_width,
    };
    var ball_rect: FRect = .{
        .x = (window_width_logical - ball_width) / 2.0,
        .y = (window_height_logical - ball_width) / 2.0,
        .h = ball_width,
        .w = ball_width,
    };
    const game_state: ObjectRectangles = .{
        .p1_paddle = &p1_paddle_rect,
        .p2_paddle = &p2_paddle_rect,
        .ball = &ball_rect,
    };

    var ball_dx: f32 = speed;
    var ball_dy: f32 = speed;

    var frame_start: Io.Timestamp = std.Io.Clock.now(.real, io);

    var scores: Scores = .{
        .p1 = 0,
        .p2 = 0,
    };

    var server: std.Io.net.Server = undefined;
    try getServer(io, config, &server);
    defer server.deinit(io);

    const stream = try server.accept(io);
    defer stream.close(io);
    std.log.info("Client connected", .{});

    var write_buffer: [1024]u8 = undefined;
    var stream_writer = stream.writer(io, &write_buffer);
    const writer: *Io.Writer = &stream_writer.interface;

    var read_buffer: [1024]u8 = undefined;
    var stream_reader = stream.reader(io, &read_buffer);
    const reader: *Io.Reader = &stream_reader.interface;

    var object_positions: ObjectPositions = .{
        .p1_paddle_position = objectRectToPosition(p1_paddle_rect),
        .p2_paddle_position = objectRectToPosition(p2_paddle_rect),
        .ball_position = objectRectToPosition(ball_rect),
    };
    try writer.writeStruct(object_positions, .big);
    try writer.flush();

    while (true) {
        var event: sdl.SDL_Event = undefined;
        _ = sdl.SDL_PollEvent(&event);

        if (event.type == sdl.SDL_EVENT_QUIT) {
            std.process.cleanExit(io);
            return;
        }

        const p1_move = getPlayerMove(.player_1);
        const p1_paddle_dy = getPaddleVelocityFromMove(p1_move);

        const p2_move = try getClientMove(reader);
        const p2_paddle_dy = getPaddleVelocityFromMove(p2_move);

        updatePaddle(&p1_paddle_rect, p1_paddle_dy);
        updatePaddle(&p2_paddle_rect, p2_paddle_dy);

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
                scores.p1 += 1;
                std.log.info(
                    "P2 scored. P1 score: {}, P2 score: {}",
                    .{ scores.p1, scores.p2 },
                );
            } else if (ball_rect.x <= 0) {
                ball_dx = @abs(ball_dx);
                scores.p2 += 1;
                std.log.info(
                    "P1 scored. P1 score: {}, P2 score: {}",
                    .{ scores.p1, scores.p2 },
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

        object_positions = .{
            .p1_paddle_position = objectRectToPosition(p1_paddle_rect),
            .p2_paddle_position = objectRectToPosition(p2_paddle_rect),
            .ball_position = objectRectToPosition(ball_rect),
        };
        try writer.writeStruct(object_positions, .big);
        try writer.flush();

        const time_now: Io.Timestamp = .now(io, clock);
        const frame_duration = frame_start.durationTo(time_now);
        const ns_to_wait: i96 = @max(
            0,
            ns_between_frames - frame_duration.nanoseconds,
        );
        const duration_to_wait: Io.Duration = .{ .nanoseconds = ns_to_wait };
        try Io.sleep(io, duration_to_wait, clock);
        frame_start = time_now;

        try drawObjects(renderer, &game_state);
    }
}

fn runClient(io: Io, renderer_ptr: *?*sdl.SDL_Renderer, config: Config) !void {
    const renderer = renderer_ptr.*;

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

    // var a_future = io.async(getState2, .{ reader, .big });
    // defer _ = a_future.cancel(io) catch {};
    while (true) {
        var event: sdl.SDL_Event = undefined;
        _ = sdl.SDL_PollEvent(&event);

        if (event.type == sdl.SDL_EVENT_QUIT) {
            std.process.cleanExit(io);
            return;
        }

        const move = getPlayerMove(.player_2);
        const move_int = @intFromEnum(move);
        try writer.writeInt(@TypeOf(move_int), move_int, .big);
        try writer.flush();

        const object_positions: ObjectPositions = try reader.takeStruct(ObjectPositions, .big);

        var p1_paddle_rect = paddlePositionToRect(object_positions.p1_paddle_position);
        var p2_paddle_rect = paddlePositionToRect(object_positions.p2_paddle_position);
        var ball_rect = ballPositionToRect(object_positions.ball_position);
        const game_state: ObjectRectangles = .{
            .p1_paddle = &p1_paddle_rect,
            .p2_paddle = &p2_paddle_rect,
            .ball = &ball_rect,
        };
        try drawObjects(renderer, &game_state);
    }
}

fn getServer(io: Io, config: Config, server: *std.Io.net.Server) !void {
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

    std.log.info(
        "Server waiting for connection on {f}, port {}",
        .{ address.ip4, address.getPort() },
    );

    server.* = try Io.net.IpAddress.listen(
        &address,
        io,
        connect_options,
    );
}

fn getState(io: Io, stream: net.Stream, endian: std.lang.Endian) !ObjectRectangles {
    var read_buffer: [1024]u8 = undefined;
    var stream_reader = stream.reader(io, &read_buffer);
    const reader: *Io.Reader = &stream_reader.interface;
    return try reader.takeStruct(ObjectRectangles, endian);
}

fn getState2(reader: *Io.Reader, endian: std.lang.Endian) !ObjectRectangles {
    return try reader.takeStruct(ObjectRectangles, endian);
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

fn updatePaddle(
    paddle: *FRect,
    paddle_dy: f32,
) void {
    // update y position, limit to screen border
    const next_paddle_y = paddle.y + paddle_dy * window_height_logical;
    const paddle_y_limit = window_height_logical - paddle_height;
    paddle.y = @max(@min(next_paddle_y, paddle_y_limit), 0.0);
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

fn objectRectToPosition(object_rect: FRect) ObjectPosition {
    return .{
        .x = object_rect.x,
        .y = object_rect.y,
    };
}

fn paddlePositionToRect(paddle_position: ObjectPosition) FRect {
    return .{
        .x = paddle_position.x,
        .y = paddle_position.y,
        .h = paddle_height,
        .w = paddle_width,
    };
}

fn ballPositionToRect(ball_position: ObjectPosition) FRect {
    return .{
        .x = ball_position.x,
        .y = ball_position.y,
        .h = ball_width,
        .w = ball_width,
    };
}
