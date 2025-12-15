// examples/example-http/build.zig

const std = @import("std");

// pub fn build(b: *std.Build) void {
//     const target = b.standardTargetOptions(.{});
//     const optimize = b.standardOptimizeOption(.{});

//     const http_server = b.dependency("http-server", .{ .target = target, .optimize = optimize });

//     const exe = b.addExecutable(.{
//         .name = "example-http",
//         .root_source_file = b.path("main.zig"),
//         .target = target,
//         .optimize = optimize,
//     });

//     exe.root_module.addImport("http-server", http_server.module("http-server"));

//     b.installArtifact(exe);

//     const run = b.addRunArtifact(exe);
//     const run_step = b.step("run", "Run the HTTP server example");
//     run_step.dependOn(&run.step);
// }

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_mod = b.addModule("core", .{
        .root_source_file = b.path("../../modules/core/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const http_server_mod = b.addModule("http-server", .{
        .root_source_file = b.path("../../modules/http-server/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    http_server_mod.addImport("core", core_mod);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("http-server", http_server_mod);

    const exe = b.addExecutable(.{
        .name = "example-http",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the HTTP server example");
    run_step.dependOn(&run.step);
}
