// examples/example-service/main.zig

const std = @import("std");
const core = @import("core");
const os_service = @import("os-service");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const logger = core.logger.Logger.init(allocator, .info);
    try logger.info("=== ZiServ Service Example ===", .{});
    try logger.info("Platform: {s}", .{core.platform.Os.name()});

    const config = os_service.ServiceConfig{
        .name = "ZiServExample",
        .display_name = "ZiServ Example Service",
        .description = "A service created with ZiServ framework",
        .executable_path = "/usr/bin/ziserv-example",
        .start_type = .auto,
    };

    const svc = try os_service.Service.init(allocator, config);
    defer svc.deinit();

    try logger.info("Installing service...", .{});
    try svc.install();

    try logger.info("Enabling service...", .{});
    try svc.enable();

    try logger.info("Starting service...", .{});
    try svc.start();

    const status = try svc.getStatus();
    try logger.info("Service status: {s}", .{@tagName(status)});

    try logger.info("Service operations completed!", .{});
}
