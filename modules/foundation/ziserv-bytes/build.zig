// ============================================================
// فایل: modules/foundation/ziserv-bytes/build.zig
// ============================================================

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // وابستگی به core
    const core_dep = b.dependency("ziserv_core", .{
        .target = target,
        .optimize = optimize,
    });
    const core_module = core_dep.module("ziserv-core");

    // ساخت ماژول bytes
    const bytes_module = b.addModule("ziserv-bytes", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    bytes_module.addImport("ziserv-core", core_module);

    // تست‌ها
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ziserv-core", .module = core_module },
            },
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run bytes module tests");
    test_step.dependOn(&run_tests.step);

    // Benchmark
    const bench = b.addExecutable(.{
        .name = "bytes-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "ziserv-core", .module = core_module },
                .{ .name = "ziserv-bytes", .module = bytes_module },
            },
        }),
    });

    b.installArtifact(bench);

    const run_bench = b.addRunArtifact(bench);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);
}
