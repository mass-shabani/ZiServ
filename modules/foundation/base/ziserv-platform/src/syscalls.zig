// ============================================================
// فایل: src/syscalls.zig
// Syscall wrappers cross-platform
// ============================================================

const std = @import("std");
const builtin = @import("builtin");
const Os = @import("os.zig").Os;

/// Syscall wrappers
pub const Syscalls = struct {
    /// خواندن environment variable
    pub fn getenv(name: []const u8, allocator: std.mem.Allocator) !?[]u8 {
        return std.process.getEnvVarOwned(allocator, name) catch |err| {
            return if (err == error.EnvironmentVariableNotFound) null else err;
        };
    }

    /// نوشتن environment variable (فقط در process فعلی)
    pub fn setenv(name: []const u8, value: []const u8) !void {
        // در Zig، setenv فقط در process فعلی تأثیر می‌گذارد
        // و روشی برای تنظیم permanent ندارد
        _ = name;
        _ = value;
        return error.NotImplemented;
    }

    /// دریافت current working directory
    pub fn getcwd(allocator: std.mem.Allocator) ![]u8 {
        return try std.process.getCwdAlloc(allocator);
    }

    /// تغییر current working directory
    pub fn chdir(path: []const u8) !void {
        try std.process.changeCurDir(std.fs.cwd(), path);
    }

    /// دریافت process ID
    pub fn getpid() u32 {
        if (builtin.os.tag == .windows) {
            return std.os.windows.GetCurrentProcessId();
        } else {
            return @intCast(std.os.linux.getpid());
        }
    }

    /// دریافت parent process ID
    pub fn getppid() u32 {
        if (builtin.os.tag == .windows) {
            // Windows ندارد - return خود pid
            return getpid();
        } else {
            return @intCast(std.os.linux.getppid());
        }
    }

    /// خواب (nanoseconds)
    pub fn sleep(nanoseconds: u64) void {
        std.Thread.sleep(nanoseconds);
    }

    /// خواب (milliseconds)
    pub fn sleepMs(milliseconds: u64) void {
        sleep(milliseconds * std.time.ns_per_ms);
    }

    /// دریافت hostname
    pub fn hostname(buffer: []u8) ![]u8 {
        return std.os.gethostname(buffer) catch {
            return error.SystemResources;
        };
    }

    /// دریافت username
    pub fn username(allocator: std.mem.Allocator) ![]u8 {
        if (builtin.os.tag == .windows) {
            // Windows
            if (try getenv("USERNAME", allocator)) |name| {
                return name;
            }
            return error.NotFound;
        } else {
            // POSIX
            if (try getenv("USER", allocator)) |name| {
                return name;
            }
            return error.NotFound;
        }
    }

    /// دریافت home directory
    pub fn homeDir(allocator: std.mem.Allocator) ![]u8 {
        if (builtin.os.tag == .windows) {
            if (try getenv("USERPROFILE", allocator)) |home| {
                return home;
            }
            return error.NotFound;
        } else {
            if (try getenv("HOME", allocator)) |home| {
                return home;
            }
            return error.NotFound;
        }
    }

    /// دریافت temp directory
    pub fn tempDir(allocator: std.mem.Allocator) ![]u8 {
        // اول TMPDIR را چک کن
        if (try getenv("TMPDIR", allocator)) |tmp| {
            return tmp;
        }

        // بعد TEMP (Windows)
        if (try getenv("TEMP", allocator)) |tmp| {
            return tmp;
        }

        // بعد TMP
        if (try getenv("TMP", allocator)) |tmp| {
            return tmp;
        }

        // پیش‌فرض
        if (builtin.os.tag == .windows) {
            return try allocator.dupe(u8, "C:\\Windows\\Temp");
        } else {
            return try allocator.dupe(u8, "/tmp");
        }
    }
};

// تست‌ها
test "Syscalls: getenv" {
    // PATH باید در همه سیستم‌ها باشد
    if (try Syscalls.getenv("PATH", std.testing.allocator)) |path| {
        defer std.testing.allocator.free(path);
        try std.testing.expect(path.len > 0);
    }
}

test "Syscalls: getcwd" {
    const cwd = try Syscalls.getcwd(std.testing.allocator);
    defer std.testing.allocator.free(cwd);

    try std.testing.expect(cwd.len > 0);
}

test "Syscalls: getpid" {
    const pid = Syscalls.getpid();
    try std.testing.expect(pid > 0);
}

test "Syscalls: sleep" {
    const start = std.time.milliTimestamp();
    Syscalls.sleepMs(10);
    const end = std.time.milliTimestamp();

    try std.testing.expect(end - start >= 10);
}

// test "Syscalls: hostname" {
//     var buffer: [256]u8 = undefined;
//     const name = try Syscalls.hostname(&buffer);

//     try std.testing.expect(name.len > 0);
// }

test "Syscalls: tempDir" {
    const tmp = try Syscalls.tempDir(std.testing.allocator);
    defer std.testing.allocator.free(tmp);

    try std.testing.expect(tmp.len > 0);
}
