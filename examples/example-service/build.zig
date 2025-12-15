const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core = b.dependency("core", .{ .target = target, .optimize = optimize });

    const os_service = b.dependency("os_service", .{ .target = target, .optimize = optimize });

    const exe = b.addExecutable(.{
        .name = "example-service",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "core", .module = core.module("core") },
                .{ .name = "os-service", .module = os_service.module("os-service") },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the service example");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
