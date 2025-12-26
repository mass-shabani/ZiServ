// ============================================================
// فایل: modules/foundation/ziserv-bytes/src/bytes_mut.zig
// Mutable bytes - قابل تغییر
// ============================================================

const std = @import("std");
const core = @import("ziserv-core");
const Bytes = @import("bytes.zig").Bytes;

/// BytesMut - bytes قابل تغییر
pub const BytesMut = struct {
    buffer: std.ArrayList(u8),

    const Self = @This();

    /// ساخت با capacity
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    /// ساخت با capacity اولیه
    pub fn initCapacity(allocator: std.mem.Allocator, cpcty: usize) !Self {
        var buf = std.ArrayList(u8).init(allocator);
        try buf.ensureTotalCapacity(cpcty);
        return .{ .buffer = buf };
    }

    /// ساخت از داده
    pub fn from(data: []const u8, allocator: std.mem.Allocator) !Self {
        var self = Self.init(allocator);
        try self.write(data);
        return self;
    }

    /// آزاد کردن
    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }

    /// طول فعلی
    pub fn len(self: Self) usize {
        return self.buffer.items.len;
    }

    /// capacity
    pub fn capacity(self: Self) usize {
        return self.buffer.capacity;
    }

    /// آیا خالی است؟
    pub fn isEmpty(self: Self) bool {
        return self.buffer.items.len == 0;
    }

    /// نوشتن
    pub fn write(self: *Self, data: []const u8) !void {
        try self.buffer.appendSlice(data);
    }

    /// نوشتن یک byte
    pub fn writeByte(self: *Self, byte: u8) !void {
        try self.buffer.append(byte);
    }

    /// خواندن همه
    pub fn readAll(self: *Self) []u8 {
        return self.buffer.items;
    }

    /// خواندن به slice
    pub fn readBytes(self: Self) []const u8 {
        return self.buffer.items;
    }

    /// پاک کردن
    pub fn clear(self: *Self) void {
        self.buffer.clearRetainingCapacity();
    }

    /// تغییر اندازه
    pub fn resize(self: *Self, new_len: usize) !void {
        try self.buffer.resize(new_len);
    }

    /// reserve کردن capacity
    pub fn reserve(self: *Self, additional: usize) !void {
        try self.buffer.ensureUnusedCapacity(additional);
    }

    /// برش مستقیم (mutable)
    pub fn slice(self: *Self, start: usize, end: usize) []u8 {
        if (start >= self.buffer.items.len or end > self.buffer.items.len or start > end) {
            return &[_]u8{};
        }
        return self.buffer.items[start..end];
    }

    /// تبدیل به Bytes (freeze)
    pub fn freeze(self: *Self) Bytes {
        const data = self.buffer.toOwnedSlice() catch &[_]u8{};
        const alloc = self.buffer.allocator;
        return .{
            .data = data,
            .allocator = alloc,
        };
    }

    /// کپی کردن به BytesMut جدید
    pub fn clone(self: Self) !Self {
        return try Self.from(self.buffer.items, self.buffer.allocator);
    }
};

test "bytes mut basic" {
    var bytes = BytesMut.init(std.testing.allocator);
    defer bytes.deinit();

    try bytes.write("Hello");
    try std.testing.expectEqual(@as(usize, 5), bytes.len());

    try bytes.write(", World!");
    try std.testing.expectEqual(@as(usize, 13), bytes.len());
}

test "bytes mut freeze" {
    var bytes_mut = BytesMut.init(std.testing.allocator);
    try bytes_mut.write("Test");

    var bytes = bytes_mut.freeze();
    defer bytes.deinit();

    try std.testing.expectEqualStrings("Test", bytes.asString());
}
