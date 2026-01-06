// ============================================================
// فایل: src/pool.zig
// Object Pool - High-performance object reuse
// ============================================================

const std = @import("std");

/// Object pool برای reuse کردن objects
pub fn Pool(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        available: std.ArrayList(*T),
        capacity: usize,
        acquired_count: usize,

        const Self = @This();

        /// ایجاد pool جدید
        pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
            var available = std.ArrayList(*T){};

            // Pre-allocate objects
            try available.ensureTotalCapacity(allocator, capacity);

            var i: usize = 0;
            while (i < capacity) : (i += 1) {
                const item = try allocator.create(T);
                try available.append(allocator, item);
            }

            return Self{
                .allocator = allocator,
                .available = available,
                .capacity = capacity,
                .acquired_count = 0,
            };
        }

        /// آزادسازی pool
        pub fn deinit(self: *Self) void {
            // Free all available items
            for (self.available.items) |item| {
                self.allocator.destroy(item);
            }
            self.available.deinit(self.allocator);
        }

        /// دریافت یک object از pool
        pub fn acquire(self: *Self) !*T {
            const item = self.available.pop() orelse {
                // اگر pool خالی است، object جدید بسازیم
                const new_item = try self.allocator.create(T);
                self.acquired_count += 1;
                return new_item;
            };
            self.acquired_count += 1;
            return item;
        }

        /// بازگرداندن object به pool
        pub fn release(self: *Self, item: *T) void {
            if (self.available.items.len < self.capacity) {
                self.available.append(self.allocator, item) catch {
                    // اگر نتوانستیم به pool برگردانیم، destroy کنیم
                    self.allocator.destroy(item);
                    if (self.acquired_count > 0) {
                        self.acquired_count -= 1;
                    }
                    return;
                };
                if (self.acquired_count > 0) {
                    self.acquired_count -= 1;
                }
            } else {
                // Pool پر است، destroy کنیم
                self.allocator.destroy(item);
                if (self.acquired_count > 0) {
                    self.acquired_count -= 1;
                }
            }
        }

        /// دریافت تعداد objects موجود
        pub fn availableCount(self: Self) usize {
            return self.available.items.len;
        }

        /// دریافت تعداد objects در استفاده
        pub fn inUseCount(self: Self) usize {
            return self.acquired_count;
        }

        /// Reset pool (آزادسازی همه)
        pub fn reset(self: *Self) void {
            for (self.available.items) |item| {
                self.allocator.destroy(item);
            }
            self.available.clearRetainingCapacity();
            self.acquired_count = 0;
        }
    };
}

/// Pool with initialization
pub fn PoolWithInit(comptime T: type, comptime init_fn: fn (*T) void) type {
    return struct {
        pool: Pool(T),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
            return Self{
                .pool = try Pool(T).init(allocator, capacity),
            };
        }

        pub fn deinit(self: *Self) void {
            self.pool.deinit();
        }

        pub fn acquire(self: *Self) !*T {
            const item = try self.pool.acquire();
            init_fn(item);
            return item;
        }

        pub fn release(self: *Self, item: *T) void {
            self.pool.release(item);
        }

        pub fn availableCount(self: Self) usize {
            return self.pool.availableCount();
        }

        pub fn inUseCount(self: Self) usize {
            return self.pool.inUseCount();
        }
    };
}

/// Thread-safe Pool
pub fn ThreadSafePool(comptime T: type) type {
    return struct {
        pool: Pool(T),
        mutex: std.Thread.Mutex,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
            return Self{
                .pool = try Pool(T).init(allocator, capacity),
                .mutex = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.pool.deinit();
        }

        pub fn acquire(self: *Self) !*T {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.pool.acquire();
        }

        pub fn release(self: *Self, item: *T) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.pool.release(item);
        }

        pub fn availableCount(self: *Self) usize {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.pool.availableCount();
        }

        pub fn inUseCount(self: *Self) usize {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.pool.inUseCount();
        }
    };
}

// ─────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────

const TestStruct = struct {
    value: u32,
    buffer: [100]u8,
};

test "Pool: basic usage" {
    var pool = try Pool(TestStruct).init(std.testing.allocator, 10);
    defer pool.deinit();

    try std.testing.expectEqual(@as(usize, 10), pool.availableCount());

    const item1 = try pool.acquire();
    try std.testing.expectEqual(@as(usize, 9), pool.availableCount());
    try std.testing.expectEqual(@as(usize, 1), pool.inUseCount());

    item1.value = 42;

    pool.release(item1);
    try std.testing.expectEqual(@as(usize, 10), pool.availableCount());
    try std.testing.expectEqual(@as(usize, 0), pool.inUseCount());
}

test "Pool: multiple acquire/release" {
    var pool = try Pool(u32).init(std.testing.allocator, 5);
    defer pool.deinit();

    const item1 = try pool.acquire();
    const item2 = try pool.acquire();
    const item3 = try pool.acquire();

    try std.testing.expectEqual(@as(usize, 2), pool.availableCount());
    try std.testing.expectEqual(@as(usize, 3), pool.inUseCount());

    pool.release(item1);
    pool.release(item2);
    pool.release(item3);

    try std.testing.expectEqual(@as(usize, 5), pool.availableCount());
    try std.testing.expectEqual(@as(usize, 0), pool.inUseCount());
}

test "Pool: overflow capacity" {
    var pool = try Pool(u32).init(std.testing.allocator, 2);
    defer pool.deinit();

    const item1 = try pool.acquire();
    const item2 = try pool.acquire();
    const item3 = try pool.acquire();

    try std.testing.expectEqual(@as(usize, 0), pool.availableCount());
    try std.testing.expectEqual(@as(usize, 3), pool.inUseCount());

    pool.release(item1);
    pool.release(item2);
    pool.release(item3);

    // فقط 2 تا در pool ذخیره می‌شود
    try std.testing.expectEqual(@as(usize, 2), pool.availableCount());
}

test "Pool: reset" {
    var pool = try Pool(u32).init(std.testing.allocator, 5);
    defer pool.deinit();

    _ = try pool.acquire();
    _ = try pool.acquire();

    pool.reset();

    try std.testing.expectEqual(@as(usize, 0), pool.availableCount());
    try std.testing.expectEqual(@as(usize, 0), pool.inUseCount());
}

test "PoolWithInit: initialization" {
    const TestPool = PoolWithInit(TestStruct, struct {
        fn initItem(item: *TestStruct) void {
            item.value = 999;
            @memset(&item.buffer, 0);
        }
    }.initItem);

    var pool = try TestPool.init(std.testing.allocator, 5);
    defer pool.deinit();

    const item = try pool.acquire();
    try std.testing.expectEqual(@as(u32, 999), item.value);

    pool.release(item);
}
