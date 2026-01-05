// ============================================================
// فایل: src/stats.zig
// Memory Statistics
// ============================================================

const std = @import("std");

/// آمار استفاده از حافظه
pub const Stats = struct {
    /// کل حافظه تخصیص داده شده (bytes)
    total_allocated: usize,

    /// کل حافظه آزاد شده (bytes)
    total_freed: usize,

    /// بیشترین استفاده از حافظه (bytes)
    peak_usage: usize,

    /// حافظه فعلی در استفاده (bytes)
    current_usage: usize,

    /// تعداد تخصیص‌ها
    allocation_count: usize,

    /// تعداد آزادسازی‌ها
    free_count: usize,

    /// تعداد reallocations
    realloc_count: usize,

    /// بزرگترین تخصیص تکی (bytes)
    largest_allocation: usize,

    /// کوچکترین تخصیص تکی (bytes)
    smallest_allocation: usize,

    const Self = @This();

    /// ایجاد Stats خالی
    pub fn init() Self {
        return .{
            .total_allocated = 0,
            .total_freed = 0,
            .peak_usage = 0,
            .current_usage = 0,
            .allocation_count = 0,
            .free_count = 0,
            .realloc_count = 0,
            .largest_allocation = 0,
            .smallest_allocation = std.math.maxInt(usize),
        };
    }

    /// ثبت یک تخصیص
    pub fn recordAlloc(self: *Self, size: usize) void {
        self.total_allocated += size;
        self.current_usage += size;
        self.allocation_count += 1;

        if (self.current_usage > self.peak_usage) {
            self.peak_usage = self.current_usage;
        }

        if (size > self.largest_allocation) {
            self.largest_allocation = size;
        }

        if (size < self.smallest_allocation) {
            self.smallest_allocation = size;
        }
    }

    /// ثبت یک آزادسازی
    pub fn recordFree(self: *Self, size: usize) void {
        self.total_freed += size;
        if (self.current_usage >= size) {
            self.current_usage -= size;
        } else {
            self.current_usage = 0;
        }
        self.free_count += 1;
    }

    /// ثبت یک reallocation
    pub fn recordRealloc(self: *Self, old_size: usize, new_size: usize) void {
        self.realloc_count += 1;

        // Update as free + alloc
        self.recordFree(old_size);
        self.recordAlloc(new_size);
    }

    /// Reset statistics
    pub fn reset(self: *Self) void {
        self.* = Self.init();
    }

    /// درصد استفاده از حافظه
    pub fn utilizationPercent(self: Self) f64 {
        if (self.peak_usage == 0) return 0.0;
        return @as(f64, @floatFromInt(self.current_usage)) /
            @as(f64, @floatFromInt(self.peak_usage)) * 100.0;
    }

    /// میانگین اندازه تخصیص
    pub fn averageAllocationSize(self: Self) usize {
        if (self.allocation_count == 0) return 0;
        return self.total_allocated / self.allocation_count;
    }

    /// درصد fragmentation
    pub fn fragmentationPercent(self: Self) f64 {
        if (self.total_allocated == 0) return 0.0;
        const wasted = self.total_allocated - self.current_usage;
        return @as(f64, @floatFromInt(wasted)) /
            @as(f64, @floatFromInt(self.total_allocated)) * 100.0;
    }

    /// چاپ آمار
    pub fn print(self: Self, writer: anytype) !void {
        try writer.writeAll("╔════════════════════════════════════════════════════════════╗\n");
        try writer.writeAll("║               Memory Statistics                            ║\n");
        try writer.writeAll("╚════════════════════════════════════════════════════════════╝\n");

        try writer.print("Total Allocated:      {d:>10} bytes\n", .{self.total_allocated});
        try writer.print("Total Freed:          {d:>10} bytes\n", .{self.total_freed});
        try writer.print("Current Usage:        {d:>10} bytes\n", .{self.current_usage});
        try writer.print("Peak Usage:           {d:>10} bytes\n", .{self.peak_usage});
        try writer.writeAll("────────────────────────────────────────────────────────────\n");

        try writer.print("Allocation Count:     {d:>10}\n", .{self.allocation_count});
        try writer.print("Free Count:           {d:>10}\n", .{self.free_count});
        try writer.print("Realloc Count:        {d:>10}\n", .{self.realloc_count});
        try writer.writeAll("────────────────────────────────────────────────────────────\n");

        try writer.print("Largest Allocation:   {d:>10} bytes\n", .{self.largest_allocation});
        try writer.print("Smallest Allocation:  {d:>10} bytes\n", .{if (self.smallest_allocation == std.math.maxInt(usize)) 0 else self.smallest_allocation});
        try writer.print("Average Allocation:   {d:>10} bytes\n", .{self.averageAllocationSize()});
        try writer.writeAll("────────────────────────────────────────────────────────────\n");

        try writer.print("Utilization:          {d:>9.2}%\n", .{self.utilizationPercent()});
        try writer.print("Fragmentation:        {d:>9.2}%\n", .{self.fragmentationPercent()});
        try writer.writeAll("────────────────────────────────────────────────────────────\n\n");
    }

    /// Format support
    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("Stats{{ alloc={d}, free={d}, current={d}, peak={d} }}", .{
            self.allocation_count,
            self.free_count,
            self.current_usage,
            self.peak_usage,
        });
    }
};

// ─────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────

test "Stats: basic recording" {
    var stats = Stats.init();

    stats.recordAlloc(100);
    try std.testing.expectEqual(@as(usize, 100), stats.total_allocated);
    try std.testing.expectEqual(@as(usize, 100), stats.current_usage);
    try std.testing.expectEqual(@as(usize, 1), stats.allocation_count);

    stats.recordAlloc(200);
    try std.testing.expectEqual(@as(usize, 300), stats.total_allocated);
    try std.testing.expectEqual(@as(usize, 300), stats.current_usage);
    try std.testing.expectEqual(@as(usize, 300), stats.peak_usage);

    stats.recordFree(100);
    try std.testing.expectEqual(@as(usize, 100), stats.total_freed);
    try std.testing.expectEqual(@as(usize, 200), stats.current_usage);
    try std.testing.expectEqual(@as(usize, 1), stats.free_count);
}

test "Stats: peak tracking" {
    var stats = Stats.init();

    stats.recordAlloc(1000);
    try std.testing.expectEqual(@as(usize, 1000), stats.peak_usage);

    stats.recordFree(500);
    try std.testing.expectEqual(@as(usize, 1000), stats.peak_usage);

    stats.recordAlloc(300);
    try std.testing.expectEqual(@as(usize, 1000), stats.peak_usage);
}

test "Stats: calculations" {
    var stats = Stats.init();

    stats.recordAlloc(100);
    stats.recordAlloc(200);
    stats.recordAlloc(300);

    try std.testing.expectEqual(@as(usize, 200), stats.averageAllocationSize());
    try std.testing.expectEqual(@as(usize, 300), stats.largest_allocation);
    try std.testing.expectEqual(@as(usize, 100), stats.smallest_allocation);
}

test "Stats: reset" {
    var stats = Stats.init();

    stats.recordAlloc(1000);
    stats.recordFree(500);

    stats.reset();

    try std.testing.expectEqual(@as(usize, 0), stats.total_allocated);
    try std.testing.expectEqual(@as(usize, 0), stats.current_usage);
    try std.testing.expectEqual(@as(usize, 0), stats.allocation_count);
}
