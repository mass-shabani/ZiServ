// ============================================================
// فایل: modules/foundation/ziserv-core/src/logger.zig
// سیستم Logger حرفه‌ای با performance بالا
// اصلاح شده نهایی: رفع بستن stdout در ConsoleSink
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

/// Console Sink (stdout/stderr) - اصلاح شده: نباید stdout را ببندیم
pub const ConsoleSink = struct {
    file: std.fs.File,
    config: LoggerConfig,
    mutex: std.Thread.Mutex,
    buffer: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: LoggerConfig, file: std.fs.File) ConsoleSink {
        return .{
            .file = file,
            .config = config,
            .mutex = .{},
            .buffer = std.ArrayList(u8){},
            .allocator = allocator,
        };
    }

    pub fn write(self: *ConsoleSink, entry: LogEntry) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.buffer.clearRetainingCapacity();
        const writer = self.buffer.writer(self.allocator);

        switch (self.config.format) {
            .text => try self.writeText(entry, writer),
            .json => try self.writeJson(entry, writer),
            .colored => try self.writeColored(entry, writer),
        }

        try self.file.writeAll(self.buffer.items);
    }

    fn writeText(self: *ConsoleSink, entry: LogEntry, writer: anytype) !void {
        if (self.config.show_timestamp) {
            const ms = @divTrunc(entry.timestamp, 1_000_000);
            try writer.print("[{d}] ", .{ms});
        }

        try writer.print("[{s}] ", .{entry.level.toString()});

        if (self.config.show_source and entry.source != null) {
            const src = entry.source.?;
            try writer.print("{s}:{}:{} ", .{ std.fs.path.basename(src.file), src.line, src.column });
        }

        if (self.config.show_thread_id and entry.thread_id != null) {
            try writer.print("[T:{}] ", .{entry.thread_id.?});
        }

        try writer.print("{s}\n", .{entry.message});
    }

    fn writeJson(self: *ConsoleSink, entry: LogEntry, writer: anytype) !void {
        try writer.writeAll("{");

        var needs_comma = false;

        if (self.config.show_timestamp) {
            try writer.print("\"timestamp\":{d}", .{entry.timestamp});
            needs_comma = true;
        }

        try writer.print("{s}\"level\":\"{s}\"", .{ if (needs_comma) "," else "", entry.level.toString() });
        needs_comma = true;

        if (self.config.show_source and entry.source != null) {
            const src = entry.source.?;
            try writer.print(",\"file\":\"{s}\"", .{std.fs.path.basename(src.file)});
            try writer.print(",\"line\":{d}", .{src.line});
            try writer.print(",\"column\":{d}", .{src.column});
        }

        if (self.config.show_thread_id and entry.thread_id != null) {
            try writer.print(",\"thread\":{d}", .{entry.thread_id.?});
        }

        try writer.print(",\"message\":\"{s}\"", .{entry.message});
        try writer.writeAll("}\n");
    }

    fn writeColored(self: *ConsoleSink, entry: LogEntry, writer: anytype) !void {
        const color = entry.level.color();
        const reset = "\x1b[0m";

        if (self.config.show_timestamp) {
            const ms = @divTrunc(entry.timestamp, 1_000_000);
            try writer.print("\x1b[90m[{d}]\x1b[0m ", .{ms});
        }

        try writer.print("{s}[{s}]{s} ", .{ color, entry.level.toString(), reset });

        if (self.config.show_source and entry.source != null) {
            const src = entry.source.?;
            try writer.print("\x1b[90m{s}:{}:{}\x1b[0m ", .{ std.fs.path.basename(src.file), src.line, src.column });
        }

        try writer.print("{s}\n", .{entry.message});
    }

    pub fn flush(self: *ConsoleSink) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.file.sync();
    }

    pub fn deinit(self: *ConsoleSink) void {
        // اصلاح شد: self.file.close() حذف شد.
        // ما نباید stdout/stderr را ببندیم چون باعث خطا در ویندوز می‌شود
        // و همچنین کتابخانه استاندارد ممکن است بعدا به آن‌ها نیاز داشته باشد.
        self.buffer.deinit(self.allocator);
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

/// File Sink (لاگ به فایل) - اصلاح شده برای یکسان‌سازی نام‌ها
pub const FileSink = struct {
    file: std.fs.File,
    config: LoggerConfig,
    mutex: std.Thread.Mutex,
    buffer: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, path: []const u8, config: LoggerConfig) !FileSink {
        const file = try std.fs.cwd().createFile(path, .{ .truncate = false });
        try file.seekFromEnd(0); // append mode

        return .{
            .file = file,
            .config = config,
            .mutex = .{},
            .buffer = std.ArrayList(u8){},
            .allocator = allocator,
        };
    }

    pub fn write(self: *FileSink, entry: LogEntry) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.buffer.clearRetainingCapacity();
        const writer = self.buffer.writer(self.allocator);

        if (self.config.show_timestamp) {
            const ms = @divTrunc(entry.timestamp, 1_000_000);
            try writer.print("[{d}] [{s}] ", .{ ms, entry.level.toString() });
        } else {
            try writer.print("[{s}] ", .{entry.level.toString()});
        }

        if (self.config.show_source) {
            if (entry.source) |s| {
                try writer.print("{s}:{}:{} ", .{ std.fs.path.basename(s.file), s.line, s.column });
            }
        }

        try writer.print("{s}\n", .{entry.message});

        _ = try self.file.write(self.buffer.items);
    }

    pub fn flush(self: *FileSink) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.file.sync();
    }

    pub fn deinit(self: *FileSink) void {
        self.file.close();
        self.buffer.deinit(self.allocator);
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
            .sinks = std.ArrayList(Sink){},
            .allocator = allocator,
            .buffer = std.ArrayList(u8){},
            .mutex = .{},
        };
    }

    pub fn deinit(self: *Logger) void {
        for (self.sinks.items) |s| {
            s.deinit();
        }
        self.sinks.deinit(self.allocator);
        self.buffer.deinit(self.allocator);
    }

    pub fn addSink(self: *Logger, sink: Sink) !void {
        try self.sinks.append(self.allocator, sink);
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
        const writer = self.buffer.writer(self.allocator);
        std.fmt.format(writer, fmt, args) catch return;

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

// --- Tests ---

test "logger basic" {
    var logger = Logger.init(std.testing.allocator, .{
        .level = .debug,
        .format = .text,
    });
    defer logger.deinit();

    var console = ConsoleSink.init(std.testing.allocator, .{}, std.fs.File.stdout());
    try logger.addSink(console.sink());

    logger.info("Test message: {s}", .{"Hello"});
    logger.warn("Warning: {d}", .{42});
}

test "logger levels" {
    var logger = Logger.init(std.testing.allocator, .{
        .level = .warn,
    });
    defer logger.deinit();

    var console = ConsoleSink.init(std.testing.allocator, .{}, std.fs.File.stdout());
    try logger.addSink(console.sink());

    logger.debug("This should not appear", .{});
    logger.warn("This should appear", .{});
    logger.err("This should also appear", .{});
}
