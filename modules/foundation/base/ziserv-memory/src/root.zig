// ============================================================
// فایل: src/root.zig
// ziserv-memory - High-performance memory management
// ============================================================

const std = @import("std");

// Re-export submodules
pub const allocator = @import("allocator.zig");
pub const arena = @import("arena.zig");
pub const pool = @import("pool.zig");
pub const bump = @import("bump.zig");
pub const tracking = @import("tracking.zig");
pub const stats = @import("stats.zig");

// Re-export main types
pub const Allocator = allocator.Allocator;
pub const Arena = arena.Arena;
pub const Pool = pool.Pool;
pub const BumpAllocator = bump.BumpAllocator;
pub const GrowingBumpAllocator = bump.GrowingBumpAllocator;
pub const Tracker = tracking.Tracker;
pub const Stats = stats.Stats;
pub const BoundedArena = arena.BoundedArena;

// Version info
pub const version = .{
    .major = 0,
    .minor = 1,
    .patch = 0,
};

test {
    @import("std").testing.refAllDecls(@This());
}
