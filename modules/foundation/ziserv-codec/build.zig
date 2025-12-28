// ============================================================
// فایل: modules/foundation/ziserv-codec/build.zig
// ============================================================

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // وابستگی‌ها
    const core_dep = b.dependency("ziserv_core", .{
        .target = target,
        .optimize = optimize,
    });
    const bytes_dep = b.dependency("ziserv_bytes", .{
        .target = target,
        .optimize = optimize,
    });

    const core_module = core_dep.module("ziserv-core");
    const bytes_module = bytes_dep.module("ziserv-bytes");

    // ساخت ماژول codec
    const codec_module = b.addModule("ziserv-codec", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    codec_module.addImport("ziserv-core", core_module);
    codec_module.addImport("ziserv-bytes", bytes_module);

    // تست‌ها
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ziserv-core", .module = core_module },
                .{ .name = "ziserv-bytes", .module = bytes_module },
            },
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run codec module tests");
    test_step.dependOn(&run_tests.step);

    // Benchmark
    const bench = b.addExecutable(.{
        .name = "codec-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "ziserv-core", .module = core_module },
                .{ .name = "ziserv-bytes", .module = bytes_module },
                .{ .name = "ziserv-codec", .module = codec_module },
            },
        }),
    });

    b.installArtifact(bench);

    const run_bench = b.addRunArtifact(bench);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);
}
