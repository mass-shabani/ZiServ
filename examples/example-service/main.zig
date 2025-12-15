// examples/example-service/main.zig

const std = @import("std");
const core = @import("core");
const os_service = @import("os-service");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // نمایش اطلاعات اولیه
    const logger = core.logger.Logger.init(allocator, .info);
    try logger.info("=================================", .{});
    try logger.info("ZiServ Service Management Example", .{});
    try logger.info("=================================", .{});
    try logger.info("Platform: {s}", .{core.platform.Os.name()});
    try logger.info("Path Separator: {c}", .{core.platform.getPathSeparator()});
    try logger.info("", .{});

    // تنظیمات سرویس
    const config = os_service.ServiceConfig{
        .name = "ZiServExample",
        .display_name = "ZiServ Example Service",
        .description = "A system service created with ZiServ framework",
        .executable_path = "/usr/bin/ziserv-example",
        .start_type = .auto,
    };

    // ایجاد سرویس
    const svc = try os_service.Service.init(allocator, config);
    defer svc.deinit();

    try logger.info("Service Name: {s}", .{svc.config.name});
    try logger.info("Display Name: {s}", .{svc.config.display_name});
    try logger.info("", .{});

    // عملیات نصب
    try logger.info("[1/5] Installing service...", .{});
    try svc.install();
    try logger.info("✓ Service installed successfully", .{});

    // عملیات فعال‌سازی
    try logger.info("[2/5] Enabling service...", .{});
    try svc.enable();
    try logger.info("✓ Service enabled", .{});

    // عملیات شروع
    try logger.info("[3/5] Starting service...", .{});
    try svc.start();
    try logger.info("✓ Service started", .{});

    // بررسی وضعیت
    try logger.info("[4/5] Checking service status...", .{});
    const status = try svc.getStatus();
    try logger.info("✓ Service status: {s}", .{@tagName(status)});

    // اطلاعات نهایی
    try logger.info("[5/5] Operations completed!", .{});
    try logger.info("", .{});
    try logger.info("=================================", .{});
    try logger.info("All service operations finished successfully", .{});
    try logger.info("=================================", .{});
}
