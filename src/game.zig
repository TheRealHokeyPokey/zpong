const std = @import("std");
const Io = std.Io;
const net = Io.net;

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

const window_width_c_int = 1920;
const window_height_c_int = 1080;

const ns_between_frames = std.time.ns_per_s / 60;

const Player = enum {
    player_1,
    player_2,
};

const Move = enum {
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

// pub const GameState = struct {
//     p1_paddle: FRect,
//     p2_paddle: FRect,
//     ball: FRect,
// };

const GameState = extern struct {
    p1_paddle: FRect,
    p2_paddle: FRect,
    ball: FRect,
};

pub fn runGameLoop(io: Io) !void {
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

    // const initial_window_width = 640;

    if (!sdl.SDL_CreateWindowAndRenderer(
        "examples/renderer/clear",
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

    // var window_width_c_int: c_int = undefined;
    // var window_height_c_int: c_int = undefined;

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

        // if (!sdl.SDL_GetWindowSizeInPixels(window, &window_width_c_int, &window_height_c_int)) {
        //     std.debug.panic("{s}", .{sdl.SDL_GetError()});
        // }

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
        } else if (ball_rect.y <= 0) {
            ball_dy = @abs(ball_dy);
        }

        ball_rect.x += ball_dx * window_height;
        ball_rect.y += ball_dy * window_height;

        const time_now: Io.Timestamp = .now(io, clock);
        const frame_duration = frame_start.durationTo(time_now);
        const ns_to_wait: i96 = @max(0, ns_between_frames - frame_duration.nanoseconds);
        const duration_to_wait: Io.Duration = .{ .nanoseconds = ns_to_wait };
        try Io.sleep(io, duration_to_wait, clock);
        frame_start = time_now;

        try drawObjects(renderer, &object_rectangles);
    }
}

pub fn runBasicHostLoop(io: Io) !void {
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

    // const initial_window_width = 640;

    if (!sdl.SDL_CreateWindowAndRenderer(
        "examples/renderer/clear",
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

    var p1_paddle_dy: f32 = 0.0;

    var p2_paddle_dy: f32 = 0.0;

    var ball_dx: f32 = speed;
    var ball_dy: f32 = speed;

    // var window_width_c_int: c_int = undefined;
    // var window_height_c_int: c_int = undefined;

    var frame_start: Io.Timestamp = std.Io.Clock.now(.real, io);

    var p1_score: u16 = 0;
    var p2_score: u16 = 0;

    // const address = try Io.net.IpAddress.parseIp4("127.0.0.1", 55555);
    const address = try Io.net.IpAddress.parseIp4("0.0.0.0", 55555);
    const address_ptr = &address;
    const connect_options: Io.net.IpAddress.ListenOptions = .{};

    std.log.info(
        "Server waiting for connection on {f}, port {}",
        .{ address.ip4, address.getPort() },
    );

    var server: Io.net.Server = try Io.net.IpAddress.listen(
        address_ptr,
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
    _ = reader;

    // // read message from client
    // const message = try reader.takeDelimiterInclusive('\n');
    // std.log.info("Message read: {s}", .{message});
    // std.log.info("Writing response", .{});
    //
    // try writer.print("This is Server. Client, do you copy?\n", .{});
    // try writer.flush();

    while (true) {
        var event: sdl.SDL_Event = undefined;
        _ = sdl.SDL_PollEvent(&event);

        if (event.type == sdl.SDL_EVENT_QUIT) {
            std.process.cleanExit(io);
            return;
        }

        p1_paddle_dy = 0.0;
        p2_paddle_dy = 0.0;

        const key_states: [*]const bool = sdl.SDL_GetKeyboardState(null);
        if (key_states[sdl.SDL_SCANCODE_W]) {
            p1_paddle_dy = -speed;
        } else if (key_states[sdl.SDL_SCANCODE_S]) {
            p1_paddle_dy = speed;
        }
        if (key_states[sdl.SDL_SCANCODE_UP]) {
            p2_paddle_dy = -speed;
        } else if (key_states[sdl.SDL_SCANCODE_DOWN]) {
            p2_paddle_dy = speed;
        }

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
        } else if (ball_rect.y <= 0) {
            ball_dy = @abs(ball_dy);
        }

        ball_rect.x += ball_dx * window_height;
        ball_rect.y += ball_dy * window_height;

        // const state: GameState = .{
        //     .p1_paddle = @bitCast(p1_paddle_rect.*),
        //     .p2_paddle = @bitCast(p2_paddle_rect.*),
        //     .ball = @bitCast(ball_rect.*),
        // };
        // const p1_paddle_rect_copy = p1_paddle_rect.*;
        // const p2_paddle_rect_copy = p2_paddle_rect.*;
        // const ball_rect_copy = ball_rect.*;
        const game_state: GameState = .{ .p1_paddle = p1_paddle_rect, .p2_paddle = p2_paddle_rect, .ball = ball_rect };
        // const s = extern struct { p1_paddle: p1_paddle_rect_copy, p2_paddle: p2_paddle_rect_copy, ball: ball_rect_copy };
        try writer.writeStruct(game_state, .big);
        try writer.flush();

        const time_now: Io.Timestamp = .now(io, clock);
        const frame_duration = frame_start.durationTo(time_now);
        const ns_to_wait: i96 = @max(0, ns_between_frames - frame_duration.nanoseconds);
        const duration_to_wait: Io.Duration = .{ .nanoseconds = ns_to_wait };
        try Io.sleep(io, duration_to_wait, clock);
        frame_start = time_now;

        try drawObjects(renderer, &object_rectangles);
    }
}

pub fn runClientLoop(io: Io) !void {
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
        "examples/renderer/clear",
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

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_file_reader: Io.File.Reader = .init(.stdout(), io, &stdin_buffer);
    const stdin = &stdin_file_reader.interface;

    try stdout.print("Please enter host IPv4 address like \"address:port\": ", .{});
    try stdout.flush();
    const address_literal = try stdin.takeDelimiterExclusive('\n');
    const address: net.IpAddress = try .parseLiteral(address_literal);

    if (address.getPort() != 55555) {
        @panic("Wrong port");
    }

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
    _ = writer;

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
    while (true) {
        var frame_start: Io.Timestamp = std.Io.Clock.now(.real, io);

        // const p1_paddle_rect_copy = p1_paddle_rect.*;
        // const p2_paddle_rect_copy = p2_paddle_rect.*;
        // const ball_rect_copy = ball_rect.*;
        // const s = extern struct { p1_paddle: p1_paddle_rect_copy, p2_paddle: p2_paddle_rect_copy, ball: ball_rect_copy };
        // try writer.writeStruct(s, .big);

        const game_state: GameState = try reader.takeStruct(GameState, .big);
        // const takeStruct = reader.takeStruct();

        // var get_state = try io.async(reader.takeStruct, .{ GameState, .big });
        // defer get_state.cancel(io) catch {};
        // const game_state = try get_state.await(io);

        object_rectangles.p1_paddle_rect.* = game_state.p1_paddle;
        object_rectangles.p2_paddle_rect.* = game_state.p2_paddle;
        object_rectangles.ball_rect.* = game_state.ball;

        const time_now: Io.Timestamp = .now(io, clock);
        const frame_duration = frame_start.durationTo(time_now);
        const ns_to_wait: i96 = @max(0, ns_between_frames - frame_duration.nanoseconds);
        const duration_to_wait: Io.Duration = .{ .nanoseconds = ns_to_wait };
        try Io.sleep(io, duration_to_wait, clock);
        frame_start = time_now;

        try drawObjects(renderer, &object_rectangles);
    }
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
    if (move == .no_move) {
        return 0.0;
    }
    if (move == .up) {
        return -speed;
    }
    if (move == .down) {
        return speed;
    }
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
