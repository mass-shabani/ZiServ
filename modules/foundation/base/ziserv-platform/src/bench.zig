// ============================================================
// فایل: src/bench.zig
// Benchmarks
// ============================================================

const std = @import("std");
const platform = @import("root.zig");

fn benchPlatformInfo(iterations: usize) !void {
    var timer = std.time.Timer.start() catch unreachable;

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = platform.PlatformInfo.current();
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("PlatformInfo.current(): {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
}

fn benchPageSize(iterations: usize) !void {
    var timer = std.time.Timer.start() catch unreachable;

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = platform.Platform.pageSize();
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Platform.pageSize(): {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
}

fn benchCpuCount(iterations: usize) !void {
    var timer = std.time.Timer.start() catch unreachable;

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = platform.Platform.cpuCount() catch unreachable;
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Platform.cpuCount(): {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
}

fn benchEnvGet(iterations: usize) !void {
    const allocator = std.heap.page_allocator;
    var timer = std.time.Timer.start() catch unreachable;

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        if (try platform.env.Env.get("PATH", allocator)) |value| {
            allocator.free(value);
        }
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Env.get(): {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
}

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("  ziserv-platform - Performance Benchmarks\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("\n", .{});

    const iterations = 1_000_000;

    try benchPlatformInfo(iterations);
    try benchPageSize(iterations);
    try benchCpuCount(10_000); // کمتر چون syscall دارد
    try benchEnvGet(10_000); // کمتر چون allocation دارد

    std.debug.print("\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("  Platform Information\n", .{});
    std.debug.print("====================================================================\n", .{});

    try platform.Platform.printInfo(std.io.getStdOut().writer());
    try platform.features.CpuFeatures.printFeatures(std.io.getStdOut().writer());

    std.debug.print("====================================================================\n", .{});
    std.debug.print("  Benchmarks Completed!\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("\n", .{});
}
