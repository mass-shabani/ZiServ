// modules/core/src/platform.zig

const std = @import("std");
const builtin = @import("builtin");

pub const Os = enum {
    windows,
    linux,
    unsupported,

    pub fn current() Os {
        return switch (builtin.os.tag) {
            .windows => .windows,
            .linux => .linux,
            else => .unsupported,
        };
    }

    pub fn isSupported() bool {
        return current() != .unsupported;
    }

    pub fn name() []const u8 {
        return switch (current()) {
            .windows => "Windows",
            .linux => "Linux",
            .unsupported => "Unsupported",
        };
    }
};

pub fn getPathSeparator() u8 {
    return switch (Os.current()) {
        .windows => '\\',
        .linux => '/',
        .unsupported => '/',
    };
}

pub fn getNewline() []const u8 {
    return switch (Os.current()) {
        .windows => "\r\n",
        else => "\n",
    };
}

test "platform detection" {
    const os = Os.current();
    try std.testing.expect(os == .windows or os == .linux or os == .unsupported);
}
