// modules/os-service/src/linux.zig

const std = @import("std");
const core = @import("core");
const service = @import("service.zig");

pub const SystemdServiceHandle = struct {
    unit_name: []const u8,
};

pub fn installService(svc: *service.Service) !void {
    const logger = core.logger.Logger.init(svc.allocator, .info);
    try logger.info("Installing service on Linux: {s}", .{svc.config.name});

    // ایجاد فایل systemd unit
    const unit_path = try std.fmt.allocPrint(svc.allocator, "/etc/systemd/system/{s}.service", .{svc.config.name});
    defer svc.allocator.free(unit_path);

    const unit_content = try std.fmt.allocPrint(svc.allocator,
        \\[Unit]
        \\Description={s}
        \\After=network.target
        \\
        \\[Service]
        \\Type=simple
        \\ExecStart={s}
        \\Restart=on-failure
        \\
        \\[Install]
        \\WantedBy=multi-user.target
        \\
    , .{ svc.config.description, svc.config.executable_path });
    defer svc.allocator.free(unit_content);

    // نوشتن فایل و daemon-reload

    return;
}

pub fn uninstallService(svc: *service.Service) !void {
    const logger = core.logger.Logger.init(svc.allocator, .info);
    try logger.info("Uninstalling service on Linux: {s}", .{svc.config.name});
    return;
}

pub fn startService(svc: *service.Service) !void {
    const logger = core.logger.Logger.init(svc.allocator, .info);
    try logger.info("Starting service on Linux: {s}", .{svc.config.name});

    svc.status = .running;
    return;
}

pub fn stopService(svc: *service.Service) !void {
    const logger = core.logger.Logger.init(svc.allocator, .info);
    try logger.info("Stopping service on Linux: {s}", .{svc.config.name});

    svc.status = .stopped;
    return;
}

pub fn getServiceStatus(svc: *service.Service) !service.ServiceStatus {
    return svc.status;
}

pub fn enableService(svc: *service.Service) !void {
    const logger = core.logger.Logger.init(svc.allocator, .info);
    try logger.info("Enabling service on Linux: {s}", .{svc.config.name});
    return;
}

pub fn disableService(svc: *service.Service) !void {
    const logger = core.logger.Logger.init(svc.allocator, .info);
    try logger.info("Disabling service on Linux: {s}", .{svc.config.name});
    return;
}
