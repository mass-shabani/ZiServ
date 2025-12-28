// ============================================================
// فایل: modules/foundation/ziserv-codec/src/encoder.zig
// Encoder interface
// ============================================================

const std = @import("std");
const bytes = @import("ziserv-bytes");

/// Encoder - تبدیل T به bytes
pub fn Encoder(comptime T: type) type {
    return struct {
        ptr: *anyopaque,
        vtable: *const VTable,

        const Self = @This();

        pub const VTable = struct {
            encode: *const fn (ptr: *anyopaque, value: T, writer: *bytes.BytesMut) anyerror!void,
        };

        pub fn encode(self: Self, value: T, writer: *bytes.BytesMut) !void {
            return self.vtable.encode(self.ptr, value, writer);
        }
    };
}
