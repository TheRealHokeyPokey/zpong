const std = @import("std");
const Io = std.Io;

const pi = std.math.pi;
const clock = Io.Clock.real;

const sdl = @import("main.zig").sdl;

const game = @import("game.zig");
const ObjectRectangles = game.ObjectRectangles;
const ObjectPosition = game.ObjectPosition;
// const ObjectPositions = game.ObjectPositions;

const zpong = @import("zpong");
const convertSDLError = zpong.convertSDLError;

const FRect = sdl.SDL_FRect;
const Renderer = sdl.SDL_Renderer;
const SetRenderDrawColorFloat = sdl.SDL_SetRenderDrawColorFloat;
const RenderFillRect = sdl.SDL_RenderFillRect;
const GetError = sdl.SDL_GetError;

const speed: f32 = 0.007;
const width: f32 = 0.045;

const window_height_logical = game.window_height_logical;
const window_width_logical = game.window_width_logical;

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

pub fn drawObjects(
    renderer: ?*sdl.SDL_Renderer,
    game_state: *const ObjectRectangles,
) !void {
    const p1_paddle_rect = game_state.p1_paddle;
    const p2_paddle_rect = game_state.p2_paddle;
    const ball_rect = game_state.ball;

    // clear screen and draw background
    try drawBackground(renderer);

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

fn drawBackground(renderer: ?*Renderer) !void {
    try setRenderColor(renderer, .black);
    if (!sdl.SDL_RenderClear(renderer)) {
        return convertSDLError(GetError());
    }
    const window_width_f32: f32 = @floatFromInt(window_width_logical);
    const window_height_f32: f32 = @floatFromInt(window_width_logical);
    const background_rectangle: FRect = .{
        .w = window_width_f32,
        .h = window_height_f32,
        .x = 0.0,
        .y = 0.0,
    };
    try drawColorRectangle(renderer, @constCast(&background_rectangle), .white);
    const center_line_width = window_width_f32 / 80.0;
    const center_line_rect: FRect = .{
        .w = center_line_width,
        .h = window_height_f32,
        .x = (window_width_f32 - center_line_width) / 2.0,
        .y = 0.0,
    };
    try drawColorRectangle(renderer, @constCast(&center_line_rect), .black);
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
