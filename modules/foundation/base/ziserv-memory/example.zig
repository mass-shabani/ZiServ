// ============================================================
// فایل: example.zig
// Examples for ziserv-memory
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

    pub fn print(self: *@This(), comptime str: []const u8, args: anytype) !void {
        _ = self;
        std.debug.print(str, args);
    }

    fn write(self: *output, str: []const u8) !void {
        const io = self.threaded.io();
        try std.Io.File.stdout().writeStreamingAll(io, str);
    }
};

fn exampleBasicAllocator() !void {
    var stdout = output.init();
    defer stdout.deInit() catch {};

    try stdout.write("\n");
    try stdout.write("\n");
    try stdout.write("╔════════════════════════════════════════════════════════════╗\n");
    try stdout.write("║         Example 1: Basic Allocator                         ║\n");
    try stdout.write("╚════════════════════════════════════════════════════════════╝\n");
    try stdout.write("\n");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var alloc = memory.Allocator.init(gpa.allocator());

    const slice = try alloc.alloc(u8, 100);
    defer alloc.free(slice);

    @memset(slice, 42);

    try stdout.print("Allocated {d} bytes\n", .{slice.len});
    try stdout.print("First byte: {d}\n", .{slice[0]});
    try stdout.write("\n");
}

fn exampleArena() !void {
    var stdout = output.init();
    defer stdout.deInit() catch {};

    try stdout.write("╔════════════════════════════════════════════════════════════╗\n");
    try stdout.write("║         Example 2: Arena Allocator                         ║\n");
    try stdout.write("╚════════════════════════════════════════════════════════════╝\n");
    try stdout.write("\n");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = memory.Arena.init(gpa.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();

    const slice1 = try allocator.alloc(u8, 100);
    const slice2 = try allocator.alloc(u32, 50);
    const slice3 = try allocator.alloc(u64, 25);

    slice1[0] = 1;
    slice2[0] = 2;
    slice3[0] = 3;

    try stdout.write("Arena allocated 3 slices\n");
    try stdout.print("Values: {d}, {d}, {d}\n", .{ slice1[0], slice2[0], slice3[0] });
    try stdout.write("All will be freed together on arena.deinit()\n");
    try stdout.write("\n");
}

fn exampleBumpAllocator() !void {
    var stdout = output.init();
    defer stdout.deInit() catch {};

    try stdout.write("╔════════════════════════════════════════════════════════════╗\n");
    try stdout.write("║         Example 3: Bump Allocator                          ║\n");
    try stdout.write("╚════════════════════════════════════════════════════════════╝\n");
    try stdout.write("\n");

    var buffer: [4096]u8 = undefined;
    var bump = memory.BumpAllocator.init(&buffer);

    const allocator = bump.allocator();

    try stdout.print("Buffer size: {d} bytes\n", .{buffer.len});

    const slice1 = try allocator.alloc(u8, 1000);
    try stdout.print("Allocated 1000 bytes, used: {d}, remaining: {d}\n", .{
        bump.used(),
        bump.remaining(),
    });

    const slice2 = try allocator.alloc(u32, 100);
    try stdout.print("Allocated 100 u32s, used: {d}, remaining: {d}\n", .{
        bump.used(),
        bump.remaining(),
    });

    _ = slice1;
    _ = slice2;

    try stdout.print("Utilization: {d:.2}%\n", .{bump.utilizationPercent()});

    bump.reset();
    try stdout.print("After reset, used: {d}\n", .{bump.used()});
    try stdout.write("\n");
}

fn examplePool() !void {
    var stdout = output.init();
    defer stdout.deInit() catch {};

    try stdout.write("╔════════════════════════════════════════════════════════════╗\n");
    try stdout.write("║         Example 4: Object Pool                             ║\n");
    try stdout.write("╚════════════════════════════════════════════════════════════╝\n");
    try stdout.write("\n");

    const Connection = struct {
        id: u32,
        active: bool,
        buffer: [256]u8,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var pool = try memory.Pool(Connection).init(gpa.allocator(), 10);
    defer pool.deinit();

    try stdout.write("Pool capacity: 10 connections\n");
    try stdout.print("Available: {d}\n", .{pool.availableCount()});

    const conn1 = try pool.acquire();
    const conn2 = try pool.acquire();
    const conn3 = try pool.acquire();

    conn1.id = 1;
    conn2.id = 2;
    conn3.id = 3;

    try stdout.write("Acquired 3 connections\n");
    try stdout.print("Available: {d}, In use: {d}\n", .{
        pool.availableCount(),
        pool.inUseCount(),
    });

    pool.release(conn1);
    pool.release(conn2);

    try stdout.write("Released 2 connections\n");
    try stdout.print("Available: {d}, In use: {d}\n", .{
        pool.availableCount(),
        pool.inUseCount(),
    });

    pool.release(conn3);
    try stdout.write("\n");
}

fn exampleTracker() !void {
    var stdout = output.init();
    defer stdout.deInit() catch {};

    try stdout.write("╔════════════════════════════════════════════════════════════╗\n");
    try stdout.write("║         Example 5: Memory Tracker                          ║\n");
    try stdout.write("╚════════════════════════════════════════════════════════════╝\n");
    try stdout.write("\n");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var tracker = memory.Tracker.init(gpa.allocator());
    defer tracker.deinit();

    const allocator = tracker.allocator();

    const slice1 = try allocator.alloc(u8, 1000);
    const slice2 = try allocator.alloc(u32, 500);
    const slice3 = try allocator.alloc(u64, 250);

    var stats = tracker.report();
    try stdout.write("After allocations:\n");
    try stdout.print("  Total allocated: {d} bytes\n", .{stats.total_allocated});
    try stdout.print("  Current usage: {d} bytes\n", .{stats.current_usage});
    try stdout.print("  Allocation count: {d}\n", .{stats.allocation_count});

    allocator.free(slice1);
    allocator.free(slice2);

    stats = tracker.report();
    try stdout.write("\nAfter freeing 2 allocations:\n");
    try stdout.print("  Current usage: {d} bytes\n", .{stats.current_usage});
    try stdout.print("  Free count: {d}\n", .{stats.free_count});

    allocator.free(slice3);

    stats = tracker.report();
    try stdout.write("\nFinal stats:\n");
    try stats.print(stdout);
}

fn exampleBoundedArena() !void {
    var stdout = output.init();
    defer stdout.deInit() catch {};

    try stdout.write("╔════════════════════════════════════════════════════════════╗\n");
    try stdout.write("║         Example 6: Bounded Arena                           ║\n");
    try stdout.write("╚════════════════════════════════════════════════════════════╝\n");
    try stdout.write("\n");

    var arena = memory.BoundedArena.init(std.testing.allocator, 2048);
    defer arena.deinit();

    const allocator = arena.allocator();

    try stdout.write("Arena limit: 2048 bytes\n");
    try stdout.print("Remaining: {d} bytes\n", .{arena.remaining()});

    const slice1 = try allocator.alloc(u8, 1000);
    try stdout.write("\nAllocated 1000 bytes\n");
    try stdout.print("Remaining: {d} bytes\n", .{arena.remaining()});

    const slice2 = try allocator.alloc(u8, 800);
    try stdout.write("\nAllocated 800 bytes\n");
    try stdout.print("Remaining: {d} bytes\n", .{arena.remaining()});

    _ = slice1;
    _ = slice2;

    const result = allocator.alloc(u8, 500);
    if (result) |_| {
        try stdout.write("\nUnexpected: allocation succeeded\n");
    } else |err| {
        try stdout.print("\nExpected: allocation failed with {}\n", .{err});
    }

    try stdout.write("\n");
}

fn exampleGrowingBump() !void {
    var stdout = output.init();
    defer stdout.deInit() catch {};

    try stdout.write("╔════════════════════════════════════════════════════════════╗\n");
    try stdout.write("║         Example 7: Growing Bump Allocator                  ║\n");
    try stdout.write("╚════════════════════════════════════════════════════════════╝\n");
    try stdout.write("\n");

    var bump = try memory.GrowingBumpAllocator.init(std.testing.allocator, 1024);
    defer bump.deinit();

    const allocator = bump.allocator_interface();

    try stdout.write("Initial buffer: 1024 bytes\n");
    try stdout.print("Buffer count: {d}\n", .{bump.buffers.items.len});

    _ = try allocator.alloc(u8, 800);
    try stdout.write("\nAllocated 800 bytes\n");
    try stdout.print("Buffer count: {d}\n", .{bump.buffers.items.len});

    _ = try allocator.alloc(u8, 500);
    try stdout.write("\nAllocated 500 bytes (triggered growth)\n");
    try stdout.print("Buffer count: {d}\n", .{bump.buffers.items.len});

    _ = try allocator.alloc(u8, 2000);
    try stdout.write("\nAllocated 2000 bytes (triggered another growth)\n");
    try stdout.print("Buffer count: {d}\n", .{bump.buffers.items.len});
    try stdout.print("Total used: {d} bytes\n", .{bump.total_used()});

    try stdout.write("\n");
}

pub fn main() !void {
    var stdout: output = output.init();
    defer stdout.deInit() catch {};

    try stdout.write("\n");
    try stdout.write("╔════════════════════════════════════════════════════════════╗\n");
    try stdout.write("║              ziserv-memory Examples                        ║\n");
    try stdout.write("╚════════════════════════════════════════════════════════════╝\n");

    try exampleBasicAllocator();
    try exampleArena();
    try exampleBumpAllocator();
    try examplePool();
    try exampleTracker();
    try exampleBoundedArena();
    try exampleGrowingBump();

    try stdout.write("╔════════════════════════════════════════════════════════════╗\n");
    try stdout.write("║         All Examples Completed Successfully!               ║\n");
    try stdout.write("╚════════════════════════════════════════════════════════════╝\n");
    try stdout.write("\n");
}
