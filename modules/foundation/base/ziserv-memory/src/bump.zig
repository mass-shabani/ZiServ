// ============================================================
// فایل: src/bump.zig
// Bump Allocator - Ultra-fast linear allocation
// ============================================================

const std = @import("std");

/// Bump allocator - سریع‌ترین allocator برای allocations متوالی
/// فقط forward allocation، بدون individual free
pub const BumpAllocator = struct {
    buffer: []u8,
    offset: usize,

    const Self = @This();

    /// ایجاد bump allocator با buffer
    pub fn init(buffer: []u8) Self {
        return .{
            .buffer = buffer,
            .offset = 0,
        };
    }

    /// دریافت allocator
    pub fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
                .remap = remap,
            },
        };
    }

    fn alloc(
        ctx: *anyopaque,
        len: usize,
        ptr_align: std.mem.Alignment,
        _: usize,
    ) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const alignment: usize = @as(usize, 1) << @intFromEnum(ptr_align);

        // محاسبه aligned offset
        const current_addr = @intFromPtr(self.buffer.ptr) + self.offset;
        const aligned_addr = std.mem.alignForward(usize, current_addr, alignment);
        const padding = aligned_addr - current_addr;
        const aligned_offset = self.offset + padding;

        // چک کردن فضای کافی
        if (aligned_offset + len > self.buffer.len) {
            return null;
        }

        const result = self.buffer.ptr + aligned_offset;
        self.offset = aligned_offset + len;

        return result;
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        _: std.mem.Alignment,
        new_len: usize,
        _: usize,
    ) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));

        // فقط اگر آخرین allocation باشد می‌توانیم resize کنیم
        const buf_end = @intFromPtr(buf.ptr) + buf.len;
        const buffer_start = @intFromPtr(self.buffer.ptr);
        const current_end = buffer_start + self.offset;

        if (buf_end != current_end) {
            return false;
        }

        const buf_start_offset = @intFromPtr(buf.ptr) - buffer_start;
        if (buf_start_offset + new_len > self.buffer.len) {
            return false;
        }

        self.offset = buf_start_offset + new_len;
        return true;
    }

    fn free(
        _: *anyopaque,
        _: []u8,
        _: std.mem.Alignment,
        _: usize,
    ) void {
        // Bump allocator doesn't support individual free
    }

    fn remap(
        _: *anyopaque,
        _: []u8,
        _: std.mem.Alignment,
        _: usize,
        _: usize,
    ) ?[*]u8 {
        // Bump allocator doesn't support remap
        return null;
    }

    /// Reset allocator
    pub fn reset(self: *Self) void {
        self.offset = 0;
    }

    /// مقدار استفاده شده
    pub fn used(self: Self) usize {
        return self.offset;
    }

    /// مقدار باقی‌مانده
    pub fn remaining(self: Self) usize {
        return self.buffer.len - self.offset;
    }

    /// درصد استفاده
    pub fn utilizationPercent(self: Self) f64 {
        if (self.buffer.len == 0) return 0.0;
        return @as(f64, @floatFromInt(self.offset)) /
            @as(f64, @floatFromInt(self.buffer.len)) * 100.0;
    }
};

/// Bump allocator با checkpoint/restore
pub const CheckpointBumpAllocator = struct {
    bump: BumpAllocator,
    checkpoints: std.ArrayList(usize),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(buffer: []u8, backing_allocator: std.mem.Allocator) Self {
        return .{
            .bump = BumpAllocator.init(buffer),
            .checkpoints = std.ArrayList(usize).init(backing_allocator),
            .allocator = backing_allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.checkpoints.deinit();
    }

    pub fn allocator_interface(self: *Self) std.mem.Allocator {
        return self.bump.allocator();
    }

    /// ذخیره checkpoint
    pub fn checkpoint(self: *Self) !void {
        try self.checkpoints.append(self.bump.offset);
    }

    /// بازگشت به آخرین checkpoint
    pub fn restore(self: *Self) !void {
        if (self.checkpoints.items.len == 0) {
            return error.NoCheckpoint;
        }
        self.bump.offset = self.checkpoints.pop();
    }

    /// حذف checkpoint بدون restore
    pub fn drop_checkpoint(self: *Self) !void {
        if (self.checkpoints.items.len == 0) {
            return error.NoCheckpoint;
        }
        _ = self.checkpoints.pop();
    }

    pub fn reset(self: *Self) void {
        self.bump.reset();
        self.checkpoints.clearRetainingCapacity();
    }
};

/// Growing bump allocator - می‌تواند رشد کند
pub const GrowingBumpAllocator = struct {
    current: BumpAllocator,
    backing: std.mem.Allocator,
    buffers: std.ArrayList([]u8),
    buffer_size: usize,

    const Self = @This();

    pub fn init(backing: std.mem.Allocator, initial_size: usize) !Self {
        const initial_buffer = try backing.alloc(u8, initial_size);

        var buffers = std.ArrayList([]u8).init(backing);
        try buffers.append(initial_buffer);

        return Self{
            .current = BumpAllocator.init(initial_buffer),
            .backing = backing,
            .buffers = buffers,
            .buffer_size = initial_size,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.buffers.items) |buffer| {
            self.backing.free(buffer);
        }
        self.buffers.deinit();
    }

    pub fn allocator_interface(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
                .remap = remap,
            },
        };
    }

    fn alloc(
        ctx: *anyopaque,
        len: usize,
        ptr_align: std.mem.Alignment,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));

        // سعی کن از current buffer استفاده کنی
        if (self.current.allocator().rawAlloc(len, ptr_align, ret_addr)) |ptr| {
            return ptr;
        }

        // نیاز به buffer جدید
        const new_size = @max(self.buffer_size, len * 2);
        const new_buffer = self.backing.alloc(u8, new_size) catch return null;

        self.buffers.append(new_buffer) catch {
            self.backing.free(new_buffer);
            return null;
        };

        self.current = BumpAllocator.init(new_buffer);
        return self.current.allocator().rawAlloc(len, ptr_align, ret_addr);
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.current.allocator().rawResize(buf, buf_align, new_len, ret_addr);
    }

    fn free(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize) void {
        // No individual free
    }

    fn remap(
        _: *anyopaque,
        _: []u8,
        _: std.mem.Alignment,
        _: usize,
        _: usize,
    ) ?[*]u8 {
        // GrowingBumpAllocator doesn't support remap
        return null;
    }

    pub fn reset(self: *Self) void {
        // فقط اولین buffer را نگه دار
        if (self.buffers.items.len > 1) {
            for (self.buffers.items[1..]) |buffer| {
                self.backing.free(buffer);
            }
            self.buffers.shrinkRetainingCapacity(1);
        }

        if (self.buffers.items.len > 0) {
            self.current = BumpAllocator.init(self.buffers.items[0]);
        }
    }

    pub fn total_used(self: Self) usize {
        var total: usize = 0;
        for (self.buffers.items[0 .. self.buffers.items.len - 1]) |buffer| {
            total += buffer.len;
        }
        total += self.current.used();
        return total;
    }
};

// ─────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────

test "BumpAllocator: basic allocation" {
    var buffer: [1024]u8 = undefined;
    var bump = BumpAllocator.init(&buffer);

    const alloc = bump.allocator();

    const slice1 = try alloc.alloc(u8, 100);
    try std.testing.expectEqual(@as(usize, 100), slice1.len);
    try std.testing.expectEqual(@as(usize, 100), bump.used());

    const slice2 = try alloc.alloc(u32, 10);
    try std.testing.expectEqual(@as(usize, 10), slice2.len);
}

test "BumpAllocator: alignment" {
    var buffer: [1024]u8 = undefined;
    var bump = BumpAllocator.init(&buffer);

    const alloc = bump.allocator();

    _ = try alloc.alloc(u8, 1);
    const aligned = try alloc.alignedAlloc(u64, 8, 1);

    try std.testing.expect(@intFromPtr(aligned.ptr) % 8 == 0);
}

test "BumpAllocator: reset" {
    var buffer: [1024]u8 = undefined;
    var bump = BumpAllocator.init(&buffer);

    const alloc = bump.allocator();

    _ = try alloc.alloc(u8, 500);
    try std.testing.expectEqual(@as(usize, 500), bump.used());

    bump.reset();
    try std.testing.expectEqual(@as(usize, 0), bump.used());

    _ = try alloc.alloc(u8, 100);
    try std.testing.expectEqual(@as(usize, 100), bump.used());
}

test "CheckpointBumpAllocator: checkpoint/restore" {
    var buffer: [1024]u8 = undefined;
    var bump = CheckpointBumpAllocator.init(&buffer, std.testing.allocator);
    defer bump.deinit();

    const alloc = bump.allocator_interface();

    _ = try alloc.alloc(u8, 100);
    try bump.checkpoint();

    _ = try alloc.alloc(u8, 200);
    try std.testing.expect(bump.bump.used() >= 300);

    try bump.restore();
    try std.testing.expectEqual(@as(usize, 100), bump.bump.used());
}

test "GrowingBumpAllocator: growth" {
    var bump = try GrowingBumpAllocator.init(std.testing.allocator, 100);
    defer bump.deinit();

    const alloc = bump.allocator_interface();

    _ = try alloc.alloc(u8, 80);
    _ = try alloc.alloc(u8, 80);

    try std.testing.expect(bump.buffers.items.len >= 2);
}
