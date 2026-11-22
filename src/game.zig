const std = @import("std");
const Io = std.Io;

const pi = std.math.pi;
const clock = Io.Clock.real;

const sdl = @import("main.zig").sdl;

const zpong = @import("zpong");
const convertSDLError = zpong.convertSDLError;

const FRect = sdl.SDL_FRect;
const Renderer = sdl.SDL_Renderer;
const SetRenderDrawColorFloat = sdl.SDL_SetRenderDrawColorFloat;
const RenderFillRect = sdl.SDL_RenderFillRect;
const GetError = sdl.SDL_GetError;

const speed: f32 = 0.007;
const width: f32 = 0.045;

const Color = enum {
    red,
    green,
    blue,
    yellow,
    purple,
    orange,
    white,
    black,
};

const ObjectPosition = struct {
    x: f32,
    y: f32,
};

const ObjectRectangles = struct {
    p1_paddle_rect: *FRect,
    p2_paddle_rect: *FRect,
    ball_rect: *FRect,
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

    const initial_window_width = 640;

    if (!sdl.SDL_CreateWindowAndRenderer(
        "examples/renderer/clear",
        initial_window_width,
        480,
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

    var window_width_c_int: c_int = undefined;
    var window_height_c_int: c_int = undefined;

    const ns_between_frames = std.time.ns_per_s / 60;
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

        if (!sdl.SDL_GetWindowSizeInPixels(window, &window_width_c_int, &window_height_c_int)) {
            std.debug.panic("{s}", .{sdl.SDL_GetError()});
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

        const time_now: Io.Timestamp = .now(io, clock);
        const frame_duration = frame_start.durationTo(time_now);
        const ns_to_wait: i96 = @max(0, ns_between_frames - frame_duration.nanoseconds);
        const duration_to_wait: Io.Duration = .{ .nanoseconds = ns_to_wait };
        try Io.sleep(io, duration_to_wait, clock);
        frame_start = time_now;

        try draw_objects(renderer, &object_rectangles);
    }
}

fn draw_objects(renderer: ?*sdl.SDL_Renderer, object_rectangles: *const ObjectRectangles) !void {
    const p1_paddle_rect = object_rectangles.p1_paddle_rect;
    const p2_paddle_rect = object_rectangles.p2_paddle_rect;
    const ball_rect = object_rectangles.ball_rect;

    // clear screen
    try setRenderColor(renderer, .black);
    if (!sdl.SDL_RenderClear(renderer)) {
        return convertSDLError(GetError());
    }

    // draw objects
    try drawColorRectangle(renderer, p1_paddle_rect, .green);
    try drawColorRectangle(renderer, p2_paddle_rect, .blue);
    try drawColorRectangle(renderer, ball_rect, .orange);

    if (!sdl.SDL_RenderPresent(renderer)) {
        return convertSDLError(GetError());
    }
}

fn drawColorRectangle(renderer: ?*Renderer, rectangle: *FRect, color: Color) !void {
    try setRenderColor(renderer, color);
    try drawRectangle(renderer, rectangle);
}

fn drawRectangle(renderer: ?*Renderer, rectangle: *FRect) !void {
    if (!RenderFillRect(
        renderer,
        @ptrCast(rectangle),
    )) {
        return convertSDLError(GetError());
    }
}

fn setRenderColor(renderer: ?*Renderer, color: Color) !void {
    switch (color) {
        .black => try setRenderColorFloat(renderer, 0.0, 0.0, 0.0, 1.0),
        .blue => try setRenderColorFloat(renderer, 0.0, 0.0, 1.0, 1.0),
        .green => try setRenderColorFloat(renderer, 0.0, 1.0, 0.0, 1.0),
        .orange => try setRenderColorFloat(renderer, 1.0, 0.5, 0.0, 1.0),
        .purple => try setRenderColorFloat(renderer, 0.5, 0.0, 0.5, 1.0),
        .red => try setRenderColorFloat(renderer, 1.0, 0.0, 0.0, 1.0),
        .white => try setRenderColorFloat(renderer, 1.0, 1.0, 1.0, 1.0),
        .yellow => try setRenderColorFloat(renderer, 1.0, 1.0, 0.0, 1.0),
    }
}

fn setRenderColorFloat(renderer: ?*Renderer, r: f32, g: f32, b: f32, a: f32) !void {
    if (!SetRenderDrawColorFloat(renderer, r, g, b, a)) {
        return convertSDLError(GetError());
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

fn fillPaddleRect(
    paddle_pos: ObjectPosition,
    window_height: f32,
    paddle_rect: *FRect,
) void {
    const paddle_x = paddle_pos.x;
    const paddle_y = paddle_pos.y;
    const paddle_width = width * window_height;
    const paddle_height = 6 * width * window_height;

    paddle_rect.* = FRect{
        .x = paddle_x,
        .y = paddle_y,
        .w = paddle_width,
        .h = paddle_height,
    };
}
