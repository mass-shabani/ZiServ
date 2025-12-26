// ============================================================
// فایل: modules/foundation/ziserv-core/src/root.zig
// ============================================================

const std = @import("std");

/// زیرماژول‌های اصلی
pub const platform = @import("platform.zig");
pub const error_types = @import("error.zig");
pub const config = @import("config.zig");
pub const traits = @import("traits.zig");
pub const memory = @import("memory.zig");
pub const time = @import("time.zig");

/// اطلاعات ماژول
pub const version = "0.1.0";
pub const name = "ziserv-core";

// تست‌ها
test {
    std.testing.refAllDecls(@This());
}
