// ============================================================
// فایل: src/arena.zig
// Arena Allocator - Fast temporary allocations
// ============================================================

const std = @import("std");

/// Arena allocator برای تخصیص‌های موقت
/// مناسب برای per-request memory management
pub const Arena = struct {
    inner: std.heap.ArenaAllocator,

    const Self = @This();

    /// ایجاد Arena جدید
    pub fn init(child: std.mem.Allocator) Self {
        return .{
            .inner = std.heap.ArenaAllocator.init(child),
        };
    }

    /// آزادسازی همه حافظه
    pub fn deinit(self: *Self) void {
        self.inner.deinit();
    }

    /// دریافت allocator
    pub fn allocator(self: *Self) std.mem.Allocator {
        return self.inner.allocator();
    }

    /// Reset arena (آزادسازی بدون deinit)
    pub fn reset(self: *Self) void {
        _ = self.inner.reset(.retain_capacity);
    }

    /// Reset و آزادسازی کامل حافظه
    pub fn resetFull(self: *Self) void {
        _ = self.inner.reset(.free_all);
    }

    /// دریافت وضعیت arena
    pub fn state(self: *Self) std.heap.ArenaAllocator.State {
        return self.inner.state;
    }
};

/// Scoped Arena - Arena که خودکار cleanup می‌شود
pub fn ScopedArena(comptime Context: type) type {
    return struct {
        arena: Arena,
        context: Context,

        const Self = @This();

        pub fn init(child: std.mem.Allocator, context: Context) Self {
            return .{
                .arena = Arena.init(child),
                .context = context,
            };
        }

        pub fn deinit(self: *Self) void {
            self.arena.deinit();
        }

        pub fn allocator(self: *Self) std.mem.Allocator {
            return self.arena.allocator();
        }

        pub fn reset(self: *Self) void {
            self.arena.reset();
        }
    };
}

/// Arena با حد مشخص
pub const BoundedArena = struct {
    arena: Arena,
    max_size: usize,
    current_size: usize,

    const Self = @This();

    pub fn init(child: std.mem.Allocator, max_size: usize) Self {
        return .{
            .arena = Arena.init(child),
            .max_size = max_size,
            .current_size = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }

    /// Allocator با چک کردن حد
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
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (self.current_size + len > self.max_size) {
            return null;
        }

        const result = self.arena.allocator().rawAlloc(len, ptr_align, ret_addr);
        if (result != null) {
            self.current_size += len;
        }
        return result;
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (new_len > buf.len) {
            const additional = new_len - buf.len;
            if (self.current_size + additional > self.max_size) {
                return false;
            }
        }

        const result = self.arena.allocator().rawResize(buf, buf_align, new_len, ret_addr);
        if (result) {
            if (new_len > buf.len) {
                self.current_size += new_len - buf.len;
            } else {
                self.current_size -= buf.len - new_len;
            }
        }
        return result;
    }

    fn free(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: std.mem.Alignment,
        ret_addr: usize,
    ) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.arena.allocator().rawFree(buf, buf_align, ret_addr);
        if (self.current_size >= buf.len) {
            self.current_size -= buf.len;
        } else {
            self.current_size = 0;
        }
    }

    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }

    pub fn reset(self: *Self) void {
        self.arena.reset();
        self.current_size = 0;
    }

    pub fn remaining(self: Self) usize {
        if (self.max_size > self.current_size) {
            return self.max_size - self.current_size;
        }
        return 0;
    }
};

// ─────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────

test "Arena: basic usage" {
    var arena = Arena.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const slice1 = try alloc.alloc(u8, 100);
    const slice2 = try alloc.alloc(u32, 50);

    slice1[0] = 42;
    slice2[0] = 1234;

    try std.testing.expectEqual(@as(u8, 42), slice1[0]);
    try std.testing.expectEqual(@as(u32, 1234), slice2[0]);
}

test "Arena: reset" {
    var arena = Arena.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    _ = try alloc.alloc(u8, 1000);
    arena.reset();

    _ = try alloc.alloc(u8, 1000);
}

test "BoundedArena: limit enforcement" {
    var arena = BoundedArena.init(std.testing.allocator, 1000);
    defer arena.deinit();

    const alloc = arena.allocator();

    const slice1 = try alloc.alloc(u8, 500);
    try std.testing.expectEqual(@as(usize, 500), slice1.len);

    const slice2 = try alloc.alloc(u8, 400);
    try std.testing.expectEqual(@as(usize, 400), slice2.len);

    // این باید fail کند
    const slice3 = alloc.alloc(u8, 200);
    try std.testing.expectError(error.OutOfMemory, slice3);
}

test "BoundedArena: remaining" {
    var arena = BoundedArena.init(std.testing.allocator, 1000);
    defer arena.deinit();

    try std.testing.expectEqual(@as(usize, 1000), arena.remaining());

    const alloc = arena.allocator();
    _ = try alloc.alloc(u8, 300);

    try std.testing.expect(arena.remaining() <= 700);
}

test "BoundedArena: reset" {
    var arena = BoundedArena.init(std.testing.allocator, 1000);
    defer arena.deinit();

    const alloc = arena.allocator();
    _ = try alloc.alloc(u8, 500);

    arena.reset();

    try std.testing.expectEqual(@as(usize, 0), arena.current_size);
}
