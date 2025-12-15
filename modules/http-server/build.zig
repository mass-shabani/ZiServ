// modules/http-server/build.zig

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_dep = b.dependency("core", .{
        .target = target,
        .optimize = optimize,
    });

    const core_module = core_dep.module("core");

    const http_module = b.addModule("http-server", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    http_module.addImport("core", core_module);

    const tests = b.addTest(.{
        .root_module = http_module,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run http-server tests");
    test_step.dependOn(&run_tests.step);
}
