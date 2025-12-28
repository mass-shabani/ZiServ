// ============================================================
// فایل: modules/foundation/ziserv-codec/src/root.zig
// ============================================================

const std = @import("std");
const core = @import("ziserv-core");
const bytes = @import("ziserv-bytes");

/// زیرماژول‌ها
pub const Encoder = @import("encoder.zig").Encoder;
pub const Decoder = @import("decoder.zig").Decoder;
pub const base64 = @import("base64.zig");
pub const hex = @import("hex.zig");
pub const utf8 = @import("utf8.zig");
pub const varint = @import("varint.zig");
pub const frame = @import("frame.zig");

/// اطلاعات ماژول
pub const version = "0.1.0";
pub const name = "ziserv-codec";

// تست‌ها
test {
    std.testing.refAllDecls(@This());
}
