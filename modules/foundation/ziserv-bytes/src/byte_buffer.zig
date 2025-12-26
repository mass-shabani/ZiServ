// ============================================================
// فایل: modules/foundation/ziserv-bytes/src/byte_buffer.zig
// Buffer با read/write position
// ============================================================

const std = @import("std");
const core = @import("ziserv-core");

/// ByteBuffer - buffer با position tracking
pub const ByteBuffer = struct {
    data: std.ArrayList(u8),
    read_pos: usize,
    write_pos: usize,

    const Self = @This();

    /// ساخت
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .data = std.ArrayList(u8).init(allocator),
            .read_pos = 0,
            .write_pos = 0,
        };
    }

    /// ساخت با capacity
    pub fn initCapacity(allocator: std.mem.Allocator, capacity: usize) !Self {
        var buf = std.ArrayList(u8).init(allocator);
        try buf.ensureTotalCapacity(capacity);
        return .{
            .data = buf,
            .read_pos = 0,
            .write_pos = 0,
        };
    }

    /// آزاد کردن
    pub fn deinit(self: *Self) void {
        self.data.deinit();
    }

    /// تعداد bytes قابل خواندن
    pub fn readable(self: Self) usize {
        return self.write_pos - self.read_pos;
    }

    /// تعداد bytes قابل نوشتن
    pub fn writable(self: Self) usize {
        return self.data.capacity - self.write_pos;
    }

    /// نوشتن
    pub fn write(self: *Self, data: []const u8) !void {
        const needed = self.write_pos + data.len;
        if (needed > self.data.capacity) {
            try self.data.ensureTotalCapacity(needed);
        }

        // اگر items.len کمتر از write_pos است، resize کن
        if (self.data.items.len < needed) {
            try self.data.resize(needed);
        }

        @memcpy(self.data.items[self.write_pos..][0..data.len], data);
        self.write_pos += data.len;
    }

    /// خواندن
    pub fn read(self: *Self, buf: []u8) usize {
        const available = self.readable();
        const to_read = @min(buf.len, available);

        if (to_read > 0) {
            @memcpy(buf[0..to_read], self.data.items[self.read_pos..][0..to_read]);
            self.read_pos += to_read;
        }

        return to_read;
    }

    /// خواندن بدون تغییر position
    pub fn peek(self: Self, buf: []u8) usize {
        const available = self.readable();
        const to_read = @min(buf.len, available);

        if (to_read > 0) {
            @memcpy(buf[0..to_read], self.data.items[self.read_pos..][0..to_read]);
        }

        return to_read;
    }

    /// رد کردن n byte
    pub fn skip(self: *Self, n: usize) void {
        const available = self.readable();
        self.read_pos += @min(n, available);
    }

    /// compact کردن - حذف داده‌های خوانده شده
    pub fn compact(self: *Self) void {
        if (self.read_pos == 0) return;

        const available = self.readable();
        if (available > 0) {
            std.mem.copyForwards(u8, self.data.items[0..available], self.data.items[self.read_pos..self.write_pos]);
        }

        self.write_pos = available;
        self.read_pos = 0;
    }

    /// پاک کردن
    pub fn clear(self: *Self) void {
        self.read_pos = 0;
        self.write_pos = 0;
        self.data.clearRetainingCapacity();
    }

    /// reset کردن positions
    pub fn reset(self: *Self) void {
        self.read_pos = 0;
        self.write_pos = 0;
    }
};

test "byte buffer" {
    var buf = ByteBuffer.init(std.testing.allocator);
    defer buf.deinit();

    try buf.write("Hello");
    try std.testing.expectEqual(@as(usize, 5), buf.readable());

    var read_buf: [10]u8 = undefined;
    const n = buf.read(&read_buf);
    try std.testing.expectEqual(@as(usize, 5), n);
    try std.testing.expectEqualStrings("Hello", read_buf[0..n]);
}

test "byte buffer compact" {
    var buf = ByteBuffer.init(std.testing.allocator);
    defer buf.deinit();

    try buf.write("ABCDEFGH");

    var read_buf: [4]u8 = undefined;
    _ = buf.read(&read_buf);

    buf.compact();
    try std.testing.expectEqual(@as(usize, 4), buf.readable());
    try std.testing.expectEqual(@as(usize, 0), buf.read_pos);
}
