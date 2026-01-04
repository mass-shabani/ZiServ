// ============================================================
// فایل: src/context.zig
// Error Context - اطلاعات اضافی درباره خطا
// ============================================================

const std = @import("std");
const errors = @import("errors.zig");

/// Context برای خطا (اطلاعات اضافی)
pub const Context = struct {
    message: []const u8,
    file: []const u8,
    line: u32,
    column: u32,
    timestamp: i64,

    pub fn init(message: []const u8, src: std.builtin.SourceLocation) Context {
        return .{
            .message = message,
            .file = src.file,
            .line = src.line,
            .column = src.column,
            .timestamp = std.time.milliTimestamp(),
        };
    }

    pub fn initSimple(message: []const u8) Context {
        return .{
            .message = message,
            .file = "",
            .line = 0,
            .column = 0,
            .timestamp = std.time.milliTimestamp(),
        };
    }

    pub fn format(
        self: Context,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        if (self.file.len > 0) {
            try writer.print("{s} at {s}:{d}:{d}", .{
                self.message,
                self.file,
                self.line,
                self.column,
            });
        } else {
            try writer.print("{s}", .{self.message});
        }
    }

    /// دریافت نام فایل (بدون path)
    pub fn filename(self: Context) []const u8 {
        if (self.file.len == 0) return "";

        var i: usize = self.file.len;
        while (i > 0) {
            i -= 1;
            if (self.file[i] == '/' or self.file[i] == '\\') {
                return self.file[i + 1 ..];
            }
        }
        return self.file;
    }
};

/// Wrapper برای خطاها با context
pub fn ErrorWithContext(comptime E: type) type {
    return struct {
        err: E,
        context: ?Context,

        const Self = @This();

        pub fn init(err: E, ctx: ?Context) Self {
            return .{ .err = err, .context = ctx };
        }

        pub fn fromError(err: E) Self {
            return .{ .err = err, .context = null };
        }

        pub fn withContext(err: E, ctx: Context) Self {
            return .{ .err = err, .context = ctx };
        }

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            try writer.print("Error: {s}", .{@errorName(self.err)});
            if (self.context) |ctx| {
                try writer.print(" - {}", .{ctx});
            }
        }

        /// دریافت category
        pub fn category(self: Self) errors.ErrorCategory {
            // اگر E از نوع errors.Error است
            if (E == errors.Error) {
                return errors.getCategory(self.err);
            }
            return .general;
        }

        /// دریافت severity
        pub fn severity(self: Self) errors.ErrorSeverity {
            if (E == errors.Error) {
                return errors.getSeverity(self.err);
            }
            return .errors;
        }
    };
}

// تست‌ها
test "Context: creation" {
    const ctx = Context.init("Test error", @src());

    try std.testing.expectEqual(@as(u32, 116), ctx.line);
    try std.testing.expect(ctx.message.len > 0);
    try std.testing.expect(ctx.timestamp > 0);
}

test "Context: filename" {
    const ctx = Context.init("Test", @src());
    const fname = ctx.filename();

    try std.testing.expect(fname.len > 0);
    try std.testing.expect(std.mem.endsWith(u8, fname, ".zig"));
}

test "ErrorWithContext: basic" {
    const EWC = ErrorWithContext(errors.Error);

    const ctx = Context.initSimple("Division by zero");
    const err = EWC.withContext(error.InvalidArgument, ctx);

    try std.testing.expectEqual(error.InvalidArgument, err.err);
    try std.testing.expect(err.context != null);
}

test "ErrorWithContext: formatting" {
    const EWC = ErrorWithContext(errors.Error);

    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(std.testing.allocator);

    const ctx = Context.initSimple("Test error");
    const err = EWC.withContext(error.IoError, ctx);

    try std.fmt.format(buffer.writer(std.testing.allocator), "{}", .{err});
    try std.testing.expect(buffer.items.len > 0);
}
