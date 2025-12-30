// ============================================================
// فایل: modules/foundation/ziserv-util/src/bench.zig
// Benchmarks
// ============================================================

const std = @import("std");
const core = @import("ziserv-core");
const util = @import("ziserv-util");

fn benchStringBuilder(iterations: usize) !void {
    const allocator = std.heap.page_allocator;
    var timer = core.time.Stopwatch.init();

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var sb = util.StringBuilder.init(allocator);
        defer sb.deinit();

        try sb.append("Hello");
        try sb.append(" ");
        try sb.append("World");
        _ = sb.toStringConst();
    }
    timer.stop();

    std.debug.print("StringBuilder: {d} iterations in {d}ms\n", .{
        iterations,
        timer.elapsedMs(),
    });
}

fn benchHashMap(iterations: usize) !void {
    const allocator = std.heap.page_allocator;
    var timer = core.time.Stopwatch.init();

    var map = util.HashMap([]const u8, i32).init(allocator);
    defer map.deinit();

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        try map.put("key", @intCast(i));
        _ = map.get("key");
    }
    timer.stop();

    std.debug.print("HashMap: {d} iterations in {d}ms\n", .{
        iterations,
        timer.elapsedMs(),
    });
}

fn benchArrayList(iterations: usize) !void {
    const allocator = std.heap.page_allocator;
    var timer = core.time.Stopwatch.init();

    var list = util.ArrayList(i32).init(allocator);
    defer list.deinit();

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        try list.append(@intCast(i));
    }
    timer.stop();

    std.debug.print("ArrayList append: {d} iterations in {d}ms\n", .{
        iterations,
        timer.elapsedMs(),
    });
}

fn benchRingBuffer(iterations: usize) !void {
    var timer = core.time.Stopwatch.init();

    var rb = util.RingBuffer(i32, 1024).init();

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        try rb.push(@intCast(i));
        if (rb.isFull()) {
            _ = rb.pop();
        }
    }
    timer.stop();

    std.debug.print("RingBuffer: {d} iterations in {d}ms\n", .{
        iterations,
        timer.elapsedMs(),
    });
}

fn benchUuidGeneration(iterations: usize) !void {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const rng = prng.random();

    var timer = core.time.Stopwatch.init();

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = util.Uuid.v4(rng);
    }
    timer.stop();

    std.debug.print("UUID generation: {d} iterations in {d}ms\n", .{
        iterations,
        timer.elapsedMs(),
    });
}

fn benchStringOperations(iterations: usize) !void {
    const allocator = std.heap.page_allocator;
    var timer = core.time.Stopwatch.init();

    const text = "hello,world,foo,bar,baz";

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const parts = try util.string.split(allocator, text, ",");
        defer {
            for (parts) |_| {}
            allocator.free(parts);
        }
    }
    timer.stop();

    std.debug.print("String split: {d} iterations in {d}ms\n", .{
        iterations,
        timer.elapsedMs(),
    });
}

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("  ZiServ Util - Performance Benchmarks\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("\n", .{});

    const iterations = 100_000;

    try benchStringBuilder(iterations);
    try benchHashMap(iterations);
    try benchArrayList(iterations);
    try benchRingBuffer(iterations);
    try benchUuidGeneration(iterations);
    try benchStringOperations(10_000); // Fewer iterations (allocations)

    std.debug.print("\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("  Benchmarks Completed!\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("\n", .{});
}
