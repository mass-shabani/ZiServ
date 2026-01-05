// ============================================================
// فایل: src/bench.zig
// Benchmarks for ziserv-errors
// ============================================================

const std = @import("std");
const errors = @import("root.zig");

fn benchResult(iterations: usize) !void {
    const R = errors.Result(i32, error{Failed});
    var timer = try std.time.Timer.start();

    // Benchmark: creation + unwrap
    var sum: i64 = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = R.success(42);
        sum += result.unwrap();
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Result creation + unwrap: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
    std.debug.print("  Dummy sum: {d}\n", .{sum}); // Prevent optimization
}

fn benchResultMap(iterations: usize) !void {
    const R = errors.Result(i32, error{Failed});
    var timer = try std.time.Timer.start();

    var sum: i64 = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = R.success(21);
        const doubled = result.map(i32, struct {
            fn double(x: i32) i32 {
                return x * 2;
            }
        }.double);
        sum += doubled.unwrap();
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Result map: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
    std.debug.print("  Dummy sum: {d}\n", .{sum});
}

fn benchResultAndThen(iterations: usize) !void {
    const R = errors.Result(i32, error{Failed});
    var timer = try std.time.Timer.start();

    var sum: i64 = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = R.success(21);
        const doubled = result.andThen(i32, struct {
            fn double(x: i32) R {
                return R.success(x * 2);
            }
        }.double);
        sum += doubled.unwrap();
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Result andThen: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
    std.debug.print("  Dummy sum: {d}\n", .{sum});
}

fn benchOption(iterations: usize) !void {
    const O = errors.Option(i32);
    var timer = try std.time.Timer.start();

    var sum: i64 = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const option = O.someOption(42);
        sum += option.unwrap();
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Option creation + unwrap: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
    std.debug.print("  Dummy sum: {d}\n", .{sum});
}

fn benchOptionMap(iterations: usize) !void {
    const O = errors.Option(i32);
    var timer = try std.time.Timer.start();

    var sum: i64 = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const option = O.someOption(21);
        const doubled = option.map(i32, struct {
            fn double(x: i32) i32 {
                return x * 2;
            }
        }.double);
        sum += doubled.unwrap();
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Option map: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
    std.debug.print("  Dummy sum: {d}\n", .{sum});
}

fn benchErrorContext(iterations: usize) !void {
    var timer = try std.time.Timer.start();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const ctx = errors.Context.initSimple("Test error");
        _ = ctx;
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("ErrorContext creation: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
}

fn benchErrorWithContext(iterations: usize) !void {
    const EWC = errors.ErrorWithContext(errors.Error);
    var timer = try std.time.Timer.start();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const ctx = errors.Context.initSimple("Test error");
        const err = EWC.withContext(error.IoError, ctx);
        _ = err;
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("ErrorWithContext creation: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
}

fn benchWrapResult(iterations: usize) !void {
    var timer = try std.time.Timer.start();

    var sum: i64 = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const value: error{Failed}!i32 = 42;
        const result = errors.wrapResult(i32, error{Failed}, value);
        sum += result.unwrap();
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("wrapResult: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
    std.debug.print("  Dummy sum: {d}\n", .{sum});
}

fn benchCombinators(allocator: std.mem.Allocator, iterations: usize) !void {
    const R = errors.Result(i32, error{Failed});
    var timer = try std.time.Timer.start();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const results = [_]R{
            R.success(1),
            R.success(2),
            R.failure(error.Failed),
            R.success(3),
        };

        const filtered = try errors.combinators.filterOk(i32, error{Failed}, allocator, &results);
        allocator.free(filtered);
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Combinators filterOk: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
}

pub fn main() !void {
    const stdout = std.fs.File.stdout();
    const writer = stdout.deprecatedWriter();

    try writer.writeAll("\n");
    try writer.writeAll("╔════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║       ziserv-errors - Performance Benchmarks               ║\n");
    try writer.writeAll("╚════════════════════════════════════════════════════════════╝\n");
    try writer.writeAll("\n");

    const iterations: usize = 10_000_000;
    const combo_iterations: usize = 100_000; // کمتر چون allocation دارد

    try writer.writeAll("Running benchmarks...\n\n");

    // Result benchmarks
    try writer.writeAll("─────────────────────────────────────\n");
    try writer.writeAll("Result Type Benchmarks\n");
    try writer.writeAll("─────────────────────────────────────\n");
    try benchResult(iterations);
    try benchResultMap(iterations);
    try benchResultAndThen(iterations);
    try writer.writeAll("\n");

    // Option benchmarks
    try writer.writeAll("─────────────────────────────────────\n");
    try writer.writeAll("Option Type Benchmarks\n");
    try writer.writeAll("─────────────────────────────────────\n");
    try benchOption(iterations);
    try benchOptionMap(iterations);
    try writer.writeAll("\n");

    // Error context benchmarks
    try writer.writeAll("─────────────────────────────────────\n");
    try writer.writeAll("Error Context Benchmarks\n");
    try writer.writeAll("─────────────────────────────────────\n");
    try benchErrorContext(iterations);
    try benchErrorWithContext(iterations);
    try writer.writeAll("\n");

    // Utility benchmarks
    try writer.writeAll("─────────────────────────────────────\n");
    try writer.writeAll("Utility Benchmarks\n");
    try writer.writeAll("─────────────────────────────────────\n");
    try benchWrapResult(iterations);
    try writer.writeAll("\n");

    // Combinators benchmarks (با allocator)
    var gpa = std.heap.GeneralPurposeAllocator(.{}){
        .backing_allocator = std.heap.page_allocator,
    };
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try writer.writeAll("─────────────────────────────────────\n");
    try writer.writeAll("Combinators Benchmarks\n");
    try writer.writeAll("─────────────────────────────────────\n");
    try benchCombinators(allocator, combo_iterations);
    try writer.writeAll("\n");

    try writer.writeAll("╔════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║         Benchmarks Completed Successfully!                 ║\n");
    try writer.writeAll("╚════════════════════════════════════════════════════════════╝\n");
    try writer.writeAll("\n");
}
