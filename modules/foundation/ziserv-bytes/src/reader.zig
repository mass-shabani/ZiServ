// ============================================================
// فایل: modules/foundation/ziserv-bytes/src/reader.zig
// Abstraction برای خواندن
// ============================================================

const std = @import("std");

/// Reader interface
pub const Reader = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        read: *const fn (ptr: *anyopaque, buf: []u8) anyerror!usize,
    };

    pub fn read(self: Reader, buf: []u8) !usize {
        return self.vtable.read(self.ptr, buf);
    }

    /// ساخت از ByteBuffer
    pub fn fromByteBuffer(buffer: anytype) Reader {
        const T = @TypeOf(buffer);
        return .{
            .ptr = buffer,
            .vtable = &.{
                .read = struct {
                    fn read(ptr: *anyopaque, buf: []u8) !usize {
                        const self: T = @ptrCast(@alignCast(ptr));
                        return self.read(buf);
                    }
                }.read,
            },
        };
    }
};
