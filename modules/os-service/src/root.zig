// modules/os-service/src/root.zig

const std = @import("std");
const core = @import("core");

// Export کردن زیرماژول‌ها
pub const Service = @import("service.zig").Service;
pub const ServiceConfig = @import("service.zig").ServiceConfig;
pub const ServiceStatus = @import("service.zig").ServiceStatus;
pub const StartType = @import("service.zig").StartType;

// اطلاعات ماژول
pub const version = "0.1.0";
pub const name = "ziserv-os-service";

// تست‌ها
test {
    std.testing.refAllDecls(@This());
}
