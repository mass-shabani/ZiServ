// ============================================================
// فایل: modules/foundation/ziserv-core/build.zig
// ============================================================

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ساخت ماژول core
    _ = b.addModule("ziserv-core", .{
        .root_source_file = b.path("src/bench.zig"),
        .target = target,
        .optimize = optimize,
    });

    // تست‌های ماژول
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run core module tests");
    test_step.dependOn(&run_tests.step);
}
