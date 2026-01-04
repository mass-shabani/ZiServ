// ============================================================
// فایل: src/root.zig
// نقطه ورود اصلی ماژول ziserv-platform
// ============================================================

const std = @import("std");

// Re-exports
pub const Os = @import("os.zig").Os;
pub const Arch = @import("arch.zig").Arch;
pub const PlatformInfo = @import("info.zig").PlatformInfo;
pub const Platform = @import("info.zig").Platform;
pub const syscalls = @import("syscalls.zig");
pub const features = @import("features.zig");
pub const env = @import("env.zig");

// اطلاعات ماژول
pub const version = "0.1.0";
pub const name = "ziserv-platform";

// تست‌ها
test {
    std.testing.refAllDecls(@This());
}
