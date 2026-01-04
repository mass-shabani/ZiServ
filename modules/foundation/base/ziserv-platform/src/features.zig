// ============================================================
// فایل: src/features.zig
// تشخیص قابلیت‌های CPU
// ============================================================

const std = @import("std");
const builtin = @import("builtin");

/// قابلیت‌های CPU
pub const CpuFeatures = struct {
    /// آیا SIMD پشتیبانی می‌شود؟
    pub fn hasSimd() bool {
        return switch (builtin.cpu.arch) {
            .x86_64, .x86 => hasX86Simd(),
            .aarch64, .arm => hasArmSimd(),
            else => false,
        };
    }

    /// آیا SSE پشتیبانی می‌شود؟ (x86)
    pub fn hasSse() bool {
        if (!isX86()) return false;
        return std.Target.x86.featureSetHas(builtin.cpu.features, .sse);
    }

    /// آیا SSE2 پشتیبانی می‌شود؟ (x86)
    pub fn hasSse2() bool {
        if (!isX86()) return false;
        return std.Target.x86.featureSetHas(builtin.cpu.features, .sse2);
    }

    /// آیا SSE3 پشتیبانی می‌شود؟ (x86)
    pub fn hasSse3() bool {
        if (!isX86()) return false;
        return std.Target.x86.featureSetHas(builtin.cpu.features, .sse3);
    }

    /// آیا SSSE3 پشتیبانی می‌شود؟ (x86)
    pub fn hasSsse3() bool {
        if (!isX86()) return false;
        return std.Target.x86.featureSetHas(builtin.cpu.features, .ssse3);
    }

    /// آیا SSE4.1 پشتیبانی می‌شود؟ (x86)
    pub fn hasSse41() bool {
        if (!isX86()) return false;
        return std.Target.x86.featureSetHas(builtin.cpu.features, .sse4_1);
    }

    /// آیا SSE4.2 پشتیبانی می‌شود؟ (x86)
    pub fn hasSse42() bool {
        if (!isX86()) return false;
        return std.Target.x86.featureSetHas(builtin.cpu.features, .sse4_2);
    }

    /// آیا AVX پشتیبانی می‌شود؟ (x86)
    pub fn hasAvx() bool {
        if (!isX86()) return false;
        return std.Target.x86.featureSetHas(builtin.cpu.features, .avx);
    }

    /// آیا AVX2 پشتیبانی می‌شود؟ (x86)
    pub fn hasAvx2() bool {
        if (!isX86()) return false;
        return std.Target.x86.featureSetHas(builtin.cpu.features, .avx2);
    }

    /// آیا AVX-512 پشتیبانی می‌شود؟ (x86)
    pub fn hasAvx512() bool {
        if (!isX86()) return false;
        return std.Target.x86.featureSetHas(builtin.cpu.features, .avx512f);
    }

    /// آیا AES-NI پشتیبانی می‌شود؟ (x86)
    pub fn hasAesNi() bool {
        if (!isX86()) return false;
        return std.Target.x86.featureSetHas(builtin.cpu.features, .aes);
    }

    /// آیا NEON پشتیبانی می‌شود؟ (ARM)
    pub fn hasNeon() bool {
        if (!isArm()) return false;
        return switch (builtin.cpu.arch) {
            .aarch64 => std.Target.aarch64.featureSetHas(builtin.cpu.features, .neon),
            .arm => std.Target.arm.featureSetHas(builtin.cpu.features, .neon),
            else => false,
        };
    }

    /// آیا CRC32 پشتیبانی می‌شود?
    pub fn hasCrc32() bool {
        return switch (builtin.cpu.arch) {
            .x86_64, .x86 => std.Target.x86.featureSetHas(builtin.cpu.features, .sse4_2),
            .aarch64 => std.Target.aarch64.featureSetHas(builtin.cpu.features, .crc),
            else => false,
        };
    }

    /// نمایش همه features
    pub fn printFeatures(writer: anytype) !void {
        try writer.writeAll("\n");
        try writer.writeAll("CPU Features:\n");
        try writer.writeAll("─────────────────────────────────────\n");

        if (isX86()) {
            try writer.print("  SSE:        {}\n", .{hasSse()});
            try writer.print("  SSE2:       {}\n", .{hasSse2()});
            try writer.print("  SSE3:       {}\n", .{hasSse3()});
            try writer.print("  SSSE3:      {}\n", .{hasSsse3()});
            try writer.print("  SSE4.1:     {}\n", .{hasSse41()});
            try writer.print("  SSE4.2:     {}\n", .{hasSse42()});
            try writer.print("  AVX:        {}\n", .{hasAvx()});
            try writer.print("  AVX2:       {}\n", .{hasAvx2()});
            try writer.print("  AVX-512:    {}\n", .{hasAvx512()});
            try writer.print("  AES-NI:     {}\n", .{hasAesNi()});
        } else if (isArm()) {
            try writer.print("  NEON:       {}\n", .{hasNeon()});
        }

        try writer.print("  CRC32:      {}\n", .{hasCrc32()});
        try writer.writeAll("\n");
    }

    // Helper functions
    fn isX86() bool {
        return switch (builtin.cpu.arch) {
            .x86_64, .x86 => true,
            else => false,
        };
    }

    fn isArm() bool {
        return switch (builtin.cpu.arch) {
            .aarch64, .arm => true,
            else => false,
        };
    }

    fn hasX86Simd() bool {
        return hasSse() or hasSse2() or hasAvx();
    }

    fn hasArmSimd() bool {
        return hasNeon();
    }
};

// تست‌ها
test "CpuFeatures: detection" {
    // فقط مطمئن می‌شویم که crash نمی‌کند
    _ = CpuFeatures.hasSimd();
    _ = CpuFeatures.hasCrc32();

    if (builtin.cpu.arch == .x86_64 or builtin.cpu.arch == .x86) {
        _ = CpuFeatures.hasSse();
        _ = CpuFeatures.hasAvx();
    }

    if (builtin.cpu.arch == .aarch64 or builtin.cpu.arch == .arm) {
        _ = CpuFeatures.hasNeon();
    }
}

test "CpuFeatures: print" {
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(std.testing.allocator);

    try CpuFeatures.printFeatures(buffer.writer(std.testing.allocator));
    try std.testing.expect(buffer.items.len > 0);
}
