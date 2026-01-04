// ============================================================
// فایل: src/errors.zig
// تعریف Error types عمومی
// ============================================================

const std = @import("std");

/// دسته‌بندی خطاها
pub const ErrorCategory = enum {
    /// خطای عمومی
    general,
    /// خطای I/O
    io,
    /// خطای شبکه
    network,
    /// خطای پارس
    parse,
    /// خطای validation
    validation,
    /// خطای حافظه
    memory,
    /// خطای پلتفرم
    platform,
    /// خطای امنیتی
    security,
    /// خطای timeout
    timeout,
    /// خطای configuration
    config,

    pub fn toString(self: ErrorCategory) []const u8 {
        return switch (self) {
            .general => "General",
            .io => "I/O",
            .network => "Network",
            .parse => "Parse",
            .validation => "Validation",
            .memory => "Memory",
            .platform => "Platform",
            .security => "Security",
            .timeout => "Timeout",
            .config => "Configuration",
        };
    }
};

/// سطح جدیت خطا
pub const ErrorSeverity = enum {
    /// اطلاعات - قابل نادیده گرفتن
    info,
    /// هشدار - نیاز به توجه
    warning,
    /// خطا - نیاز به رسیدگی
    errors,
    /// بحرانی - نیاز به توقف فوری
    critical,

    pub fn toString(self: ErrorSeverity) []const u8 {
        return switch (self) {
            .info => "Info",
            .warning => "Warning",
            .errors => "Error",
            .critical => "Critical",
        };
    }
};

/// خطاهای عمومی ZiServ
pub const Error = error{
    // ─────────────────────────────────────────────────────────
    // General Errors
    // ─────────────────────────────────────────────────────────
    /// آرگومان نامعتبر
    InvalidArgument,
    /// وضعیت نامعتبر
    InvalidState,
    /// پشتیبانی نمی‌شود
    NotSupported,
    /// پیاده‌سازی نشده
    NotImplemented,
    /// پیدا نشد
    NotFound,
    /// از قبل وجود دارد
    AlreadyExists,
    /// دسترسی رد شد
    PermissionDenied,
    /// منبع مشغول است
    ResourceBusy,
    /// عملیات لغو شد
    Cancelled,
    /// زمان تمام شد
    Timeout,

    // ─────────────────────────────────────────────────────────
    // I/O Errors
    // ─────────────────────────────────────────────────────────
    /// خطای I/O
    IoError,
    /// اتصال بسته شده
    ConnectionClosed,
    /// اتصال ریست شده
    ConnectionReset,
    /// لوله شکسته
    BrokenPipe,
    /// خطای خواندن
    ReadError,
    /// خطای نوشتن
    WriteError,
    /// پایان فایل
    EndOfFile,

    // ─────────────────────────────────────────────────────────
    // Memory Errors
    // ─────────────────────────────────────────────────────────
    /// حافظه کافی نیست
    OutOfMemory,
    /// بافر کوچک است
    BufferTooSmall,
    /// بافر پر است
    BufferOverflow,

    // ─────────────────────────────────────────────────────────
    // Parse/Validation Errors
    // ─────────────────────────────────────────────────────────
    /// خطای پارس
    ParseError,
    /// فرمت نامعتبر
    InvalidFormat,
    /// encoding نامعتبر
    InvalidEncoding,
    /// طول نامعتبر
    InvalidLength,
    /// مقدار نامعتبر
    InvalidValue,
    /// محدوده خارج از حد
    OutOfRange,

    // ─────────────────────────────────────────────────────────
    // Network Errors
    // ─────────────────────────────────────────────────────────
    /// خطای شبکه
    NetworkError,
    /// اتصال برقرار نشد
    ConnectionFailed,
    /// اتصال رد شد
    ConnectionRefused,
    /// timeout اتصال
    ConnectionTimeout,
    /// آدرس قابل دسترس نیست
    AddressNotAvailable,
    /// آدرس در حال استفاده
    AddressInUse,

    // ─────────────────────────────────────────────────────────
    // Platform Errors
    // ─────────────────────────────────────────────────────────
    /// خطای پلتفرم
    PlatformError,
    /// syscall شکست خورد
    SystemCallFailed,

    // ─────────────────────────────────────────────────────────
    // Security Errors
    // ─────────────────────────────────────────────────────────
    /// خطای امنیتی
    SecurityError,
    /// احراز هویت شکست خورد
    AuthenticationFailed,
    /// مجوز کافی نیست
    InsufficientPermissions,

    // ─────────────────────────────────────────────────────────
    // Configuration Errors
    // ─────────────────────────────────────────────────────────
    /// خطای پیکربندی
    ConfigError,
    /// کلید پیکربندی پیدا نشد
    ConfigKeyNotFound,
    /// مقدار پیکربندی نامعتبر
    InvalidConfigValue,
};

/// دریافت category یک خطا
pub fn getCategory(err: Error) ErrorCategory {
    return switch (err) {
        error.IoError,
        error.ConnectionClosed,
        error.ConnectionReset,
        error.BrokenPipe,
        error.ReadError,
        error.WriteError,
        error.EndOfFile,
        => .io,

        error.NetworkError,
        error.ConnectionFailed,
        error.ConnectionRefused,
        error.ConnectionTimeout,
        error.AddressNotAvailable,
        error.AddressInUse,
        => .network,

        error.ParseError,
        error.InvalidFormat,
        error.InvalidEncoding,
        => .parse,

        error.InvalidLength,
        error.InvalidValue,
        error.OutOfRange,
        => .validation,

        error.OutOfMemory,
        error.BufferTooSmall,
        error.BufferOverflow,
        => .memory,

        error.PlatformError,
        error.SystemCallFailed,
        => .platform,

        error.SecurityError,
        error.AuthenticationFailed,
        error.InsufficientPermissions,
        error.PermissionDenied,
        => .security,

        error.Timeout,
        error.ConnectionTimeout,
        => .timeout,

        error.ConfigError,
        error.ConfigKeyNotFound,
        error.InvalidConfigValue,
        => .config,

        else => .general,
    };
}

/// دریافت severity یک خطا
pub fn getSeverity(err: Error) ErrorSeverity {
    return switch (err) {
        error.NotSupported,
        error.NotImplemented,
        error.NotFound,
        => .warning,

        error.OutOfMemory,
        error.SystemCallFailed,
        error.SecurityError,
        error.AuthenticationFailed,
        => .critical,

        else => .errors,
    };
}

/// تبدیل خطا به رشته
pub fn toString(err: Error) []const u8 {
    return @errorName(err);
}

// تست‌ها
test "Error: category detection" {
    try std.testing.expectEqual(ErrorCategory.io, getCategory(error.IoError));
    try std.testing.expectEqual(ErrorCategory.network, getCategory(error.NetworkError));
    try std.testing.expectEqual(ErrorCategory.memory, getCategory(error.OutOfMemory));
    try std.testing.expectEqual(ErrorCategory.parse, getCategory(error.ParseError));
}

test "Error: severity detection" {
    try std.testing.expectEqual(ErrorSeverity.warning, getSeverity(error.NotSupported));
    try std.testing.expectEqual(ErrorSeverity.critical, getSeverity(error.OutOfMemory));
    try std.testing.expectEqual(ErrorSeverity.errors, getSeverity(error.IoError));
}

test "Error: toString" {
    const name = toString(error.InvalidArgument);
    try std.testing.expectEqualStrings("InvalidArgument", name);
}
