// ============================================================
// فایل: src/allocator.zig
// Enhanced Allocator Wrapper
// ============================================================

const std = @import("std");
const Stats = @import("stats.zig").Stats;

/// Wrapper برای std.mem.Allocator با قابلیت‌های اضافی
pub const Allocator = struct {
    backing: std.mem.Allocator,

    const Self = @This();

    /// ایجاد Allocator جدید
    pub fn init(backing: std.mem.Allocator) Self {
        return .{
            .backing = backing,
        };
    }

    /// دریافت std.mem.Allocator
    pub fn allocator(self: *Self) std.mem.Allocator {
        return self.backing;
    }

    /// تخصیص حافظه برای slice
    pub fn alloc(self: *Self, comptime T: type, n: usize) ![]T {
        return self.backing.alloc(T, n);
    }

    /// تخصیص حافظه با align مشخص
    pub fn alignedAlloc(
        self: *Self,
        comptime T: type,
        comptime alignment: u29,
        n: usize,
    ) ![]align(alignment) T {
        return self.backing.alignedAlloc(T, alignment, n);
    }

    /// آزادسازی حافظه
    pub fn free(self: *Self, memory: anytype) void {
        self.backing.free(memory);
    }

    /// تخصیص و صفر کردن
    pub fn allocWithOptions(
        self: *Self,
        comptime T: type,
        n: usize,
        options: struct {
            zero: bool = false,
            alignment: ?u29 = null,
        },
    ) ![]T {
        const slice = if (options.alignment) |alignment|
            try self.backing.alignedAlloc(T, alignment, n)
        else
            try self.backing.alloc(T, n);

        if (options.zero) {
            @memset(slice, std.mem.zeroes(T));
        }

        return slice;
    }

    /// تخصیص یک آیتم
    pub fn create(self: *Self, comptime T: type) !*T {
        return self.backing.create(T);
    }

    /// آزادسازی یک آیتم
    pub fn destroy(self: *Self, ptr: anytype) void {
        self.backing.destroy(ptr);
    }

    /// کپی کردن slice
    pub fn dupe(self: *Self, comptime T: type, m: []const T) ![]T {
        return self.backing.dupe(T, m);
    }

    /// Realloc
    pub fn realloc(self: *Self, old_mem: anytype, new_n: usize) !@TypeOf(old_mem) {
        return self.backing.realloc(old_mem, new_n);
    }
};

/// Allocator با thread-safety
pub const ThreadSafeAllocator = struct {
    backing: std.mem.Allocator,
    mutex: std.Thread.Mutex,

    const Self = @This();

    pub fn init(backing: std.mem.Allocator) Self {
        return .{
            .backing = backing,
            .mutex = .{},
        };
    }

    pub fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    fn alloc(
        ctx: *anyopaque,
        len: usize,
        ptr_align: u8,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.backing.rawAlloc(len, ptr_align, ret_addr);
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: u8,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        return self.backing.rawResize(buf, buf_align, new_len, ret_addr);
    }

    fn free(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: u8,
        ret_addr: usize,
    ) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.mutex.lock();
        defer self.mutex.unlock();

        self.backing.rawFree(buf, buf_align, ret_addr);
    }
};

// ─────────────────────────────────────────────────────────
// Utility Functions
// ─────────────────────────────────────────────────────────

/// محاسبه اندازه aligned
pub fn alignedSize(size: usize, alignment: usize) usize {
    const mask = alignment - 1;
    return (size + mask) & ~mask;
}

/// چک کردن alignment
pub fn isAligned(ptr: usize, alignment: usize) bool {
    return (ptr & (alignment - 1)) == 0;
}

/// محاسبه padding مورد نیاز
pub fn paddingNeeded(ptr: usize, alignment: usize) usize {
    const mask = alignment - 1;
    const misalignment = ptr & mask;
    if (misalignment == 0) return 0;
    return alignment - misalignment;
}

// ─────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────

test "Allocator: basic allocation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var alloc = Allocator.init(gpa.allocator());

    const slice = try alloc.alloc(u8, 100);
    defer alloc.free(slice);

    try std.testing.expectEqual(@as(usize, 100), slice.len);
}

test "Allocator: aligned allocation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var alloc = Allocator.init(gpa.allocator());

    const slice = try alloc.alignedAlloc(u8, 16, 100);
    defer alloc.free(slice);

    try std.testing.expect(isAligned(@intFromPtr(slice.ptr), 16));
}

test "Allocator: create/destroy" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var alloc = Allocator.init(gpa.allocator());

    const ptr = try alloc.create(u32);
    defer alloc.destroy(ptr);

    ptr.* = 42;
    try std.testing.expectEqual(@as(u32, 42), ptr.*);
}

test "Allocator: dupe" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var alloc = Allocator.init(gpa.allocator());

    const original = [_]u8{ 1, 2, 3, 4, 5 };
    const duped = try alloc.dupe(u8, &original);
    defer alloc.free(duped);

    try std.testing.expectEqualSlices(u8, &original, duped);
}

test "alignedSize" {
    try std.testing.expectEqual(@as(usize, 16), alignedSize(10, 16));
    try std.testing.expectEqual(@as(usize, 16), alignedSize(16, 16));
    try std.testing.expectEqual(@as(usize, 32), alignedSize(17, 16));
}

test "isAligned" {
    try std.testing.expect(isAligned(16, 16));
    try std.testing.expect(isAligned(32, 16));
    try std.testing.expect(!isAligned(17, 16));
}

test "paddingNeeded" {
    try std.testing.expectEqual(@as(usize, 0), paddingNeeded(16, 16));
    try std.testing.expectEqual(@as(usize, 15), paddingNeeded(17, 16));
    try std.testing.expectEqual(@as(usize, 8), paddingNeeded(8, 16));
}
