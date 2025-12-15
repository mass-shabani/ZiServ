// modules/os-service/src/service.zig

const std = @import("std");
const core = @import("core");
const windows = @import("windows.zig");
const linux = @import("linux.zig");

pub const ServiceStatus = enum {
    stopped,
    starting,
    running,
    stopping,
    paused,
};

pub const StartType = enum {
    auto,
    manual,
    disabled,
};

pub const ServiceConfig = struct {
    name: []const u8,
    display_name: []const u8,
    description: []const u8,
    executable_path: []const u8,
    start_type: StartType,
};

pub const Service = struct {
    config: ServiceConfig,
    allocator: std.mem.Allocator,
    status: ServiceStatus,
    platform_handle: PlatformHandle,

    const PlatformHandle = switch (core.platform.Os.current()) {
        .windows => windows.WindowsServiceHandle,
        .linux => linux.SystemdServiceHandle,
        .unsupported => void,
    };

    pub fn init(allocator: std.mem.Allocator, config: ServiceConfig) !*Service {
        const svc = try allocator.create(Service);
        svc.* = .{
            .config = config,
            .allocator = allocator,
            .status = .stopped,
            .platform_handle = undefined,
        };
        return svc;
    }

    pub fn deinit(self: *Service) void {
        self.allocator.destroy(self);
    }

    pub fn install(self: *Service) !void {
        return switch (core.platform.Os.current()) {
            .windows => windows.installService(self),
            .linux => linux.installService(self),
            .unsupported => error.UnsupportedPlatform,
        };
    }

    pub fn uninstall(self: *Service) !void {
        return switch (core.platform.Os.current()) {
            .windows => windows.uninstallService(self),
            .linux => linux.uninstallService(self),
            .unsupported => error.UnsupportedPlatform,
        };
    }

    pub fn start(self: *Service) !void {
        return switch (core.platform.Os.current()) {
            .windows => windows.startService(self),
            .linux => linux.startService(self),
            .unsupported => error.UnsupportedPlatform,
        };
    }

    pub fn stop(self: *Service) !void {
        return switch (core.platform.Os.current()) {
            .windows => windows.stopService(self),
            .linux => linux.stopService(self),
            .unsupported => error.UnsupportedPlatform,
        };
    }

    pub fn getStatus(self: *Service) !ServiceStatus {
        return switch (core.platform.Os.current()) {
            .windows => windows.getServiceStatus(self),
            .linux => linux.getServiceStatus(self),
            .unsupported => error.UnsupportedPlatform,
        };
    }

    pub fn enable(self: *Service) !void {
        return switch (core.platform.Os.current()) {
            .windows => windows.enableService(self),
            .linux => linux.enableService(self),
            .unsupported => error.UnsupportedPlatform,
        };
    }

    pub fn disable(self: *Service) !void {
        return switch (core.platform.Os.current()) {
            .windows => windows.disableService(self),
            .linux => linux.disableService(self),
            .unsupported => error.UnsupportedPlatform,
        };
    }
};

test "service creation" {
    const config = ServiceConfig{
        .name = "test-service",
        .display_name = "Test Service",
        .description = "A test service",
        .executable_path = "/usr/bin/test",
        .start_type = .manual,
    };

    const svc = try Service.init(std.testing.allocator, config);
    defer svc.deinit();

    try std.testing.expectEqualStrings("test-service", svc.config.name);
}
