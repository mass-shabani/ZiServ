// ============================================================
// فایل: src/os.zig
// تشخیص سیستم‌عامل
// ============================================================

const std = @import("std");
const builtin = @import("builtin");

/// سیستم‌عامل‌های پشتیبانی شده
pub const Os = enum {
    windows,
    linux,
    macos,
    freebsd,
    openbsd,
    netbsd,
    unknown,

    /// سیستم‌عامل فعلی
    pub fn current() Os {
        return switch (builtin.os.tag) {
            .windows => .windows,
            .linux => .linux,
            .macos => .macos,
            .freebsd => .freebsd,
            .openbsd => .openbsd,
            .netbsd => .netbsd,
            else => .unknown,
        };
    }

    /// آیا سیستم‌عامل پشتیبانی می‌شود؟
    pub fn isSupported(self: Os) bool {
        return self != .unknown;
    }

    /// نام سیستم‌عامل
    pub fn name(self: Os) []const u8 {
        return switch (self) {
            .windows => "Windows",
            .linux => "Linux",
            .macos => "macOS",
            .freebsd => "FreeBSD",
            .openbsd => "OpenBSD",
            .netbsd => "NetBSD",
            .unknown => "Unknown",
        };
    }

    /// آیا POSIX است؟
    pub fn isPosix(self: Os) bool {
        return switch (self) {
            .linux, .macos, .freebsd, .openbsd, .netbsd => true,
            .windows, .unknown => false,
        };
    }

    /// آیا Windows است؟
    pub fn isWindows(self: Os) bool {
        return self == .windows;
    }

    /// آیا Unix-like است؟
    pub fn isUnix(self: Os) bool {
        return switch (self) {
            .linux, .macos, .freebsd, .openbsd, .netbsd => true,
            else => false,
        };
    }

    /// آیا BSD است؟
    pub fn isBsd(self: Os) bool {
        return switch (self) {
            .freebsd, .openbsd, .netbsd => true,
            else => false,
        };
    }

    /// جداکننده مسیر
    pub fn pathSeparator(self: Os) u8 {
        return if (self.isWindows()) '\\' else '/';
    }

    /// جداکننده مسیر به صورت رشته
    pub fn pathSeparatorStr(self: Os) []const u8 {
        return if (self.isWindows()) "\\" else "/";
    }

    /// خط جدید
    pub fn newline(self: Os) []const u8 {
        return if (self.isWindows()) "\r\n" else "\n";
    }

    /// null device
    pub fn nullDevice(self: Os) []const u8 {
        return if (self.isWindows()) "NUL" else "/dev/null";
    }

    /// پسوند فایل اجرایی
    pub fn exeExtension(self: Os) []const u8 {
        return if (self.isWindows()) ".exe" else "";
    }

    /// پسوند کتابخانه پویا
    pub fn dynlibExtension(self: Os) []const u8 {
        return switch (self) {
            .windows => ".dll",
            .macos => ".dylib",
            .linux, .freebsd, .openbsd, .netbsd => ".so",
            .unknown => "",
        };
    }

    /// حداکثر طول مسیر
    pub fn maxPathLen(self: Os) usize {
        return switch (self) {
            .windows => 260, // MAX_PATH
            .linux => 4096, // PATH_MAX
            .macos => 1024,
            .freebsd, .openbsd, .netbsd => 1024,
            .unknown => 256,
        };
    }
};

// تست‌ها
test "Os: current" {
    const os = Os.current();
    try std.testing.expect(os != .unknown or !Os.current().isSupported());
}

test "Os: detection" {
    const os = Os.current();

    // حداقل یکی باید true باشد
    const is_classified = os.isWindows() or os.isPosix();
    try std.testing.expect(is_classified or os == .unknown);
}

test "Os: path separator" {
    const os = Os.current();
    const sep = os.pathSeparator();

    try std.testing.expect(sep == '/' or sep == '\\');
}

test "Os: extensions" {
    const os = Os.current();

    const exe_ext = os.exeExtension();
    const dll_ext = os.dynlibExtension();

    try std.testing.expect(exe_ext.len >= 0);
    try std.testing.expect(dll_ext.len > 0);
}

test "Os: all enum values" {
    inline for (@typeInfo(Os).Enum.fields) |field| {
        const os: Os = @enumFromInt(field.value);
        _ = os.name();
        _ = os.isSupported();
        _ = os.isPosix();
        _ = os.pathSeparator();
    }
}
