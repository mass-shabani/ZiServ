// ============================================================
// فایل: modules/foundation/ziserv-codec/src/decoder.zig
// Decoder interface
// ============================================================

const std = @import("std");
const bytes = @import("ziserv-bytes");

/// Decoder - تبدیل bytes به T
pub fn Decoder(comptime T: type) type {
    return struct {
        ptr: *anyopaque,
        vtable: *const VTable,

        const Self = @This();

        pub const VTable = struct {
            decode: *const fn (ptr: *anyopaque, data: []const u8) anyerror!T,
        };

        pub fn decode(self: Self, data: []const u8) !T {
            return self.vtable.decode(self.ptr, data);
        }
    };
}
