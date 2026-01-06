// ============================================================
// فایل: src/bench.zig
// Benchmarks for ziserv-memory
// ============================================================

const std = @import("std");
const memory = @import("ziserv-memory");

const output = struct {
    debug_allocator: std.heap.DebugAllocator(.{}),
    threaded: std.Io.Threaded,

    pub fn init() output {
        var self: output = undefined;
        self.debug_allocator = .init;
        const gpa = self.debug_allocator.allocator();
        self.threaded = .init(gpa, .{});
        return self;
    }

    fn this(self: @This()) *output {
        return &self;
    }

    pub fn deInit(self: *@This()) !void {
        _ = self.debug_allocator.deinit();
        self.threaded.deinit();
    }

    pub fn print(self: *const @This(), comptime str: []const u8, args: anytype) !void {
        _ = self;
        std.debug.print(str, args);
    }

    pub fn writeAll(self: *const @This(), str: []const u8) !void {
        write(self, str);
    }

    fn write(self: *output, str: []const u8) !void {
        const io = self.threaded.io();
        try std.Io.File.stdout().writeStreamingAll(io, str);
    }
};

fn benchStdAllocator(iterations: usize) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var timer = try std.time.Timer.start();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const slice = try allocator.alloc(u8, 1024);
        allocator.free(slice);
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("std.heap.GPA: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
}

fn benchArenaAllocator(iterations: usize) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var timer = try std.time.Timer.start();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var arena = memory.Arena.init(gpa.allocator());
        defer arena.deinit();

        const allocator = arena.allocator();
        _ = try allocator.alloc(u8, 1024);
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Arena: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
}

fn benchBumpAllocator(iterations: usize) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const buffer = try gpa.allocator().alloc(u8, 10 * 1024 * 1024);
    defer gpa.allocator().free(buffer);

    var timer = try std.time.Timer.start();

    var bump = memory.BumpAllocator.init(buffer);
    const allocator = bump.allocator();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = try allocator.alloc(u8, 1024);
        if (bump.remaining() < 1024) {
            bump.reset();
        }
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Bump: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
}

fn benchPoolAllocator(iterations: usize) !void {
    const TestStruct = struct {
        data: [1024]u8,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var pool = try memory.Pool(TestStruct).init(gpa.allocator(), 100);
    defer pool.deinit();

    var timer = try std.time.Timer.start();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const item = try pool.acquire();
        pool.release(item);
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Pool: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
}

fn benchTracker(iterations: usize) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var tracker = memory.Tracker.init(gpa.allocator());
    defer tracker.deinit();

    const allocator = tracker.allocator();

    var timer = try std.time.Timer.start();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const slice = try allocator.alloc(u8, 1024);
        allocator.free(slice);
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Tracker: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
}

fn benchMixedWorkload(iterations: usize) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = memory.Arena.init(gpa.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();

    var timer = try std.time.Timer.start();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = try allocator.alloc(u8, 16);
        _ = try allocator.alloc(u32, 32);
        _ = try allocator.alloc(u64, 64);

        if (i % 1000 == 0) {
            arena.reset();
        }
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Mixed Workload: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
}

fn benchGrowingBump(iterations: usize) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var bump = try memory.GrowingBumpAllocator.init(gpa.allocator(), 4096);
    defer bump.deinit();

    const allocator = bump.allocator_interface();

    var timer = try std.time.Timer.start();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = try allocator.alloc(u8, 1024);

        if (i % 10000 == 0) {
            bump.reset();
        }
    }

    const elapsed = timer.read();
    const ns_per_op = elapsed / iterations;

    std.debug.print("Growing Bump: {d} iterations in {d}ms ({d}ns/op)\n", .{
        iterations,
        elapsed / std.time.ns_per_ms,
        ns_per_op,
    });
}

pub fn main() !void {
    var stdout: output = output.init();
    defer stdout.deInit() catch {};

    try stdout.write("\n");
    try stdout.write("╔════════════════════════════════════════════════════════════╗\n");
    try stdout.write("║       ziserv-memory - Performance Benchmarks               ║\n");
    try stdout.write("╚════════════════════════════════════════════════════════════╝\n");
    try stdout.write("\n");

    const iterations: usize = 100_000;

    try stdout.write("Running benchmarks...\n\n");

    try stdout.write("─────────────────────────────────────\n");
    try stdout.write("Allocator Comparison (1KB allocations)\n");
    try stdout.write("─────────────────────────────────────\n");
    try benchStdAllocator(iterations);
    try benchArenaAllocator(iterations);
    try benchBumpAllocator(iterations);
    try benchPoolAllocator(iterations);
    try benchTracker(iterations);
    try stdout.write("\n");

    try stdout.write("─────────────────────────────────────\n");
    try stdout.write("Advanced Benchmarks\n");
    try stdout.write("─────────────────────────────────────\n");
    try benchMixedWorkload(iterations);
    try benchGrowingBump(iterations);
    try stdout.write("\n");

    try stdout.write("╔════════════════════════════════════════════════════════════╗\n");
    try stdout.write("║         Benchmarks Completed Successfully!                 ║\n");
    try stdout.write("╚════════════════════════════════════════════════════════════╝\n");
    try stdout.write("\n");
}
