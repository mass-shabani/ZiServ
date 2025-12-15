// modules/core/src/root.zig

const std = @import("std");

// Export کردن زیرماژول‌ها
pub const platform = @import("platform.zig");
pub const allocator = @import("allocator.zig");
pub const logger = @import("logger.zig");

// اطلاعات ماژول
pub const version = "0.1.0";
pub const name = "ziserv-core";

// تست‌ها
test {
    std.testing.refAllDecls(@This());
}
