// ============================================================
// فایل: src/env.zig
// Environment variable utilities
// ============================================================

const std = @import("std");
const builtin = @import("builtin");

/// Environment variable utilities
pub const Env = struct {
    /// دریافت environment variable
    pub fn get(name: []const u8, allocator: std.mem.Allocator) !?[]u8 {
        return std.process.getEnvVarOwned(allocator, name) catch |err| {
            return if (err == error.EnvironmentVariableNotFound) null else err;
        };
    }

    /// دریافت با مقدار پیش‌فرض
    pub fn getOr(name: []const u8, default: []const u8, allocator: std.mem.Allocator) ![]u8 {
        if (try get(name, allocator)) |value| {
            return value;
        }
        return try allocator.dupe(u8, default);
    }

    /// بررسی وجود environment variable
    pub fn has(name: []const u8) bool {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        const value = get(name, allocator) catch return false;
        return value != null;
    }

    /// دریافت به عنوان integer
    pub fn getInt(comptime T: type, name: []const u8, allocator: std.mem.Allocator) !?T {
        if (try get(name, allocator)) |value| {
            defer allocator.free(value);
            return try std.fmt.parseInt(T, value, 10);
        }
        return null;
    }

    /// دریافت به عنوان boolean
    pub fn getBool(name: []const u8, allocator: std.mem.Allocator) !?bool {
        if (try get(name, allocator)) |value| {
            defer allocator.free(value);

            if (std.ascii.eqlIgnoreCase(value, "true") or
                std.ascii.eqlIgnoreCase(value, "yes") or
                std.ascii.eqlIgnoreCase(value, "1"))
            {
                return true;
            }

            if (std.ascii.eqlIgnoreCase(value, "false") or
                std.ascii.eqlIgnoreCase(value, "no") or
                std.ascii.eqlIgnoreCase(value, "0"))
            {
                return false;
            }

            return error.InvalidValue;
        }
        return null;
    }

    /// دریافت همه environment variables
    pub fn getAll(allocator: std.mem.Allocator) !std.process.EnvMap {
        return try std.process.getEnvMap(allocator);
    }

    /// نمایش همه environment variables
    pub fn printAll(writer: anytype, allocator: std.mem.Allocator) !void {
        var env_map = try getAll(allocator);
        defer env_map.deinit();

        try writer.writeAll("\n");
        try writer.writeAll("Environment Variables:\n");
        try writer.writeAll("─────────────────────────────────────\n");

        var it = env_map.iterator();
        var count: usize = 0;
        while (it.next()) |entry| {
            try writer.print("  {s} = {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            count += 1;
            if (count >= 20) {
                try writer.writeAll("  ... (truncated)\n");
                break;
            }
        }

        try writer.writeAll("\n");
    }

    /// Common environment variables
    pub const Common = struct {
        pub fn path(allocator: std.mem.Allocator) !?[]u8 {
            return try get("PATH", allocator);
        }

        pub fn home(allocator: std.mem.Allocator) !?[]u8 {
            if (builtin.os.tag == .windows) {
                return try get("USERPROFILE", allocator);
            } else {
                return try get("HOME", allocator);
            }
        }

        pub fn user(allocator: std.mem.Allocator) !?[]u8 {
            if (builtin.os.tag == .windows) {
                return try get("USERNAME", allocator);
            } else {
                return try get("USER", allocator);
            }
        }

        pub fn shell(allocator: std.mem.Allocator) !?[]u8 {
            return try get("SHELL", allocator);
        }

        pub fn editor(allocator: std.mem.Allocator) !?[]u8 {
            return try get("EDITOR", allocator);
        }

        pub fn lang(allocator: std.mem.Allocator) !?[]u8 {
            return try get("LANG", allocator);
        }

        pub fn term(allocator: std.mem.Allocator) !?[]u8 {
            return try get("TERM", allocator);
        }
    };
};

// تست‌ها
test "Env: get PATH" {
    // PATH باید در همه سیستم‌ها وجود داشته باشد
    if (try Env.get("PATH", std.testing.allocator)) |path| {
        defer std.testing.allocator.free(path);
        try std.testing.expect(path.len > 0);
    }
}

test "Env: has" {
    try std.testing.expect(Env.has("PATH"));
}

test "Env: getOr" {
    const value = try Env.getOr("NONEXISTENT_VAR_12345", "default", std.testing.allocator);
    defer std.testing.allocator.free(value);

    try std.testing.expectEqualStrings("default", value);
}

test "Env: getBool" {
    // تست با مقدار موجود نیست، فقط API را چک می‌کنیم
    _ = try Env.getBool("SOME_VAR", std.testing.allocator);
}

test "Env: Common" {
    if (try Env.Common.home(std.testing.allocator)) |home| {
        defer std.testing.allocator.free(home);
        try std.testing.expect(home.len > 0);
    }
}
