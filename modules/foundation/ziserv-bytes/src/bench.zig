// ============================================================
// فایل: modules/foundation/ziserv-bytes/src/bench.zig
// Benchmarks
// ============================================================

const std = @import("std");
const core = @import("ziserv-core");
const bytes_mod = @import("ziserv-bytes");

fn benchBytes(iterations: usize) !void {
    const allocator = std.heap.page_allocator;
    var timer = core.time.Stopwatch.init();

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var b = try bytes_mod.Bytes.copy("Test data for benchmark", allocator);
        b.deinit();
    }
    timer.stop();

    std.debug.print("Bytes.copy: {d} iterations in {d}ms\n", .{
        iterations,
        timer.elapsedMs(),
    });
}

fn benchBytesMut(iterations: usize) !void {
    const allocator = std.heap.page_allocator;
    var timer = core.time.Stopwatch.init();

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var b = bytes_mod.BytesMut.init(allocator);
        try b.write("Test data");
        b.deinit();
    }
    timer.stop();

    std.debug.print("BytesMut: {d} iterations in {d}ms\n", .{
        iterations,
        timer.elapsedMs(),
    });
}

fn benchByteBuffer(iterations: usize) !void {
    const allocator = std.heap.page_allocator;
    var timer = core.time.Stopwatch.init();

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var buf = bytes_mod.ByteBuffer.init(allocator);
        try buf.write("Test");
        var read_buf: [4]u8 = undefined;
        _ = buf.read(&read_buf);
        buf.deinit();
    }
    timer.stop();

    std.debug.print("ByteBuffer: {d} iterations in {d}ms\n", .{
        iterations,
        timer.elapsedMs(),
    });
}

fn benchBytesPool(iterations: usize) !void {
    const allocator = std.heap.page_allocator;
    var timer = core.time.Stopwatch.init();

    var pool = bytes_mod.BytesPool.init(allocator, 1024, 100);
    defer pool.deinit();

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const buf = try pool.acquire();
        try buf.write("Test");
        pool.release(buf);
    }
    timer.stop();

    std.debug.print("BytesPool: {d} iterations in {d}ms\n", .{
        iterations,
        timer.elapsedMs(),
    });
}

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("  ZiServ Bytes - Benchmarks\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("\n", .{});

    const iterations = 100_000;

    try benchBytes(iterations);
    try benchBytesMut(iterations);
    try benchByteBuffer(iterations);
    try benchBytesPool(iterations);

    std.debug.print("\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("  Benchmarks Completed!\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("\n", .{});
}
