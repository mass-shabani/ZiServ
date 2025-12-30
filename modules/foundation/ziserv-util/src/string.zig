// ============================================================
// فایل: modules/foundation/ziserv-util/src/string.zig
// String utilities - بهینه‌سازی شده برای performance
// ============================================================

const std = @import("std");
const core = @import("ziserv-core");

/// String Builder - Unmanaged ArrayList در Zig 0.15+
pub const StringBuilder = struct {
    buffer: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) StringBuilder {
        return .{
            .buffer = std.ArrayList(u8){},
            .allocator = allocator,
        };
    }

    pub fn initCapacity(allocator: std.mem.Allocator, capacity_size: usize) !StringBuilder {
        var buf = std.ArrayList(u8){};
        try buf.ensureTotalCapacity(allocator, capacity_size);
        return .{
            .buffer = buf,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StringBuilder) void {
        self.buffer.deinit(self.allocator);
    }

    pub inline fn append(self: *StringBuilder, str: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, str);
    }

    pub inline fn appendChar(self: *StringBuilder, c: u8) !void {
        try self.buffer.append(self.allocator, c);
    }

    pub fn appendFmt(self: *StringBuilder, comptime fmt: []const u8, args: anytype) !void {
        try self.buffer.writer(self.allocator).print(fmt, args);
    }

    pub inline fn clear(self: *StringBuilder) void {
        self.buffer.clearRetainingCapacity();
    }

    pub inline fn len(self: *const StringBuilder) usize {
        return self.buffer.items.len;
    }

    pub inline fn capacity(self: *const StringBuilder) usize {
        return self.buffer.capacity;
    }

    pub fn toString(self: *StringBuilder) []u8 {
        return self.buffer.toOwnedSlice(self.allocator) catch &[_]u8{};
    }

    pub fn toStringConst(self: *const StringBuilder) []const u8 {
        return self.buffer.items;
    }
};

/// Split string - بهینه‌سازی شده با iterator
pub const SplitIterator = struct {
    buffer: []const u8,
    delimiter: []const u8,
    index: usize,

    pub fn init(buffer: []const u8, delimiter: []const u8) SplitIterator {
        return .{
            .buffer = buffer,
            .delimiter = delimiter,
            .index = 0,
        };
    }

    pub fn next(self: *SplitIterator) ?[]const u8 {
        if (self.index >= self.buffer.len) return null;

        const start = self.index;
        const end = std.mem.indexOfPos(u8, self.buffer, start, self.delimiter) orelse self.buffer.len;

        self.index = end + self.delimiter.len;
        return self.buffer[start..end];
    }

    pub fn rest(self: *const SplitIterator) []const u8 {
        if (self.index >= self.buffer.len) return &[_]u8{};
        return self.buffer[self.index..];
    }
};

/// Split به array - allocation
pub fn split(allocator: std.mem.Allocator, str: []const u8, delimiter: []const u8) ![][]const u8 {
    var result = std.ArrayList([]const u8){};
    defer result.deinit(allocator);

    var it = SplitIterator.init(str, delimiter);
    while (it.next()) |part| {
        try result.append(allocator, part);
    }

    return result.toOwnedSlice(allocator);
}

/// Trim whitespace
pub fn trim(str: []const u8) []const u8 {
    return std.mem.trim(u8, str, &std.ascii.whitespace);
}

/// Trim left
pub fn trimLeft(str: []const u8) []const u8 {
    return std.mem.trimLeft(u8, str, &std.ascii.whitespace);
}

/// Trim right
pub fn trimRight(str: []const u8) []const u8 {
    return std.mem.trimRight(u8, str, &std.ascii.whitespace);
}

/// Starts with
pub inline fn startsWith(str: []const u8, prefix: []const u8) bool {
    return std.mem.startsWith(u8, str, prefix);
}

/// Ends with
pub inline fn endsWith(str: []const u8, suffix: []const u8) bool {
    return std.mem.endsWith(u8, str, suffix);
}

/// Contains
pub inline fn contains(str: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, str, needle) != null;
}

/// Index of
pub inline fn indexOf(str: []const u8, needle: []const u8) ?usize {
    return std.mem.indexOf(u8, str, needle);
}

/// Last index of
pub inline fn lastIndexOf(str: []const u8, needle: []const u8) ?usize {
    return std.mem.lastIndexOf(u8, str, needle);
}

/// Replace (single occurrence)
pub fn replace(allocator: std.mem.Allocator, str: []const u8, old: []const u8, new: []const u8) ![]u8 {
    const pos = indexOf(str, old) orelse return allocator.dupe(u8, str);

    var result = try allocator.alloc(u8, str.len - old.len + new.len);
    @memcpy(result[0..pos], str[0..pos]);
    @memcpy(result[pos .. pos + new.len], new);
    @memcpy(result[pos + new.len ..], str[pos + old.len ..]);

    return result;
}

/// Replace all occurrences
pub fn replaceAll(allocator: std.mem.Allocator, str: []const u8, old: []const u8, new: []const u8) ![]u8 {
    if (old.len == 0) return allocator.dupe(u8, str);

    var count_str: usize = 0;
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, str, pos, old)) |found| {
        count_str += 1;
        pos = found + old.len;
    }

    if (count_str == 0) return allocator.dupe(u8, str);

    const new_len = str.len + count_str * (new.len - old.len);
    var result = try allocator.alloc(u8, new_len);

    var src_pos: usize = 0;
    var dst_pos: usize = 0;

    while (std.mem.indexOfPos(u8, str, src_pos, old)) |found| {
        const copy_len = found - src_pos;
        @memcpy(result[dst_pos .. dst_pos + copy_len], str[src_pos..found]);
        dst_pos += copy_len;

        @memcpy(result[dst_pos .. dst_pos + new.len], new);
        dst_pos += new.len;
        src_pos = found + old.len;
    }

    @memcpy(result[dst_pos..], str[src_pos..]);
    return result;
}

/// To uppercase
pub fn toUpper(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    const result_str = try allocator.dupe(u8, str);
    for (result_str) |*c| {
        c.* = std.ascii.toUpper(c.*);
    }
    return result_str;
}

/// To lowercase
pub fn toLower(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    const result_str = try allocator.dupe(u8, str);
    for (result_str) |*c| {
        c.* = std.ascii.toLower(c.*);
    }
    return result_str;
}

/// Reverse string
pub fn reverse(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    var result = try allocator.alloc(u8, str.len);
    var i: usize = 0;
    while (i < str.len) : (i += 1) {
        result[str.len - 1 - i] = str[i];
    }
    return result;
}

/// Repeat string
pub fn repeat(allocator: std.mem.Allocator, str: []const u8, count_str: usize) ![]u8 {
    if (count_str == 0) return try allocator.alloc(u8, 0);

    var result = try allocator.alloc(u8, str.len * count_str);
    var i: usize = 0;
    while (i < count_str) : (i += 1) {
        @memcpy(result[i * str.len .. (i + 1) * str.len], str);
    }
    return result;
}

/// Join strings
pub fn join(allocator: std.mem.Allocator, strings: []const []const u8, separator: []const u8) ![]u8 {
    if (strings.len == 0) return try allocator.alloc(u8, 0);

    var total_len: usize = 0;
    for (strings) |s| {
        total_len += s.len;
    }
    if (strings.len > 1) {
        total_len += separator.len * (strings.len - 1);
    }

    var result = try allocator.alloc(u8, total_len);
    var pos: usize = 0;

    for (strings, 0..) |s, i| {
        @memcpy(result[pos .. pos + s.len], s);
        pos += s.len;
        if (i < strings.len - 1) {
            @memcpy(result[pos .. pos + separator.len], separator);
            pos += separator.len;
        }
    }

    return result;
}

/// String equality (case-insensitive)
pub fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (std.ascii.toLower(ca) != std.ascii.toLower(cb)) return false;
    }
    return true;
}

/// Count occurrences
pub fn count(str: []const u8, needle: []const u8) usize {
    if (needle.len == 0) return 0;

    var cnt: usize = 0;
    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, str, pos, needle)) |found| {
        cnt += 1;
        pos = found + needle.len;
    }
    return cnt;
}

test "string builder" {
    var sb = StringBuilder.init(std.testing.allocator);
    defer sb.deinit();

    try sb.append("Hello");
    try sb.appendChar(' ');
    try sb.append("World");

    try std.testing.expectEqualStrings("Hello World", sb.toStringConst());
}

test "split iterator" {
    var it = SplitIterator.init("a,b,c,d", ",");

    try std.testing.expectEqualStrings("a", it.next().?);
    try std.testing.expectEqualStrings("b", it.next().?);
    try std.testing.expectEqualStrings("c", it.next().?);
    try std.testing.expectEqualStrings("d", it.next().?);
    try std.testing.expect(it.next() == null);
}

test "string utilities" {
    try std.testing.expectEqualStrings("hello", trim("  hello  "));
    try std.testing.expect(startsWith("hello", "hel"));
    try std.testing.expect(endsWith("hello", "llo"));
    try std.testing.expect(contains("hello", "ell"));

    const replaced = try replace(std.testing.allocator, "hello", "l", "L");
    defer std.testing.allocator.free(replaced);
    try std.testing.expectEqualStrings("heLlo", replaced);
}
