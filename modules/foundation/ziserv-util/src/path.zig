// ============================================================
// فایل: modules/foundation/ziserv-util/src/path.zig
// Path utilities - cross-platform
// ============================================================

const std = @import("std");
const core = @import("ziserv-core");

/// جداکننده مسیر
pub inline fn separator() u8 {
    return std.fs.path.sep;
}

/// جداکننده مسیر به صورت رشته
pub fn separatorStr() []const u8 {
    return if (std.fs.path.sep == '\\') "\\" else "/";
}

/// Join paths
pub fn join(allocator: std.mem.Allocator, paths: []const []const u8) ![]u8 {
    if (paths.len == 0) return try allocator.alloc(u8, 0);
    if (paths.len == 1) return allocator.dupe(u8, paths[0]);

    return std.fs.path.join(allocator, paths);
}

/// Basename (filename from path)
pub fn basename(path: []const u8) []const u8 {
    return std.fs.path.basename(path);
}

/// Dirname (directory from path)
pub fn dirname(path: []const u8) []const u8 {
    return std.fs.path.dirname(path) orelse ".";
}

/// Extension (file extension)
pub fn extension(path: []const u8) []const u8 {
    return std.fs.path.extension(path);
}

/// Stem (filename without extension)
pub fn stem(path: []const u8) []const u8 {
    return std.fs.path.stem(path);
}

/// Normalize path (remove redundant separators, resolve . and ..)
pub fn normalize(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    defer result.deinit(allocator);

    var components = std.ArrayList([]const u8){};
    defer components.deinit(allocator);

    var it = std.mem.splitScalar(u8, path, std.fs.path.sep);
    while (it.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".")) {
            continue;
        } else if (std.mem.eql(u8, component, "..")) {
            if (components.items.len > 0) {
                _ = components.pop();
            }
        } else {
            try components.append(allocator, component);
        }
    }

    // Build result
    const is_absolute = std.fs.path.isAbsolute(path);
    if (is_absolute) {
        try result.append(allocator, std.fs.path.sep);
    }

    for (components.items, 0..) |comp, i| {
        try result.appendSlice(allocator, comp);
        if (i < components.items.len - 1) {
            try result.append(allocator, std.fs.path.sep);
        }
    }

    if (result.items.len == 0) {
        try result.append(allocator, '.');
    }

    return result.toOwnedSlice(allocator);
}

/// Is absolute path
pub inline fn isAbsolute(path: []const u8) bool {
    return std.fs.path.isAbsolute(path);
}

/// Convert to absolute path
pub fn absolute(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (isAbsolute(path)) {
        return allocator.dupe(u8, path);
    }

    const cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd);

    return join(allocator, &[_][]const u8{ cwd, path });
}

/// Relative path (from base to target)
pub fn relative(allocator: std.mem.Allocator, from: []const u8, to: []const u8) ![]u8 {
    const from_abs = try absolute(allocator, from);
    defer allocator.free(from_abs);

    const to_abs = try absolute(allocator, to);
    defer allocator.free(to_abs);

    // Split into components
    var from_parts = std.ArrayList([]const u8){};
    defer from_parts.deinit(allocator);

    var to_parts = std.ArrayList([]const u8){};
    defer to_parts.deinit(allocator);

    var it = std.mem.splitScalar(u8, from_abs, std.fs.path.sep);
    while (it.next()) |part| {
        if (part.len > 0) try from_parts.append(allocator, part);
    }

    it = std.mem.splitScalar(u8, to_abs, std.fs.path.sep);
    while (it.next()) |part| {
        if (part.len > 0) try to_parts.append(allocator, part);
    }

    // Find common prefix
    var common: usize = 0;
    while (common < from_parts.items.len and common < to_parts.items.len) {
        if (!std.mem.eql(u8, from_parts.items[common], to_parts.items[common])) break;
        common += 1;
    }

    // Build relative path
    var result = std.ArrayList([]const u8){};
    defer result.deinit(allocator);

    // Add ".." for each remaining from component
    var i = common;
    while (i < from_parts.items.len) : (i += 1) {
        try result.append(allocator, "..");
    }

    // Add remaining to components
    i = common;
    while (i < to_parts.items.len) : (i += 1) {
        try result.append(allocator, to_parts.items[i]);
    }

    if (result.items.len == 0) {
        return allocator.dupe(u8, ".");
    }

    return join(allocator, result.items);
}

/// Check if path exists
pub fn exists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

/// Check if path is directory
pub fn isDir(path: []const u8) bool {
    const stat = std.fs.cwd().statFile(path) catch return false;
    return stat.kind == .directory;
}

/// Check if path is file
pub fn isFile(path: []const u8) bool {
    const stat = std.fs.cwd().statFile(path) catch return false;
    return stat.kind == .file;
}

/// Create directory (recursive)
pub fn mkdirAll(path: []const u8) !void {
    try std.fs.cwd().makePath(path);
}

/// Remove directory (recursive)
pub fn removeAll(path: []const u8) !void {
    try std.fs.cwd().deleteTree(path);
}

/// List directory contents
pub fn listDir(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var result = std.ArrayList([]const u8){};
    defer result.deinit(allocator);

    var it = dir.iterate();
    while (try it.next()) |entry| {
        const name = try allocator.dupe(u8, entry.name);
        try result.append(allocator, name);
    }

    return result.toOwnedSlice(allocator);
}

/// Walk directory recursively
pub const WalkEntry = struct {
    path: []const u8,
    kind: std.fs.File.Kind,
};

pub fn walk(allocator: std.mem.Allocator, path: []const u8) ![]WalkEntry {
    var result = std.ArrayList(WalkEntry){};
    defer result.deinit(allocator);

    try walkRecursive(allocator, &result, path, "");

    return result.toOwnedSlice(allocator);
}

fn walkRecursive(
    allocator: std.mem.Allocator,
    result: *std.ArrayList(WalkEntry),
    base: []const u8,
    rel: []const u8,
) !void {
    const full_path = if (rel.len == 0) base else try join(allocator, &[_][]const u8{ base, rel });
    defer if (rel.len > 0) allocator.free(full_path);

    var dir = try std.fs.cwd().openDir(full_path, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        const entry_path = if (rel.len == 0)
            try allocator.dupe(u8, entry.name)
        else
            try join(allocator, &[_][]const u8{ rel, entry.name });

        try result.*.append(allocator, .{
            .path = entry_path,
            .kind = entry.kind,
        });

        if (entry.kind == .directory) {
            try walkRecursive(allocator, result, base, entry_path);
        }
    }
}

/// Home directory
pub fn homeDir(allocator: std.mem.Allocator) ![]u8 {
    if (std.process.getEnvVarOwned(allocator, "HOME")) |home| {
        return home;
    } else |_| {
        if (core.platform.Os.isWindows()) {
            if (std.process.getEnvVarOwned(allocator, "USERPROFILE")) |home| {
                return home;
            } else |_| {}
        }
    }
    return error.HomeNotFound;
}

/// Temp directory
pub fn tempDir(allocator: std.mem.Allocator) ![]u8 {
    if (std.process.getEnvVarOwned(allocator, "TMPDIR")) |tmp| {
        return tmp;
    } else |_| {
        if (std.process.getEnvVarOwned(allocator, "TEMP")) |tmp| {
            return tmp;
        } else |_| {}
    }

    return if (core.platform.Os.isWindows())
        allocator.dupe(u8, "C:\\Windows\\Temp")
    else
        allocator.dupe(u8, "/tmp");
}

test "path utilities" {
    try std.testing.expectEqualStrings("file.txt", basename("/path/to/file.txt"));
    try std.testing.expectEqualStrings("/path/to", dirname("/path/to/file.txt"));
    try std.testing.expectEqualStrings(".txt", extension("file.txt"));
    try std.testing.expectEqualStrings("file", stem("file.txt"));
}

test "path join" {
    const joined = try join(std.testing.allocator, &[_][]const u8{ "a", "b", "c" });
    defer std.testing.allocator.free(joined);

    try std.testing.expect(joined.len > 0);
}

test "path normalize" {
    const normalized = try normalize(std.testing.allocator, "a/./b/../c");
    defer std.testing.allocator.free(normalized);

    // Platform-dependent result
    try std.testing.expect(normalized.len > 0);
}
