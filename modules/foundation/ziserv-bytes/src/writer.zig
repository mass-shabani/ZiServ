// ============================================================
// فایل: modules/foundation/ziserv-bytes/src/writer.zig
// Abstraction برای نوشتن
// ============================================================

const std = @import("std");

/// Writer interface
pub const Writer = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        write: *const fn (ptr: *anyopaque, data: []const u8) anyerror!void,
    };

    pub fn write(self: Writer, data: []const u8) !void {
        return self.vtable.write(self.ptr, data);
    }

    /// ساخت از ByteBuffer
    pub fn fromByteBuffer(buffer: anytype) Writer {
        const T = @TypeOf(buffer);
        return .{
            .ptr = buffer,
            .vtable = &.{
                .write = struct {
                    fn write(ptr: *anyopaque, data: []const u8) !void {
                        const self: T = @ptrCast(@alignCast(ptr));
                        return self.write(data);
                    }
                }.write,
            },
        };
    }
};
