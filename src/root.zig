//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const mem = std.mem;
const Io = std.Io;

pub const SDLError = error{ UnknownError, RenderError };

pub fn convertSDLError(sdl_error: [*:0]const u8) SDLError!void {
    std.log.info("Unknown error encountered: {s}", .{sdl_error});
    return SDLError.UnknownError;
}
