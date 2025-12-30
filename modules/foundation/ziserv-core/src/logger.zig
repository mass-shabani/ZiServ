// ============================================================
// فایل: modules/foundation/ziserv-core/src/logger.zig
// سیستم Logger حرفه‌ای با performance بالا
// ============================================================

const std = @import("std");
const builtin = @import("builtin");

/// سطوح لاگ
pub const Level = enum(u8) {
    trace = 0,
    debug = 1,
    info = 2,
    warn = 3,
    err = 4,
    fatal = 5,
    none = 6,

    pub fn fromString(s: []const u8) ?Level {
        if (std.mem.eql(u8, s, "trace")) return .trace;
        if (std.mem.eql(u8, s, "debug")) return .debug;
        if (std.mem.eql(u8, s, "info")) return .info;
        if (std.mem.eql(u8, s, "warn")) return .warn;
        if (std.mem.eql(u8, s, "error")) return .err;
        if (std.mem.eql(u8, s, "fatal")) return .fatal;
        if (std.mem.eql(u8, s, "none")) return .none;
        return null;
    }

    pub fn toString(self: Level) []const u8 {
        return switch (self) {
            .trace => "TRACE",
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .fatal => "FATAL",
            .none => "NONE",
        };
    }

    pub fn color(self: Level) []const u8 {
        return switch (self) {
            .trace => "\x1b[36m", // Cyan
            .debug => "\x1b[34m", // Blue
            .info => "\x1b[32m", // Green
            .warn => "\x1b[33m", // Yellow
            .err => "\x1b[31m", // Red
            .fatal => "\x1b[35m", // Magenta
            .none => "",
        };
    }
};

/// فرمت خروجی لاگ
pub const Format = enum {
    text, // ساده
    json, // JSON format
    colored, // رنگی برای terminal

    pub fn fromString(s: []const u8) ?Format {
        if (std.mem.eql(u8, s, "text")) return .text;
        if (std.mem.eql(u8, s, "json")) return .json;
        if (std.mem.eql(u8, s, "colored")) return .colored;
        return null;
    }
};

/// تنظیمات Logger
pub const LoggerConfig = struct {
    level: Level = .info,
    format: Format = if (builtin.os.tag == .windows) .text else .colored,
    show_timestamp: bool = true,
    show_source: bool = true,
    show_thread_id: bool = false,
    buffer_size: usize = 4096,
};

/// Log Entry
pub const LogEntry = struct {
    level: Level,
    timestamp: i128,
    message: []const u8,
    source: ?std.builtin.SourceLocation,
    thread_id: ?std.Thread.Id,
};

/// Logger Sink interface
pub const Sink = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        write: *const fn (*anyopaque, LogEntry) anyerror!void,
        flush: *const fn (*anyopaque) anyerror!void,
        deinit: *const fn (*anyopaque) void,
    };

    pub fn write(self: Sink, entry: LogEntry) !void {
        return self.vtable.write(self.ptr, entry);
    }

    pub fn flush(self: Sink) !void {
        return self.vtable.flush(self.ptr);
    }

    pub fn deinit(self: Sink) void {
        self.vtable.deinit(self.ptr);
    }
};

/// Console Sink (stdout/stderr)
pub const ConsoleSink = struct {
    config: LoggerConfig,
    writer: std.fs.File.Writer,
    mutex: std.Thread.Mutex,

    pub fn init(config: LoggerConfig, file: std.fs.File) ConsoleSink {
        return .{
            .config = config,
            .writer = file.writer(),
            .mutex = .{},
        };
    }

    pub fn write(self: *ConsoleSink, entry: LogEntry) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        switch (self.config.format) {
            .text => try self.writeText(entry),
            .json => try self.writeJson(entry),
            .colored => try self.writeColored(entry),
        }
    }

    fn writeText(self: *ConsoleSink, entry: LogEntry) !void {
        const w = self.writer;

        if (self.config.show_timestamp) {
            const ms = @divTrunc(entry.timestamp, 1_000_000);
            try w.print("[{d}] ", .{ms});
        }

        try w.print("[{s}] ", .{entry.level.toString()});

        if (self.config.show_source and entry.source != null) {
            const src = entry.source.?;
            try w.print("{}:{}:{} ", .{ std.fs.path.basename(src.file), src.line, src.column });
        }

        if (self.config.show_thread_id and entry.thread_id != null) {
            try w.print("[T:{}] ", .{entry.thread_id.?});
        }

        try w.print("{s}\n", .{entry.message});
    }

    fn writeJson(self: *ConsoleSink, entry: LogEntry) !void {
        const w = self.writer;

        try w.writeAll("{");
        try w.print("\"timestamp\":{d},", .{entry.timestamp});
        try w.print("\"level\":\"{s}\",", .{entry.level.toString()});

        if (entry.source) |src| {
            try w.print("\"file\":\"{s}\",", .{std.fs.path.basename(src.file)});
            try w.print("\"line\":{d},", .{src.line});
        }

        if (entry.thread_id) |tid| {
            try w.print("\"thread\":{d},", .{tid});
        }

        try w.print("\"message\":\"{s}\"", .{entry.message});
        try w.writeAll("}\n");
    }

    fn writeColored(self: *ConsoleSink, entry: LogEntry) !void {
        const w = self.writer;
        const color = entry.level.color();
        const reset = "\x1b[0m";

        if (self.config.show_timestamp) {
            const ms = @divTrunc(entry.timestamp, 1_000_000);
            try w.print("\x1b[90m[{d}]\x1b[0m ", .{ms});
        }

        try w.print("{s}[{s}]{s} ", .{ color, entry.level.toString(), reset });

        if (self.config.show_source and entry.source != null) {
            const src = entry.source.?;
            try w.print("\x1b[90m{}:{}:{}\x1b[0m ", .{ std.fs.path.basename(src.file), src.line, src.column });
        }

        try w.print("{s}\n", .{entry.message});
    }

    pub fn flush(self: *ConsoleSink) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        // stdout/stderr auto-flush in most cases
    }

    pub fn deinit(self: *ConsoleSink) void {
        _ = self;
    }

    pub fn sink(self: *ConsoleSink) Sink {
        return .{
            .ptr = self,
            .vtable = &.{
                .write = struct {
                    fn write(ptr: *anyopaque, entry: LogEntry) !void {
                        const s: *ConsoleSink = @ptrCast(@alignCast(ptr));
                        try s.write(entry);
                    }
                }.write,
                .flush = struct {
                    fn flush(ptr: *anyopaque) !void {
                        const s: *ConsoleSink = @ptrCast(@alignCast(ptr));
                        try s.flush();
                    }
                }.flush,
                .deinit = struct {
                    fn deinit(ptr: *anyopaque) void {
                        const s: *ConsoleSink = @ptrCast(@alignCast(ptr));
                        s.deinit();
                    }
                }.deinit,
            },
        };
    }
};

/// File Sink (لاگ به فایل)
pub const FileSink = struct {
    file: std.fs.File,
    config: LoggerConfig,
    mutex: std.Thread.Mutex,
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, path: []const u8, config: LoggerConfig) !FileSink {
        const file = try std.fs.cwd().createFile(path, .{ .truncate = false });
        try file.seekFromEnd(0); // append mode

        return .{
            .file = file,
            .config = config,
            .mutex = .{},
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn write(self: *FileSink, entry: LogEntry) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.buffer.clearRetainingCapacity();
        const w = self.buffer.writer();

        const ms = @divTrunc(entry.timestamp, 1_000_000);
        try w.print("[{d}] [{s}] ", .{ ms, entry.level.toString() });

        if (entry.source) |src| {
            try w.print("{}:{}:{} ", .{ std.fs.path.basename(src.file), src.line, src.column });
        }

        try w.print("{s}\n", .{entry.message});

        _ = try self.file.write(self.buffer.items);
    }

    pub fn flush(self: *FileSink) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.file.sync();
    }

    pub fn deinit(self: *FileSink) void {
        self.file.close();
        self.buffer.deinit();
    }

    pub fn sink(self: *FileSink) Sink {
        return .{
            .ptr = self,
            .vtable = &.{
                .write = struct {
                    fn write(ptr: *anyopaque, entry: LogEntry) !void {
                        const s: *FileSink = @ptrCast(@alignCast(ptr));
                        try s.write(entry);
                    }
                }.write,
                .flush = struct {
                    fn flush(ptr: *anyopaque) !void {
                        const s: *FileSink = @ptrCast(@alignCast(ptr));
                        try s.flush();
                    }
                }.flush,
                .deinit = struct {
                    fn deinit(ptr: *anyopaque) void {
                        const s: *FileSink = @ptrCast(@alignCast(ptr));
                        s.deinit();
                    }
                }.deinit,
            },
        };
    }
};

/// Logger اصلی
pub const Logger = struct {
    config: LoggerConfig,
    sinks: std.ArrayList(Sink),
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8),
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, config: LoggerConfig) Logger {
        return .{
            .config = config,
            .sinks = std.ArrayList(Sink).init(allocator),
            .allocator = allocator,
            .buffer = std.ArrayList(u8).init(allocator),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *Logger) void {
        for (self.sinks.items) |s| {
            s.deinit();
        }
        self.sinks.deinit();
        self.buffer.deinit();
    }

    pub fn addSink(self: *Logger, sink: Sink) !void {
        try self.sinks.append(sink);
    }

    pub fn log(
        self: *Logger,
        comptime level: Level,
        comptime fmt: []const u8,
        args: anytype,
        src: std.builtin.SourceLocation,
    ) void {
        if (@intFromEnum(level) < @intFromEnum(self.config.level)) return;

        self.mutex.lock();
        defer self.mutex.unlock();

        self.buffer.clearRetainingCapacity();
        const w = self.buffer.writer();
        std.fmt.format(w, fmt, args) catch return;

        const entry = LogEntry{
            .level = level,
            .timestamp = std.time.nanoTimestamp(),
            .message = self.buffer.items,
            .source = if (self.config.show_source) src else null,
            .thread_id = if (self.config.show_thread_id) std.Thread.getCurrentId() else null,
        };

        for (self.sinks.items) |sink| {
            sink.write(entry) catch {};
        }
    }

    // Helper methods
    pub inline fn trace(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.trace, fmt, args, @src());
    }

    pub inline fn debug(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.debug, fmt, args, @src());
    }

    pub inline fn info(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.info, fmt, args, @src());
    }

    pub inline fn warn(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.warn, fmt, args, @src());
    }

    pub inline fn err(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.err, fmt, args, @src());
    }

    pub inline fn fatal(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.fatal, fmt, args, @src());
    }

    pub fn flush(self: *Logger) void {
        for (self.sinks.items) |sink| {
            sink.flush() catch {};
        }
    }
};

/// Global logger instance (optional)
var global_logger: ?*Logger = null;

pub fn setGlobalLogger(logger: *Logger) void {
    global_logger = logger;
}

pub fn getGlobalLogger() ?*Logger {
    return global_logger;
}

// Global logging functions
pub fn trace(comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |logger| logger.trace(fmt, args);
}

pub fn debug(comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |logger| logger.debug(fmt, args);
}

pub fn info(comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |logger| logger.info(fmt, args);
}

pub fn warn(comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |logger| logger.warn(fmt, args);
}

pub fn err(comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |logger| logger.err(fmt, args);
}

pub fn fatal(comptime fmt: []const u8, args: anytype) void {
    if (global_logger) |logger| logger.fatal(fmt, args);
}

test "logger basic" {
    var logger = Logger.init(std.testing.allocator, .{
        .level = .debug,
        .format = .text,
    });
    defer logger.deinit();

    var console = ConsoleSink.init(.{}, std.io.getStdOut());
    try logger.addSink(console.sink());

    logger.info("Test message: {s}", .{"Hello"});
    logger.warn("Warning: {d}", .{42});
}

test "logger levels" {
    var logger = Logger.init(std.testing.allocator, .{
        .level = .warn,
    });
    defer logger.deinit();

    var console = ConsoleSink.init(.{}, std.io.getStdOut());
    try logger.addSink(console.sink());

    logger.debug("This should not appear", .{});
    logger.warn("This should appear", .{});
    logger.err("This should also appear", .{});
}
