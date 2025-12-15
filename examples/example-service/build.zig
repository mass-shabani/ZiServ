// examples/example-service/build.zig

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_mod = b.addModule("core", .{
        .root_source_file = b.path("../../modules/core/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const os_service_mod = b.addModule("os-service", .{
        .root_source_file = b.path("../../modules/os-service/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    os_service_mod.addImport("core", core_mod);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("core", core_mod);
    exe_mod.addImport("os-service", os_service_mod);

    const exe = b.addExecutable(.{
        .name = "example-service",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the service example");
    run_step.dependOn(&run.step);
}
