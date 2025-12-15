// modules/core/src/allocator.zig

const std = @import("std");

pub fn getDefaultAllocator() std.mem.Allocator {
    return std.heap.page_allocator;
}

pub const ArenaAllocator = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init(parent: std.mem.Allocator) ArenaAllocator {
        return .{
            .arena = std.heap.ArenaAllocator.init(parent),
        };
    }

    pub fn deinit(self: *ArenaAllocator) void {
        self.arena.deinit();
    }

    pub fn allocator(self: *ArenaAllocator) std.mem.Allocator {
        return self.arena.allocator();
    }
};

test "arena allocator" {
    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();
    const memory = try alloc.alloc(u8, 100);
    try std.testing.expectEqual(@as(usize, 100), memory.len);
}
