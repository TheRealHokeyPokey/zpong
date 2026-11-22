const std = @import("std");
const Io = std.Io;
// const sdl = @import("sdl3");

const zpong = @import("zpong");

pub const sdl = @import("sdl3");
//
const game = @import("game.zig");
// const game = @import("game.zig");

const pi = std.math.pi;
const clock = Io.Clock.real;

const speed: f32 = 0.007;
const width: f32 = 0.045;

pub fn main(init: std.process.Init) !void {

    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    const io = init.io;

    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    const is_host = if (std.mem.eql(u8, args[1], "host")) true else false;
    std.log.info("isHost: {}", .{is_host});

    try game.runGameLoop(io);

    // if (std.mem.eql([]const u8, args[1], "server")) {
    //     try std.log.info("Running server\n", .{});
    // } else {}

    // var stdout_buffer: [1024]u8 = undefined;
    // var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    // const stdout_writer = &stdout_file_writer.interface;

    // try zpong.network.printHello(stdout_writer);
    // try zpong.network.socketTest(io, stdout_writer);
    // try zpong.network.socketTestTwo(io, stdout_writer);

    // _ = sdl.SDL_SetAppMetadata(
    //     "Example Renderer Clear",
    //     "1.0",
    //     "com.example.renderer-clear",
    // );
    //
    // if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
    //     std.debug.panic("SDL_Init failed: {s}\n", .{sdl.SDL_GetError()});
    //     return sdl.SDL_APP_FAILURE;
    // }
    // defer sdl.SDL_Quit();
    //
    // std.debug.print(
    //     "video driver: {s}\n",
    //     .{sdl.SDL_GetCurrentVideoDriver() orelse @as([*c]const u8, "null")},
    // );
    //
    // var window: ?*sdl.SDL_Window = null;
    // var renderer: ?*sdl.SDL_Renderer = null;
    //
    // const initial_window_width = 640;
    //
    // if (!sdl.SDL_CreateWindowAndRenderer(
    //     "examples/renderer/clear",
    //     initial_window_width,
    //     480,
    //     sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_HIGH_PIXEL_DENSITY,
    //     &window,
    //     &renderer,
    // )) {
    //     std.debug.panic(
    //         "Couldn't create window/renderer: {s}\n",
    //         .{sdl.SDL_GetError()},
    //     );
    // }
    // defer sdl.SDL_DestroyWindow(window);
    // defer sdl.SDL_DestroyRenderer(renderer);
    //
    // var p1_paddle: sdl.SDL_FRect = .{ .x = 0.0, .y = 0.0, .h = 300.0, .w = 50.0 };
    // const p1_paddle_dx: f32 = 0.0;
    // var p1_paddle_dy: f32 = 0.0;
    //
    // var p2_paddle: sdl.SDL_FRect = .{ .x = 0.0, .y = 0.0, .h = 300.0, .w = 50.0 };
    // var p2_paddle_dy: f32 = 0.0;
    //
    // var ball: sdl.SDL_FRect = .{ .x = 0.0, .y = 0.0, .h = 50.0, .w = 50.0 };
    // var ball_dx: f32 = speed;
    // var ball_dy: f32 = speed;
    //
    // var window_width: c_int = undefined;
    // var window_height: c_int = undefined;
    //
    // const ns_between_frames = std.time.ns_per_s / 60;
    // var frame_start: Io.Timestamp = std.Io.Clock.now(.real, io);
    //
    // var p1_score: u16 = 0;
    // var p2_score: u16 = 0;
    //
    // while (true) {
    //     var event: sdl.SDL_Event = undefined;
    //     _ = sdl.SDL_PollEvent(&event);
    //
    //     if (event.type == sdl.SDL_EVENT_QUIT) {
    //         std.process.cleanExit(io);
    //         return;
    //     }
    //
    //     p1_paddle_dy = 0.0;
    //     p2_paddle_dy = 0.0;
    //
    //     const key_states: [*]const bool = sdl.SDL_GetKeyboardState(null);
    //     if (key_states[sdl.SDL_SCANCODE_W]) {
    //         p1_paddle_dy = -speed;
    //     } else if (key_states[sdl.SDL_SCANCODE_S]) {
    //         p1_paddle_dy = speed;
    //     }
    //     if (key_states[sdl.SDL_SCANCODE_UP]) {
    //         p2_paddle_dy = -speed;
    //     } else if (key_states[sdl.SDL_SCANCODE_DOWN]) {
    //         p2_paddle_dy = speed;
    //     }
    //
    //     if (!sdl.SDL_GetWindowSizeInPixels(window, &window_width, &window_height)) {
    //         std.debug.panic("{s}", .{sdl.SDL_GetError()});
    //     }
    //
    //     const window_width_f32: f32 = @floatFromInt(window_width);
    //     const window_height_f32: f32 = @floatFromInt(window_height);
    //
    //     ball.w = width * window_height_f32;
    //     ball.h = ball.w;
    //
    //     p1_paddle.w = width * window_height_f32;
    //     p1_paddle.h = 6 * width * window_height_f32;
    //
    //     p1_paddle.x += p1_paddle_dx * window_height_f32;
    //     const next_p1_paddle_y = p1_paddle.y + (p1_paddle_dy * window_height_f32);
    //     const p1_paddle_y_limit = window_height_f32 - p1_paddle.h;
    //     p1_paddle.y = @max(@min(next_p1_paddle_y, p1_paddle_y_limit), 0.0);
    //
    //     p2_paddle.w = width * window_height_f32;
    //     p2_paddle.h = 6 * width * window_height_f32;
    //
    //     p2_paddle.x = window_width_f32 - p2_paddle.w;
    //     const next_p2_paddle_y = p2_paddle.y + (p2_paddle_dy * window_height_f32);
    //     const p2_paddle_y_limit = window_height_f32 - p2_paddle.h;
    //     p2_paddle.y = @max(@min(next_p2_paddle_y, p2_paddle_y_limit), 0.0);
    //
    //     if (sdl.SDL_HasRectIntersectionFloat(
    //         @ptrCast(&ball),
    //         @ptrCast(&p1_paddle),
    //     )) {
    //         ball_dx = speed;
    //     } else if (sdl.SDL_HasRectIntersectionFloat(
    //         @ptrCast(&ball),
    //         @ptrCast(&p2_paddle),
    //     )) {
    //         ball_dx = -speed;
    //     } else {
    //         if (ball.x + ball.w > window_width_f32) {
    //             ball_dx = -@abs(ball_dx);
    //             p1_score += 1;
    //             std.log.info("P2 scored. P1 score: {}, P2 score: {}", .{ p1_score, p2_score });
    //         } else if (ball.x <= 0) {
    //             ball_dx = @abs(ball_dx);
    //             p2_score += 1;
    //             std.log.info("P1 scored. P1 score: {}, P2 score: {}", .{ p1_score, p2_score });
    //         }
    //     }
    //     if (ball.y + ball.h > window_height_f32) {
    //         ball_dy = -@abs(ball_dy);
    //     } else if (ball.y <= 0) {
    //         ball_dy = @abs(ball_dy);
    //     }
    //
    //     ball.x += ball_dx * window_height_f32;
    //     ball.y += ball_dy * window_height_f32;
    //
    //     if (!sdl.SDL_SetRenderDrawColorFloat(renderer, 0.0, 0.0, 0.0, 1.0)) {
    //         std.debug.panic("{s}", .{sdl.SDL_GetError()});
    //     }
    //     if (!sdl.SDL_RenderClear(renderer)) {
    //         std.debug.panic("{s}", .{sdl.SDL_GetError()});
    //     }
    //
    //     // render p1 paddle
    //     if (!sdl.SDL_SetRenderDrawColorFloat(renderer, 1.0, 0.0, 0.0, 1.0)) {
    //         std.debug.panic("{s}", .{sdl.SDL_GetError()});
    //     }
    //     if (!sdl.SDL_RenderFillRect(
    //         renderer,
    //         @ptrCast(&p1_paddle),
    //     )) {
    //         std.debug.panic("{s}", .{sdl.SDL_GetError()});
    //     }
    //
    //     // render p2 paddle
    //     if (!sdl.SDL_SetRenderDrawColorFloat(renderer, 0.0, 1.0, 0.0, 1.0)) {
    //         std.debug.panic("{s}", .{sdl.SDL_GetError()});
    //     }
    //     if (!sdl.SDL_RenderFillRect(
    //         renderer,
    //         @ptrCast(&p2_paddle),
    //     )) {
    //         std.debug.panic("{s}", .{sdl.SDL_GetError()});
    //     }
    //
    //     // render ball
    //     if (!sdl.SDL_SetRenderDrawColorFloat(renderer, 245.0 / 255.0, 99.0 / 255.0, 184.0 / 255.0, 1.0)) {
    //         std.debug.panic("{s}", .{sdl.SDL_GetError()});
    //     }
    //     if (!sdl.SDL_RenderFillRect(
    //         renderer,
    //         @ptrCast(&ball),
    //     )) {
    //         std.debug.panic("{s}", .{sdl.SDL_GetError()});
    //     }
    //     const time_now: Io.Timestamp = .now(io, clock);
    //     const frame_duration = frame_start.durationTo(time_now);
    //     const ns_to_wait: i96 = @max(0, ns_between_frames - frame_duration.nanoseconds);
    //     const duration_to_wait: Io.Duration = .{ .nanoseconds = ns_to_wait };
    //     try Io.sleep(io, duration_to_wait, clock);
    //     frame_start = time_now;
    //
    //     if (!sdl.SDL_RenderPresent(renderer)) {
    //         std.debug.panic("{s}", .{sdl.SDL_GetError()});
    //     }
    // }
}
