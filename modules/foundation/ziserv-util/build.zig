// ============================================================
// فایل: modules/foundation/ziserv-util/build.zig
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

    // ساخت ماژول util
    const util_module = b.addModule("ziserv-util", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    util_module.addImport("ziserv-core", core_module);

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
    const test_step = b.step("test", "Run util module tests");
    test_step.dependOn(&run_tests.step);

    // Benchmark
    const bench = b.addExecutable(.{
        .name = "util-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "ziserv-core", .module = core_module },
                .{ .name = "ziserv-util", .module = util_module },
            },
        }),
    });

    b.installArtifact(bench);

    const run_bench = b.addRunArtifact(bench);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);
}
