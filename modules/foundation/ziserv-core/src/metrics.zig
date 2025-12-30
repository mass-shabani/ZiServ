// ============================================================
// فایل: modules/foundation/ziserv-core/src/metrics.zig
// سیستم Metrics/Telemetry با performance بالا
// ============================================================

const std = @import("std");
const time = @import("time.zig");

/// نوع metric
pub const MetricType = enum {
    counter, // مقدار افزایشی
    gauge, // مقدار فعلی
    histogram, // توزیع مقادیر
    summary, // خلاصه آماری
};

/// واحد اندازه‌گیری
pub const Unit = enum {
    none,
    bytes,
    seconds,
    milliseconds,
    microseconds,
    nanoseconds,
    count,
    percent,

    pub fn toString(self: Unit) []const u8 {
        return switch (self) {
            .none => "",
            .bytes => "bytes",
            .seconds => "s",
            .milliseconds => "ms",
            .microseconds => "us",
            .nanoseconds => "ns",
            .count => "count",
            .percent => "%",
        };
    }
};

/// Counter - مقدار افزایشی
pub const Counter = struct {
    value: std.atomic.Value(u64),
    name: []const u8,
    description: []const u8,
    unit: Unit,

    pub fn init(name: []const u8, description: []const u8, unit: Unit) Counter {
        return .{
            .value = std.atomic.Value(u64).init(0),
            .name = name,
            .description = description,
            .unit = unit,
        };
    }

    pub inline fn inc(self: *Counter) void {
        _ = self.value.fetchAdd(1, .monotonic);
    }

    pub inline fn add(self: *Counter, delta: u64) void {
        _ = self.value.fetchAdd(delta, .monotonic);
    }

    pub inline fn get(self: *const Counter) u64 {
        return self.value.load(.monotonic);
    }

    pub fn reset(self: *Counter) void {
        self.value.store(0, .monotonic);
    }
};

/// Gauge - مقدار فعلی
pub const Gauge = struct {
    value: std.atomic.Value(i64),
    name: []const u8,
    description: []const u8,
    unit: Unit,

    pub fn init(name: []const u8, description: []const u8, unit: Unit) Gauge {
        return .{
            .value = std.atomic.Value(i64).init(0),
            .name = name,
            .description = description,
            .unit = unit,
        };
    }

    pub inline fn set(self: *Gauge, val: i64) void {
        self.value.store(val, .monotonic);
    }

    pub inline fn inc(self: *Gauge) void {
        _ = self.value.fetchAdd(1, .monotonic);
    }

    pub inline fn dec(self: *Gauge) void {
        _ = self.value.fetchSub(1, .monotonic);
    }

    pub inline fn add(self: *Gauge, delta: i64) void {
        _ = self.value.fetchAdd(delta, .monotonic);
    }

    pub inline fn sub(self: *Gauge, delta: i64) void {
        _ = self.value.fetchSub(delta, .monotonic);
    }

    pub inline fn get(self: *const Gauge) i64 {
        return self.value.load(.monotonic);
    }
};

/// Histogram bucket
pub const HistogramBucket = struct {
    upper_bound: f64,
    count: std.atomic.Value(u64),

    pub fn init(upper_bound: f64) HistogramBucket {
        return .{
            .upper_bound = upper_bound,
            .count = std.atomic.Value(u64).init(0),
        };
    }
};

/// Histogram - توزیع مقادیر
pub const Histogram = struct {
    name: []const u8,
    description: []const u8,
    unit: Unit,
    buckets: []HistogramBucket,
    sum: std.atomic.Value(u64),
    count: std.atomic.Value(u64),
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        description: []const u8,
        unit: Unit,
        buckets: []const f64,
    ) !Histogram {
        const bucket_list = try allocator.alloc(HistogramBucket, buckets.len);
        for (buckets, 0..) |bound, i| {
            bucket_list[i] = HistogramBucket.init(bound);
        }

        return .{
            .name = name,
            .description = description,
            .unit = unit,
            .buckets = bucket_list,
            .sum = std.atomic.Value(u64).init(0),
            .count = std.atomic.Value(u64).init(0),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Histogram) void {
        self.allocator.free(self.buckets);
    }

    pub fn observe(self: *Histogram, value: f64) void {
        _ = self.count.fetchAdd(1, .monotonic);
        _ = self.sum.fetchAdd(@as(u64, @intFromFloat(value * 1000)), .monotonic);

        for (self.buckets) |*bucket| {
            if (value <= bucket.upper_bound) {
                _ = bucket.count.fetchAdd(1, .monotonic);
            }
        }
    }

    pub fn getSum(self: *const Histogram) f64 {
        return @as(f64, @floatFromInt(self.sum.load(.monotonic))) / 1000.0;
    }

    pub fn getCount(self: *const Histogram) u64 {
        return self.count.load(.monotonic);
    }

    pub fn getMean(self: *const Histogram) f64 {
        const cnt = self.getCount();
        if (cnt == 0) return 0;
        return self.getSum() / @as(f64, @floatFromInt(cnt));
    }
};

/// Summary statistics
pub const Summary = struct {
    name: []const u8,
    description: []const u8,
    unit: Unit,
    sum: std.atomic.Value(u64),
    count: std.atomic.Value(u64),
    min: std.atomic.Value(u64),
    max: std.atomic.Value(u64),

    pub fn init(name: []const u8, description: []const u8, unit: Unit) Summary {
        return .{
            .name = name,
            .description = description,
            .unit = unit,
            .sum = std.atomic.Value(u64).init(0),
            .count = std.atomic.Value(u64).init(0),
            .min = std.atomic.Value(u64).init(std.math.maxInt(u64)),
            .max = std.atomic.Value(u64).init(0),
        };
    }

    pub fn observe(self: *Summary, value: u64) void {
        _ = self.sum.fetchAdd(value, .monotonic);
        _ = self.count.fetchAdd(1, .monotonic);

        // Update min
        var current_min = self.min.load(.monotonic);
        while (value < current_min) {
            current_min = self.min.cmpxchgWeak(
                current_min,
                value,
                .monotonic,
                .monotonic,
            ) orelse break;
        }

        // Update max
        var current_max = self.max.load(.monotonic);
        while (value > current_max) {
            current_max = self.max.cmpxchgWeak(
                current_max,
                value,
                .monotonic,
                .monotonic,
            ) orelse break;
        }
    }

    pub fn getSum(self: *const Summary) u64 {
        return self.sum.load(.monotonic);
    }

    pub fn getCount(self: *const Summary) u64 {
        return self.count.load(.monotonic);
    }

    pub fn getMin(self: *const Summary) u64 {
        const val = self.min.load(.monotonic);
        return if (val == std.math.maxInt(u64)) 0 else val;
    }

    pub fn getMax(self: *const Summary) u64 {
        return self.max.load(.monotonic);
    }

    pub fn getMean(self: *const Summary) f64 {
        const cnt = self.getCount();
        if (cnt == 0) return 0;
        return @as(f64, @floatFromInt(self.getSum())) / @as(f64, @floatFromInt(cnt));
    }

    pub fn reset(self: *Summary) void {
        self.sum.store(0, .monotonic);
        self.count.store(0, .monotonic);
        self.min.store(std.math.maxInt(u64), .monotonic);
        self.max.store(0, .monotonic);
    }
};

/// Timer - اندازه‌گیری زمان
pub const Timer = struct {
    histogram: *Histogram,
    start_time: i128,

    pub fn start(histogram: *Histogram) Timer {
        return .{
            .histogram = histogram,
            .start_time = std.time.nanoTimestamp(),
        };
    }

    pub fn stop(self: *Timer) void {
        const elapsed = std.time.nanoTimestamp() - self.start_time;
        const ms = @as(f64, @floatFromInt(elapsed)) / 1_000_000.0;
        self.histogram.observe(ms);
    }

    pub fn stopAndRecord(self: *Timer) f64 {
        const elapsed = std.time.nanoTimestamp() - self.start_time;
        const ms = @as(f64, @floatFromInt(elapsed)) / 1_000_000.0;
        self.histogram.observe(ms);
        return ms;
    }
};

/// Metrics Registry
pub const MetricsRegistry = struct {
    counters: std.StringHashMap(*Counter),
    gauges: std.StringHashMap(*Gauge),
    histograms: std.StringHashMap(*Histogram),
    summaries: std.StringHashMap(*Summary),
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) MetricsRegistry {
        return .{
            .counters = std.StringHashMap(*Counter).init(allocator),
            .gauges = std.StringHashMap(*Gauge).init(allocator),
            .histograms = std.StringHashMap(*Histogram).init(allocator),
            .summaries = std.StringHashMap(*Summary).init(allocator),
            .allocator = allocator,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *MetricsRegistry) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var counter_it = self.counters.valueIterator();
        while (counter_it.next()) |c| {
            self.allocator.destroy(c.*);
        }
        self.counters.deinit();

        var gauge_it = self.gauges.valueIterator();
        while (gauge_it.next()) |g| {
            self.allocator.destroy(g.*);
        }
        self.gauges.deinit();

        var histogram_it = self.histograms.valueIterator();
        while (histogram_it.next()) |h| {
            h.*.deinit();
            self.allocator.destroy(h.*);
        }
        self.histograms.deinit();

        var summary_it = self.summaries.valueIterator();
        while (summary_it.next()) |s| {
            self.allocator.destroy(s.*);
        }
        self.summaries.deinit();
    }

    pub fn registerCounter(
        self: *MetricsRegistry,
        name: []const u8,
        description: []const u8,
        unit: Unit,
    ) !*Counter {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.counters.get(name)) |c| return c;

        const counter = try self.allocator.create(Counter);
        counter.* = Counter.init(name, description, unit);
        try self.counters.put(name, counter);
        return counter;
    }

    pub fn registerGauge(
        self: *MetricsRegistry,
        name: []const u8,
        description: []const u8,
        unit: Unit,
    ) !*Gauge {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.gauges.get(name)) |g| return g;

        const gauge = try self.allocator.create(Gauge);
        gauge.* = Gauge.init(name, description, unit);
        try self.gauges.put(name, gauge);
        return gauge;
    }

    pub fn registerHistogram(
        self: *MetricsRegistry,
        name: []const u8,
        description: []const u8,
        unit: Unit,
        buckets: []const f64,
    ) !*Histogram {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.histograms.get(name)) |h| return h;

        const histogram = try self.allocator.create(Histogram);
        histogram.* = try Histogram.init(self.allocator, name, description, unit, buckets);
        try self.histograms.put(name, histogram);
        return histogram;
    }

    pub fn registerSummary(
        self: *MetricsRegistry,
        name: []const u8,
        description: []const u8,
        unit: Unit,
    ) !*Summary {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.summaries.get(name)) |s| return s;

        const summary = try self.allocator.create(Summary);
        summary.* = Summary.init(name, description, unit);
        try self.summaries.put(name, summary);
        return summary;
    }

    pub fn getCounter(self: *MetricsRegistry, name: []const u8) ?*Counter {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.counters.get(name);
    }

    pub fn getGauge(self: *MetricsRegistry, name: []const u8) ?*Gauge {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.gauges.get(name);
    }

    pub fn getHistogram(self: *MetricsRegistry, name: []const u8) ?*Histogram {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.histograms.get(name);
    }

    pub fn getSummary(self: *MetricsRegistry, name: []const u8) ?*Summary {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.summaries.get(name);
    }

    /// Export metrics به فرمت Prometheus
    pub fn exportPrometheus(self: *MetricsRegistry, writer: anytype) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Counters
        var counter_it = self.counters.iterator();
        while (counter_it.next()) |entry| {
            const c = entry.value_ptr.*;
            try writer.print("# HELP {s} {s}\n", .{ c.name, c.description });
            try writer.print("# TYPE {s} counter\n", .{c.name});
            try writer.print("{s} {d}\n\n", .{ c.name, c.get() });
        }

        // Gauges
        var gauge_it = self.gauges.iterator();
        while (gauge_it.next()) |entry| {
            const g = entry.value_ptr.*;
            try writer.print("# HELP {s} {s}\n", .{ g.name, g.description });
            try writer.print("# TYPE {s} gauge\n", .{g.name});
            try writer.print("{s} {d}\n\n", .{ g.name, g.get() });
        }

        // Histograms
        var histogram_it = self.histograms.iterator();
        while (histogram_it.next()) |entry| {
            const h = entry.value_ptr.*;
            try writer.print("# HELP {s} {s}\n", .{ h.name, h.description });
            try writer.print("# TYPE {s} histogram\n", .{h.name});

            for (h.buckets) |bucket| {
                try writer.print("{s}_bucket{{le=\"{d}\"}} {d}\n", .{
                    h.name,
                    bucket.upper_bound,
                    bucket.count.load(.monotonic),
                });
            }

            try writer.print("{s}_sum {d}\n", .{ h.name, h.getSum() });
            try writer.print("{s}_count {d}\n\n", .{ h.name, h.getCount() });
        }

        // Summaries
        var summary_it = self.summaries.iterator();
        while (summary_it.next()) |entry| {
            const s = entry.value_ptr.*;
            try writer.print("# HELP {s} {s}\n", .{ s.name, s.description });
            try writer.print("# TYPE {s} summary\n", .{s.name});
            try writer.print("{s}_sum {d}\n", .{ s.name, s.getSum() });
            try writer.print("{s}_count {d}\n", .{ s.name, s.getCount() });
            try writer.print("{s}_min {d}\n", .{ s.name, s.getMin() });
            try writer.print("{s}_max {d}\n", .{ s.name, s.getMax() });
            try writer.print("{s}_mean {d}\n\n", .{ s.name, s.getMean() });
        }
    }
};

/// Global metrics registry
var global_registry: ?*MetricsRegistry = null;

pub fn setGlobalRegistry(registry: *MetricsRegistry) void {
    global_registry = registry;
}

pub fn getGlobalRegistry() ?*MetricsRegistry {
    return global_registry;
}

test "counter" {
    var counter = Counter.init("test_counter", "Test counter", .count);

    counter.inc();
    counter.add(5);

    try std.testing.expectEqual(@as(u64, 6), counter.get());
}

test "gauge" {
    var gauge = Gauge.init("test_gauge", "Test gauge", .bytes);

    gauge.set(100);
    gauge.inc();
    gauge.dec();

    try std.testing.expectEqual(@as(i64, 100), gauge.get());
}

test "histogram" {
    const buckets = [_]f64{ 10, 50, 100, 500, 1000 };
    var histogram = try Histogram.init(
        std.testing.allocator,
        "test_histogram",
        "Test histogram",
        .milliseconds,
        &buckets,
    );
    defer histogram.deinit();

    histogram.observe(25);
    histogram.observe(75);
    histogram.observe(150);

    try std.testing.expectEqual(@as(u64, 3), histogram.getCount());
    try std.testing.expect(histogram.getMean() > 0);
}

test "summary" {
    var summary = Summary.init("test_summary", "Test summary", .milliseconds);

    summary.observe(100);
    summary.observe(200);
    summary.observe(300);

    try std.testing.expectEqual(@as(u64, 100), summary.getMin());
    try std.testing.expectEqual(@as(u64, 300), summary.getMax());
    try std.testing.expectEqual(@as(u64, 3), summary.getCount());
}
