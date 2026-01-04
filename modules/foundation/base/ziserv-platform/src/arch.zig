// ============================================================
// فایل: src/arch.zig
// تشخیص معماری CPU
// ============================================================

const std = @import("std");
const builtin = @import("builtin");

/// معماری‌های CPU پشتیبانی شده
pub const Arch = enum {
    x86_64,
    x86,
    aarch64,
    arm,
    riscv64,
    riscv32,
    unknown,

    /// معماری فعلی
    pub fn current() Arch {
        return switch (builtin.cpu.arch) {
            .x86_64 => .x86_64,
            .x86 => .x86,
            .aarch64 => .aarch64,
            .arm => .arm,
            .riscv64 => .riscv64,
            .riscv32 => .riscv32,
            else => .unknown,
        };
    }

    /// نام معماری
    pub fn name(self: Arch) []const u8 {
        return switch (self) {
            .x86_64 => "x86_64",
            .x86 => "x86",
            .aarch64 => "ARM64",
            .arm => "ARM",
            .riscv64 => "RISC-V 64",
            .riscv32 => "RISC-V 32",
            .unknown => "Unknown",
        };
    }

    /// تعداد بیت‌های معماری
    pub fn bits(self: Arch) u8 {
        return switch (self) {
            .x86_64, .aarch64, .riscv64 => 64,
            .x86, .arm, .riscv32 => 32,
            .unknown => 0,
        };
    }

    /// آیا 64-bit است؟
    pub fn is64Bit(self: Arch) bool {
        return self.bits() == 64;
    }

    /// آیا 32-bit است؟
    pub fn is32Bit(self: Arch) bool {
        return self.bits() == 32;
    }

    /// آیا x86 خانواده است؟
    pub fn isX86(self: Arch) bool {
        return switch (self) {
            .x86_64, .x86 => true,
            else => false,
        };
    }

    /// آیا ARM خانواده است؟
    pub fn isArm(self: Arch) bool {
        return switch (self) {
            .aarch64, .arm => true,
            else => false,
        };
    }

    /// آیا RISC-V خانواده است؟
    pub fn isRiscV(self: Arch) bool {
        return switch (self) {
            .riscv64, .riscv32 => true,
            else => false,
        };
    }

    /// Endianness
    pub fn endian(self: Arch) std.builtin.Endian {
        _ = self;
        return builtin.cpu.arch.endian();
    }

    /// آیا little-endian است؟
    pub fn isLittleEndian(self: Arch) bool {
        return self.endian() == .little;
    }

    /// آیا big-endian است؟
    pub fn isBigEndian(self: Arch) bool {
        return self.endian() == .big;
    }

    /// اندازه pointer (bytes)
    pub fn pointerSize(self: Arch) usize {
        return self.bits() / 8;
    }

    /// Alignment پیش‌فرض
    pub fn defaultAlignment(self: Arch) usize {
        return self.pointerSize();
    }
};

// تست‌ها
test "Arch: current" {
    const arch = Arch.current();
    try std.testing.expect(arch != .unknown);
}

test "Arch: bits" {
    const arch = Arch.current();
    const bits_val = arch.bits();

    if (arch != .unknown) {
        try std.testing.expect(bits_val == 32 or bits_val == 64);
    }
}

test "Arch: endianness" {
    const arch = Arch.current();

    const is_little = arch.isLittleEndian();
    const is_big = arch.isBigEndian();

    // یکی از دو باید true باشد
    try std.testing.expect(is_little or is_big);
    try std.testing.expect(!(is_little and is_big));
}

test "Arch: pointer size" {
    const arch = Arch.current();
    const ptr_size = arch.pointerSize();

    if (arch.is64Bit()) {
        try std.testing.expectEqual(@as(usize, 8), ptr_size);
    } else if (arch.is32Bit()) {
        try std.testing.expectEqual(@as(usize, 4), ptr_size);
    }
}

test "Arch: families" {
    const arch = Arch.current();

    // فقط یکی از خانواده‌ها باید true باشد (یا هیچکدام)
    const families = [_]bool{
        arch.isX86(),
        arch.isArm(),
        arch.isRiscV(),
    };

    var count: usize = 0;
    for (families) |is_family| {
        if (is_family) count += 1;
    }

    try std.testing.expect(count <= 1);
}
