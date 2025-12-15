// modules/core/src/logger.zig

const std = @import("std");

pub const LogLevel = enum(u8) {
    debug = 0,
    info = 1,
    warn = 2,
    err = 3,

    pub fn toString(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
        };
    }
};

pub const Logger = struct {
    level: LogLevel,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, level: LogLevel) Logger {
        return .{
            .level = level,
            .allocator = allocator,
        };
    }

    pub fn log(self: Logger, level: LogLevel, comptime fmt: []const u8, args: anytype) !void {
        if (@intFromEnum(level) >= @intFromEnum(self.level)) {
            const stderr = std.io.getStdErr().writer();

            const timestamp = std.time.timestamp();
            const level_str = level.toString();

            try stderr.print("[{d}] [{s}] ", .{ timestamp, level_str });
            try stderr.print(fmt, args);
            try stderr.writeAll("\n");
        }
    }

    pub fn debug(self: Logger, comptime fmt: []const u8, args: anytype) !void {
        try self.log(.debug, fmt, args);
    }

    pub fn info(self: Logger, comptime fmt: []const u8, args: anytype) !void {
        try self.log(.info, fmt, args);
    }

    pub fn warn(self: Logger, comptime fmt: []const u8, args: anytype) !void {
        try self.log(.warn, fmt, args);
    }

    pub fn err(self: Logger, comptime fmt: []const u8, args: anytype) !void {
        try self.log(.err, fmt, args);
    }
};

test "logger creation" {
    const logger = Logger.init(std.testing.allocator, .info);
    try std.testing.expectEqual(LogLevel.info, logger.level);
}
