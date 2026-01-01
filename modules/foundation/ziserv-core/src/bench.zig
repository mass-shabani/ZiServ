// ============================================================
// فایل: modules/foundation/ziserv-core/src/bench.zig
// Benchmarks - ارزیابی عملکرد ماژول Core (نهایی)
// ============================================================

const std = @import("std");
const core = @import("root.zig");

// خطای تست
const BenchError = error{TestError};

// تابع کمکی برای پرینت هدر
fn printHeader(title: []const u8) void {
    std.debug.print("\n=== {s} ===\n", .{title});
}

// 1. Benchmark تشخیص پلتفرم
fn benchPlatform(iterations: usize) !void {
    printHeader("Platform Detection");
    var timer = core.time.Stopwatch.init();

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = core.PlatformInfo.current();
    }
    timer.stop();

    const ms = timer.elapsedMs();
    const ops_per_sec = if (ms > 0) @divTrunc(@as(i128, iterations * @sizeOf(core.PlatformInfo)), @as(i128, ms * 1_000_000)) else 0;

    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  Time: {d} ms\n", .{ms});
    std.debug.print("  Speed: {d} ops/s (approx)\n", .{ops_per_sec});
}

// 2. Benchmark سربار تایمر
fn benchStopwatch(iterations: usize) !void {
    printHeader("Stopwatch Overhead");

    var timer = core.time.Stopwatch.init();
    timer.start();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var t = core.time.Stopwatch.init();
        t.start();
        t.stop();
    }

    timer.stop();
    const ms = timer.elapsedMs();
    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  Time: {d} ms\n", .{ms});
    std.debug.print("  Note: Measures init/start/stop cost\n", .{});
}

// 3. Benchmark Logger (اصلاح شده برای Var و Allocator در Main)
fn benchLogger(iterations: usize, allocator: std.mem.Allocator) !void {
    printHeader("Logger Performance");
    const msg = "Benchmark log message with some data: {d}";
    const data: i32 = 42;

    // تعریف آرایه با var و undefined برای حل مشکل const/mutex
    const LogStruct = struct { name: []const u8, logger: core.Logger };
    var loggers: [3]LogStruct = undefined;

    // مقداردهی دستی (چون try وجود دارد نمی‌توان از inline const استفاده کرد)
    loggers[0] = .{ .name = "Text", .logger = try setupLogger(allocator, .text) };
    loggers[1] = .{ .name = "JSON", .logger = try setupLogger(allocator, .json) };
    loggers[2] = .{ .name = "Colored", .logger = try setupLogger(allocator, .colored) };

    // استفاده از &loggers برای گرفتن ارجنس mutable
    for (&loggers) |*l| {
        defer l.logger.deinit();

        var timer = core.time.Stopwatch.init();
        timer.start();

        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            l.logger.info(msg, .{data});
        }

        timer.stop();

        const ms = timer.elapsedMs();
        std.debug.print("  [{s}]: {d} ms for {d} logs", .{ l.name, ms, iterations });

        if (ms > 0) {
            const bytes: u64 = @intCast(iterations * (msg.len + 10));
            const mbps = @as(f64, @floatFromInt(@as(u64, bytes))) * 8.0 / (1024.0 * 1024.0) / (@as(f64, @floatFromInt(@as(u64, @intCast(ms)))) / 1000.0);
            std.debug.print("  [{s}]: Speed: {d:.2} MB/s", .{ l.name, mbps });
        } else {
            std.debug.print("  [{s}]: Too fast to measure", .{l.name});
        }
    }
}

// تابع کمکی برای ساخت Logger (تغییر: دریافت allocator)
fn setupLogger(allocator: std.mem.Allocator, fmt: core.LogFormat) !core.Logger {
    var log = core.Logger.init(allocator, .{
        .level = .info,
        .format = fmt,
        .show_timestamp = false,
        .show_source = false,
    });

    // ساختن Sink روی Heap
    const sink = try allocator.create(core.ConsoleSink);
    sink.* = core.ConsoleSink.init(allocator, .{}, std.fs.File.stdout());
    try log.addSink(sink.sink());

    return log;
}

// 4. Benchmark Result Type
fn benchResult(iterations: usize) !void {
    printHeader("Result Type Overhead");

    var sum_native: i64 = 0;
    var sum_result: i64 = 0;

    var timer_native = core.time.Stopwatch.init();
    timer_native.start();
    {
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const val: i32 = 100;
            sum_native += val;
        }
    }
    timer_native.stop();

    var timer_result = core.time.Stopwatch.init();
    timer_result.start();
    {
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const res: core.Result(i32, BenchError) = core.Result(i32, BenchError){ .ok = 100 };
            if (res.isOk()) {
                sum_result += res.unwrap();
            }
        }
    }
    timer_result.stop();

    const ms_native = timer_native.elapsedMs();
    const ms_result = timer_result.elapsedMs();

    std.debug.print("  Native (i32):     {d} ms (Sum: {d})\n", .{ ms_native, sum_native });
    std.debug.print("  Result(i32, E): {d} ms (Sum: {d})\n", .{ ms_result, sum_result });

    if (ms_result > ms_native) {
        // اصلاح شد: استفاده از @floatFromInt و تفریق ساده برای اطمینان
        const overhead: f64 = @as(f64, @floatFromInt(ms_result - ms_native));
        const overhead_pct: f64 = (overhead * 100.0) / @as(f64, @floatFromInt(ms_native));
        std.debug.print("  Overhead: {d} ms ({d:.2}% slower)\n", .{ overhead, overhead_pct });
    } else {
        std.debug.print("  Overhead: Negligible\n", .{});
    }
}

// 5. Benchmark Features
fn benchFeatures(iterations: usize, allocator: std.mem.Allocator) !void {
    printHeader("Feature Flags Lookup");
    var flags = core.FeatureFlags.init(allocator);
    defer flags.deinit();

    try flags.register("benchmark_feature", "A benchmark feature", .{ .boolean = true }, false);
    try flags.register("int_feature", "Integer feature", .{ .integer = 42 }, false);

    var timer = core.time.Stopwatch.init();
    timer.start();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = flags.isEnabled("benchmark_feature");
        _ = flags.getValue("int_feature");
    }

    timer.stop();
    const ms = timer.elapsedMs();
    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  Time: {d} ms\n", .{ms});
    std.debug.print("  Ops/s: {d}\n", .{if (ms > 0) @divTrunc(@as(i128, iterations * 2), @as(i128, ms * 1_000_000)) else 0});
}

// 6. Benchmark Metrics
fn benchMetrics(iterations: usize, allocator: std.mem.Allocator) !void {
    printHeader("Metrics Registry (Counter/Gauge)");

    var registry = core.MetricsRegistry.init(allocator);
    defer registry.deinit();

    const counter = try registry.registerCounter("test_counter", "Test counter", .count);
    const gauge = try registry.registerGauge("test_gauge", "Test gauge", .none);

    {
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            counter.inc();
            gauge.set(42);
        }
    }

    var timer = core.time.Stopwatch.init();
    timer.start();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        counter.inc();
        if (i % 10 == 0) {
            gauge.set(@as(i64, @intCast(i % 100)));
        }
    }

    timer.stop();

    const ms = timer.elapsedMs();
    std.debug.print("  Iterations: {d}\n", .{iterations});
    std.debug.print("  Time: {d} ms\n", .{ms});
    std.debug.print("  Counter: {d}\n", .{counter.get()});
    std.debug.print("  Gauge: {d}\n", .{gauge.get()});

    const ops = @as(i128, iterations * 2);
    std.debug.print("  Ops/s: {d}\n", .{if (ms > 0) @divTrunc(ops, @as(i128, ms * 1_000_000)) else 0});
}

// 7. Benchmark Baseline
fn baselineFib(n: usize) usize {
    if (n <= 1) return n;
    return baselineFib(n - 1) + baselineFib(n - 2);
}

fn benchBaseline() !void {
    printHeader("Baseline CPU (Fibonacci N=40)");
    const n = 40;
    var timer = core.time.Stopwatch.init();
    timer.start();

    const res = baselineFib(n);

    timer.stop();
    std.debug.print("  Result: {d}\n", .{res});
    std.debug.print("  Time: {d} ns\n", .{timer.elapsedNs()});
}

pub fn main() !void {
    std.debug.print("\n====================================================================\n", .{});
    std.debug.print("  ZiServ Core - Comprehensive Benchmarks\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("\n", .{});

    const iterations = 100_000;

    // اصلاح شد: حذف آرگومان دوم .{} در نسخه 0.15.2
    var gpa = std.heap.GeneralPurposeAllocator(.{}){
        .backing_allocator = std.heap.page_allocator,
    };

    try benchPlatform(iterations * 10);
    try benchBaseline();
    try benchStopwatch(iterations * 100);
    try benchResult(iterations);
    try benchFeatures(iterations, gpa.allocator());
    try benchMetrics(iterations, gpa.allocator());
    try benchLogger(iterations / 1000, gpa.allocator());

    std.debug.print("\n====================================================================\n", .{});
    std.debug.print("  Benchmarks Completed!\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("\n", .{});
}

// تست ساده برای اطمینان از صحت کد
test "bench sanity check" {
    var flags = core.FeatureFlags.init(std.testing.allocator);
    defer flags.deinit();
    try flags.register("test", "test", .{ .boolean = true }, false);
    try std.testing.expect(flags.isEnabled("test"));
    try std.testing.expectEqual(@as(i64, 42), flags.getValue("int_feature").?.asInt().?);
}
