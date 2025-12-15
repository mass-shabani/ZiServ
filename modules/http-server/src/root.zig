// modules/http-server/src/root.zig

const std = @import("std");
const core = @import("core");

// Export کردن زیرماژول‌ها
pub const HttpServer = @import("server.zig").HttpServer;
pub const ServerConfig = @import("server.zig").ServerConfig;
pub const Request = @import("request.zig").Request;
pub const Response = @import("response.zig").Response;

// اطلاعات ماژول
pub const version = "0.1.0";
pub const name = "ziserv-http-server";

// تست‌ها
test {
    std.testing.refAllDecls(@This());
}
