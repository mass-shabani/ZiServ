// ============================================================
// فایل: modules/foundation/ziserv-bytes/src/bytes.zig
// Immutable bytes - Zero-copy reference
// ============================================================

const std = @import("std");
const core = @import("ziserv-core");

/// Bytes - یک reference به داده‌های immutable
pub const Bytes = struct {
    data: []const u8,
    allocator: ?std.mem.Allocator,

    const Self = @This();

    /// ساخت از slice
    pub fn from(data: []const u8) Self {
        return .{
            .data = data,
            .allocator = null,
        };
    }

    /// ساخت با کپی کردن
    pub fn copy(data: []const u8, allocator: std.mem.Allocator) !Self {
        const buf = try allocator.dupe(u8, data);
        return .{
            .data = buf,
            .allocator = allocator,
        };
    }

    /// ساخت خالی
    pub fn empty() Self {
        return .{
            .data = &[_]u8{},
            .allocator = null,
        };
    }

    /// آزاد کردن حافظه
    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            alloc.free(self.data);
        }
        self.data = &[_]u8{};
        self.allocator = null;
    }

    /// طول داده
    pub fn len(self: Self) usize {
        return self.data.len;
    }

    /// آیا خالی است؟
    pub fn isEmpty(self: Self) bool {
        return self.data.len == 0;
    }

    /// دسترسی به byte
    pub fn at(self: Self, index: usize) ?u8 {
        if (index >= self.data.len) return null;
        return self.data[index];
    }

    /// برش دادن (zero-copy)
    pub fn slice(self: Self, start: usize, end: usize) Self {
        if (start >= self.data.len or end > self.data.len or start > end) {
            return Self.empty();
        }
        return .{
            .data = self.data[start..end],
            .allocator = null, // برش نباید حافظه آزاد کند
        };
    }

    /// مقایسه
    pub fn equals(self: Self, other: Self) bool {
        return std.mem.eql(u8, self.data, other.data);
    }

    /// شروع می‌شود با
    pub fn startsWith(self: Self, prefix: []const u8) bool {
        return std.mem.startsWith(u8, self.data, prefix);
    }

    /// تمام می‌شود با
    pub fn endsWith(self: Self, suffix: []const u8) bool {
        return std.mem.endsWith(u8, self.data, suffix);
    }

    /// پیدا کردن
    pub fn indexOf(self: Self, needle: []const u8) ?usize {
        return std.mem.indexOf(u8, self.data, needle);
    }

    /// تبدیل به رشته
    pub fn asString(self: Self) []const u8 {
        return self.data;
    }

    /// کلون کردن
    pub fn clone(self: Self, allocator: std.mem.Allocator) !Self {
        return try Self.copy(self.data, allocator);
    }
};

test "bytes basic" {
    const data = "Hello, World!";
    const bytes = Bytes.from(data);

    try std.testing.expectEqual(@as(usize, 13), bytes.len());
    try std.testing.expect(!bytes.isEmpty());
    try std.testing.expectEqual(@as(u8, 'H'), bytes.at(0).?);
}

test "bytes slice" {
    const bytes = Bytes.from("Hello, World!");
    const slice = bytes.slice(0, 5);

    try std.testing.expectEqualStrings("Hello", slice.asString());
}

test "bytes copy" {
    const data = "Test";
    var bytes = try Bytes.copy(data, std.testing.allocator);
    defer bytes.deinit();

    try std.testing.expectEqual(@as(usize, 4), bytes.len());
}
