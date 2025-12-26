// ============================================================
// فایل: modules/foundation/ziserv-bytes/src/bytes_pool.zig
// Pool برای buffer reuse
// ============================================================

const std = @import("std");
const core = @import("ziserv-core");
const ByteBuffer = @import("byte_buffer.zig").ByteBuffer;

/// Pool برای ByteBuffer
pub const BytesPool = struct {
    buffers: std.ArrayList(*ByteBuffer),
    buffer_size: usize,
    max_pool_size: usize,
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,

    const Self = @This();

    /// ساخت pool
    pub fn init(allocator: std.mem.Allocator, buffer_size: usize, max_pool_size: usize) Self {
        return .{
            .buffers = std.ArrayList(*ByteBuffer).init(allocator),
            .buffer_size = buffer_size,
            .max_pool_size = max_pool_size,
            .allocator = allocator,
            .mutex = .{},
        };
    }

    /// آزاد کردن
    pub fn deinit(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.buffers.items) |buf| {
            buf.deinit();
            self.allocator.destroy(buf);
        }
        self.buffers.deinit();
    }

    /// دریافت buffer از pool
    pub fn acquire(self: *Self) !*ByteBuffer {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.buffers.items.len > 0) {
            const buf = self.buffers.pop();
            buf.reset();
            return buf;
        }

        // ساخت buffer جدید
        const buf = try self.allocator.create(ByteBuffer);
        buf.* = try ByteBuffer.initCapacity(self.allocator, self.buffer_size);
        return buf;
    }

    /// برگرداندن buffer به pool
    pub fn release(self: *Self, buffer: *ByteBuffer) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.buffers.items.len < self.max_pool_size) {
            buffer.clear();
            self.buffers.append(buffer) catch {
                buffer.deinit();
                self.allocator.destroy(buffer);
            };
        } else {
            buffer.deinit();
            self.allocator.destroy(buffer);
        }
    }

    /// تعداد buffer در pool
    pub fn size(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.buffers.items.len;
    }
};

test "bytes pool" {
    var pool = BytesPool.init(std.testing.allocator, 1024, 10);
    defer pool.deinit();

    const buf1 = try pool.acquire();
    try buf1.write("Test");

    pool.release(buf1);
    try std.testing.expectEqual(@as(usize, 1), pool.size());

    const buf2 = try pool.acquire();
    try std.testing.expectEqual(@as(usize, 0), buf2.readable());
}
