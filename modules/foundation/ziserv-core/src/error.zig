// ============================================================
// فایل: modules/foundation/ziserv-core/src/error.zig
// سیستم مدیریت خطا
// ============================================================

const std = @import("std");

/// خطاهای عمومی ZiServ
pub const Error = error{
    // خطاهای عمومی
    InvalidArgument,
    InvalidState,
    NotSupported,
    NotImplemented,
    Timeout,

    // خطاهای I/O
    IoError,
    ConnectionClosed,
    ConnectionReset,
    BrokenPipe,

    // خطاهای حافظه
    OutOfMemory,
    BufferTooSmall,
    BufferOverflow,

    // خطاهای پارس
    ParseError,
    InvalidFormat,
    InvalidEncoding,

    // خطاهای پلتفرم
    PlatformError,
    PermissionDenied,
    NotFound,
};

/// نتیجه با خطای ZiServ
pub fn Result(comptime T: type) type {
    return Error!T;
}

/// Context برای خطا (اطلاعات اضافی)
pub const ErrorContext = struct {
    message: []const u8,
    file: []const u8,
    line: u32,
    column: u32,

    pub fn init(message: []const u8, src: std.builtin.SourceLocation) ErrorContext {
        return .{
            .message = message,
            .file = src.file,
            .line = src.line,
            .column = src.column,
        };
    }

    pub fn format(
        self: ErrorContext,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s} at {s}:{d}:{d}", .{
            self.message,
            self.file,
            self.line,
            self.column,
        });
    }
};

/// Wrapper برای خطاها با context
pub const ErrorWithContext = struct {
    err: Error,
    context: ?ErrorContext,

    pub fn init(err: Error, context: ?ErrorContext) ErrorWithContext {
        return .{ .err = err, .context = context };
    }

    pub fn format(
        self: ErrorWithContext,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Error: {}", .{self.err});
        if (self.context) |ctx| {
            try writer.print(" - {}", .{ctx});
        }
    }
};

/// Panic handler سفارشی
pub fn panicHandler(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;

    std.debug.print("\n{'=':#<70}\n", .{});
    std.debug.print("ZiServ PANIC: {s}\n", .{msg});
    std.debug.print("{'=':#<70}\n", .{});

    std.process.exit(1);
}

test "error context" {
    const ctx = ErrorContext.init("Test error", @src());
    try std.testing.expect(ctx.message.len > 0);
    try std.testing.expect(ctx.line > 0);
}
