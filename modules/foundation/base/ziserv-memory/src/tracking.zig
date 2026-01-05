// ============================================================
// فایل: src/tracking.zig
// Memory Tracking - Debug and profiling
// ============================================================

const std = @import("std");
const Stats = @import("stats.zig").Stats;

/// Allocation info برای tracking
const AllocationInfo = struct {
    address: usize,
    size: usize,
    source_location: std.builtin.SourceLocation,
};

/// Tracker برای debug و profiling
pub const Tracker = struct {
    child: std.mem.Allocator,
    stats: Stats,
    allocations: std.AutoHashMap(usize, AllocationInfo),
    mutex: std.Thread.Mutex,

    const Self = @This();

    pub fn init(child: std.mem.Allocator) Self {
        return .{
            .child = child,
            .stats = Stats.init(),
            .allocations = std.AutoHashMap(usize, AllocationInfo).init(child),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocations.deinit();
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

        const result = self.child.rawAlloc(len, ptr_align, ret_addr) orelse return null;

        self.mutex.lock();
        defer self.mutex.unlock();

        self.stats.recordAlloc(len);

        const addr = @intFromPtr(result);
        self.allocations.put(addr, .{
            .address = addr,
            .size = len,
            .source_location = @src(),
        }) catch {};

        return result;
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: u8,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const result = self.child.rawResize(buf, buf_align, new_len, ret_addr);

        if (result) {
            self.mutex.lock();
            defer self.mutex.unlock();

            self.stats.recordRealloc(buf.len, new_len);

            const addr = @intFromPtr(buf.ptr);
            if (self.allocations.get(addr)) |info| {
                self.allocations.put(addr, .{
                    .address = addr,
                    .size = new_len,
                    .source_location = info.source_location,
                }) catch {};
            }
        }

        return result;
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

        const addr = @intFromPtr(buf.ptr);
        if (self.allocations.fetchRemove(addr)) |kv| {
            self.stats.recordFree(kv.value.size);
        }

        self.child.rawFree(buf, buf_align, ret_addr);
    }

    /// دریافت آمار
    pub fn report(self: *Self) Stats {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.stats;
    }

    /// چک کردن memory leaks
    pub fn check_leaks(self: *Self, writer: anytype) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.allocations.count() == 0) {
            return false;
        }

        try writer.print("\n⚠️  Memory Leaks Detected: {d} allocations not freed\n", .{
            self.allocations.count(),
        });

        var iter = self.allocations.iterator();
        var count: usize = 0;
        while (iter.next()) |entry| {
            count += 1;
            if (count <= 10) {
                try writer.print("  Leak {d}: {d} bytes at 0x{x} ({}:{}:{})\n", .{
                    count,
                    entry.value_ptr.size,
                    entry.value_ptr.address,
                    entry.value_ptr.source_location.file,
                    entry.value_ptr.source_location.line,
                    entry.value_ptr.source_location.column,
                });
            }
        }

        if (count > 10) {
            try writer.print("  ... and {d} more\n", .{count - 10});
        }

        return true;
    }

    /// Reset tracking
    pub fn reset(self: *Self) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.stats.reset();
        self.allocations.clearRetainingCapacity();
    }
};

/// Simple leak detector
pub const LeakDetector = struct {
    tracker: Tracker,

    const Self = @This();

    pub fn init(child: std.mem.Allocator) Self {
        return .{
            .tracker = Tracker.init(child),
        };
    }

    pub fn deinit(self: *Self) void {
        self.tracker.deinit();
    }

    pub fn allocator(self: *Self) std.mem.Allocator {
        return self.tracker.allocator();
    }

    pub fn check(self: *Self) !void {
        const stdout = std.io.getStdOut().writer();
        if (try self.tracker.check_leaks(stdout)) {
            return error.MemoryLeak;
        }
    }
};

// ─────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────

test "Tracker: basic tracking" {
    var tracker = Tracker.init(std.testing.allocator);
    defer tracker.deinit();

    const alloc = tracker.allocator();

    const slice1 = try alloc.alloc(u8, 100);
    const slice2 = try alloc.alloc(u32, 50);

    const stats = tracker.report();
    try std.testing.expect(stats.allocation_count >= 2);
    try std.testing.expect(stats.current_usage >= 100 + 50 * @sizeOf(u32));

    alloc.free(slice1);
    alloc.free(slice2);

    const final_stats = tracker.report();
    try std.testing.expectEqual(@as(usize, 0), final_stats.current_usage);
}

test "Tracker: leak detection" {
    var tracker = Tracker.init(std.testing.allocator);
    defer tracker.deinit();

    const alloc = tracker.allocator();

    _ = try alloc.alloc(u8, 100);

    // Intentional leak - don't free

    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    const has_leaks = try tracker.check_leaks(buffer.writer());
    try std.testing.expect(has_leaks);
}

test "Tracker: stats accuracy" {
    var tracker = Tracker.init(std.testing.allocator);
    defer tracker.deinit();

    const alloc = tracker.allocator();

    const slice1 = try alloc.alloc(u8, 1000);
    const slice2 = try alloc.alloc(u8, 2000);

    var stats = tracker.report();
    try std.testing.expectEqual(@as(usize, 2), stats.allocation_count);
    try std.testing.expectEqual(@as(usize, 3000), stats.total_allocated);

    alloc.free(slice1);

    stats = tracker.report();
    try std.testing.expectEqual(@as(usize, 1), stats.free_count);
    try std.testing.expectEqual(@as(usize, 2000), stats.current_usage);

    alloc.free(slice2);

    stats = tracker.report();
    try std.testing.expectEqual(@as(usize, 0), stats.current_usage);
}

test "LeakDetector: no leaks" {
    var detector = LeakDetector.init(std.testing.allocator);
    defer detector.deinit();

    const alloc = detector.allocator();

    const slice = try alloc.alloc(u8, 100);
    alloc.free(slice);

    try detector.check();
}
