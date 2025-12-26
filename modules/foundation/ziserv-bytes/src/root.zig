// ============================================================
// فایل: modules/foundation/ziserv-bytes/src/root.zig
// ============================================================

const std = @import("std");
const core = @import("ziserv-core");

/// زیرماژول‌ها
pub const Bytes = @import("bytes.zig").Bytes;
pub const BytesMut = @import("bytes_mut.zig").BytesMut;
pub const ByteBuffer = @import("byte_buffer.zig").ByteBuffer;
pub const BytesPool = @import("bytes_pool.zig").BytesPool;
pub const Reader = @import("reader.zig").Reader;
pub const Writer = @import("writer.zig").Writer;

/// اطلاعات ماژول
pub const version = "0.1.0";
pub const name = "ziserv-bytes";

// تست‌ها
test {
    std.testing.refAllDecls(@This());
}
