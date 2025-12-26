// ============================================================
// فایل: modules/foundation/ziserv-core/src/platform.zig
// تشخیص و مدیریت پلتفرم
// ============================================================

const std = @import("std");
const builtin = @import("builtin");

/// سیستم‌عامل‌های پشتیبانی شده
pub const Os = enum {
    windows,
    linux,
    macos,
    bsd,
    unknown,

    /// سیستم‌عامل فعلی
    pub fn current() Os {
        return switch (builtin.os.tag) {
            .windows => .windows,
            .linux => .linux,
            .macos => .macos,
            .freebsd, .openbsd, .netbsd => .bsd,
            else => .unknown,
        };
    }

    /// آیا پلتفرم پشتیبانی می‌شود؟
    pub fn isSupported() bool {
        return current() != .unknown;
    }

    /// نام سیستم‌عامل
    pub fn name() []const u8 {
        return switch (current()) {
            .windows => "Windows",
            .linux => "Linux",
            .macos => "macOS",
            .bsd => "BSD",
            .unknown => "Unknown",
        };
    }

    /// آیا POSIX است؟
    pub fn isPosix() bool {
        return switch (current()) {
            .linux, .macos, .bsd => true,
            .windows, .unknown => false,
        };
    }

    /// آیا Windows است؟
    pub fn isWindows() bool {
        return current() == .windows;
    }
};

/// معماری CPU
pub const Arch = enum {
    x86_64,
    aarch64,
    arm,
    riscv64,
    unknown,

    pub fn current() Arch {
        return switch (builtin.cpu.arch) {
            .x86_64 => .x86_64,
            .aarch64 => .aarch64,
            .arm => .arm,
            .riscv64 => .riscv64,
            else => .unknown,
        };
    }

    pub fn name() []const u8 {
        return switch (current()) {
            .x86_64 => "x86_64",
            .aarch64 => "ARM64",
            .arm => "ARM",
            .riscv64 => "RISC-V 64",
            .unknown => "Unknown",
        };
    }

    pub fn bits() u8 {
        return switch (current()) {
            .x86_64, .aarch64, .riscv64 => 64,
            .arm => 32,
            .unknown => 0,
        };
    }
};

/// اطلاعات پلتفرم
pub const PlatformInfo = struct {
    os: Os,
    arch: Arch,
    is_debug: bool,
    is_safe: bool,

    pub fn current() PlatformInfo {
        return .{
            .os = Os.current(),
            .arch = Arch.current(),
            .is_debug = builtin.mode == .Debug,
            .is_safe = builtin.mode == .ReleaseSafe,
        };
    }

    pub fn description(self: PlatformInfo, allocator: std.mem.Allocator) ![]const u8 {
        return try std.fmt.allocPrint(
            allocator,
            "{s} {s} ({d}-bit) - {s}",
            .{
                self.os.name(),
                self.arch.name(),
                self.arch.bits(),
                if (self.is_debug) "Debug" else if (self.is_safe) "ReleaseSafe" else "Release",
            },
        );
    }
};

/// توابع کمکی پلتفرم
pub const Platform = struct {
    /// جداکننده مسیر
    pub fn pathSeparator() u8 {
        return if (Os.isWindows()) '\\' else '/';
    }

    /// خط جدید
    pub fn newline() []const u8 {
        return if (Os.isWindows()) "\r\n" else "\n";
    }

    /// کاراکتر null
    pub fn nullDevice() []const u8 {
        return if (Os.isWindows()) "NUL" else "/dev/null";
    }

    /// پسوند فایل اجرایی
    pub fn exeExtension() []const u8 {
        return if (Os.isWindows()) ".exe" else "";
    }

    /// پسوند کتابخانه پویا
    pub fn dynlibExtension() []const u8 {
        return switch (Os.current()) {
            .windows => ".dll",
            .macos => ".dylib",
            .linux, .bsd => ".so",
            .unknown => "",
        };
    }

    /// تعداد هسته‌های CPU
    pub fn cpuCount() !usize {
        return try std.Thread.getCpuCount();
    }

    /// اندازه صفحه حافظه
    pub fn pageSize() usize {
        return std.mem.page_size;
    }
};

test "platform detection" {
    const info = PlatformInfo.current();
    try std.testing.expect(info.os != .unknown);
    try std.testing.expect(info.arch != .unknown);
}

test "platform utilities" {
    const sep = Platform.pathSeparator();
    try std.testing.expect(sep == '/' or sep == '\\');

    const nl = Platform.newline();
    try std.testing.expect(nl.len > 0);
}
