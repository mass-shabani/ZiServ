// ============================================================
// فایل: modules/foundation/ziserv-core/src/memory.zig
// ابزارهای مدیریت حافظه
// ============================================================

const std = @import("std");

/// Arena Allocator wrapper
pub const Arena = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init(child: std.mem.Allocator) Arena {
        return .{
            .arena = std.heap.ArenaAllocator.init(child),
        };
    }

    pub fn deinit(self: *Arena) void {
        self.arena.deinit();
    }

    pub fn allocator(self: *Arena) std.mem.Allocator {
        return self.arena.allocator();
    }

    pub fn reset(self: *Arena) void {
        _ = self.arena.reset(.retain_capacity);
    }
};

/// Pool allocator ساده
pub fn Pool(comptime T: type, comptime size: usize) type {
    return struct {
        items: [size]T,
        used: [size]bool,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .items = undefined,
                .used = [_]bool{false} ** size,
                .allocator = allocator,
            };
        }

        pub fn acquire(self: *Self) ?*T {
            for (&self.used, 0..) |*is_used, i| {
                if (!is_used.*) {
                    is_used.* = true;
                    return &self.items[i];
                }
            }
            return null;
        }

        pub fn release(self: *Self, item: *T) void {
            const index = (@intFromPtr(item) - @intFromPtr(&self.items[0])) / @sizeOf(T);
            if (index < size) {
                self.used[index] = false;
            }
        }

        pub fn available(self: *const Self) usize {
            var count: usize = 0;
            for (self.used) |is_used| {
                if (!is_used) count += 1;
            }
            return count;
        }
    };
}

/// آمار حافظه
pub const MemoryStats = struct {
    allocated: usize,
    freed: usize,
    peak: usize,
    allocations: usize,

    pub fn init() MemoryStats {
        return .{
            .allocated = 0,
            .freed = 0,
            .peak = 0,
            .allocations = 0,
        };
    }

    pub fn current(self: MemoryStats) usize {
        return self.allocated - self.freed;
    }
};

test "arena allocator" {
    var arena = Arena.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();
    const slice = try alloc.alloc(u8, 100);
    try std.testing.expectEqual(@as(usize, 100), slice.len);
}

test "pool allocator" {
    var pool = Pool(i32, 10).init(std.testing.allocator);

    const item1 = pool.acquire();
    try std.testing.expect(item1 != null);

    const item2 = pool.acquire();
    try std.testing.expect(item2 != null);

    try std.testing.expectEqual(@as(usize, 8), pool.available());

    pool.release(item1.?);
    try std.testing.expectEqual(@as(usize, 9), pool.available());
}
