// ============================================================
// فایل: src/info.zig
// اطلاعات جامع پلتفرم
// ============================================================

const std = @import("std");
const builtin = @import("builtin");
const Os = @import("os.zig").Os;
const Arch = @import("arch.zig").Arch;

/// اطلاعات کامل پلتفرم
pub const PlatformInfo = struct {
    os: Os,
    arch: Arch,
    cpu_count: usize,
    page_size: usize,
    is_debug: bool,
    is_safe: bool,
    endian: std.builtin.Endian,

    /// دریافت اطلاعات پلتفرم فعلی
    pub fn current() PlatformInfo {
        return .{
            .os = Os.current(),
            .arch = Arch.current(),
            .cpu_count = Platform.cpuCount() catch 1,
            .page_size = Platform.pageSize(),
            .is_debug = builtin.mode == .Debug,
            .is_safe = builtin.mode == .ReleaseSafe,
            .endian = builtin.cpu.arch.endian(),
        };
    }

    /// توضیحات متنی
    pub fn description(self: PlatformInfo, allocator: std.mem.Allocator) ![]u8 {
        const mode = if (self.is_debug)
            "Debug"
        else if (self.is_safe)
            "ReleaseSafe"
        else
            "Release";

        return try std.fmt.allocPrint(
            allocator,
            "{s} {s} ({d}-bit, {s}) - {s}",
            .{
                self.os.name(),
                self.arch.name(),
                self.arch.bits(),
                @tagName(self.endian),
                mode,
            },
        );
    }

    /// آیا پلتفرم پشتیبانی می‌شود؟
    pub fn isSupported(self: PlatformInfo) bool {
        return self.os.isSupported() and self.arch != .unknown;
    }
};

/// توابع utility پلتفرم
pub const Platform = struct {
    /// تعداد هسته‌های CPU
    pub fn cpuCount() !usize {
        return try std.Thread.getCpuCount();
    }

    /// اندازه صفحه حافظه
    pub fn pageSize() usize {
        if (builtin.os.tag == .windows) {
            // Windows: استفاده از GetSystemInfo
            var info: std.os.windows.SYSTEM_INFO = undefined;
            std.os.windows.kernel32.GetSystemInfo(&info);
            return info.dwPageSize;
        } else {
            // POSIX (Linux, macOS, BSD): استفاده از sysconf
            return std.os.sysconf(std.os.system._SC.PAGESIZE);
        }
    }

    /// جداکننده مسیر
    pub fn pathSeparator() u8 {
        return Os.current().pathSeparator();
    }

    /// جداکننده مسیر (رشته)
    pub fn pathSeparatorStr() []const u8 {
        return Os.current().pathSeparatorStr();
    }

    /// خط جدید
    pub fn newline() []const u8 {
        return Os.current().newline();
    }

    /// null device
    pub fn nullDevice() []const u8 {
        return Os.current().nullDevice();
    }

    /// پسوند executable
    pub fn exeExtension() []const u8 {
        return Os.current().exeExtension();
    }

    /// پسوند dynamic library
    pub fn dynlibExtension() []const u8 {
        return Os.current().dynlibExtension();
    }

    /// حداکثر طول مسیر
    pub fn maxPathLen() usize {
        return Os.current().maxPathLen();
    }

    /// نمایش اطلاعات سیستم
    pub fn printInfo(writer: anytype) !void {
        const info = PlatformInfo.current();

        try writer.writeAll("\n");
        try writer.writeAll("╔════════════════════════════════════════════════════════════╗\n");
        try writer.writeAll("║              Platform Information                          ║\n");
        try writer.writeAll("╠════════════════════════════════════════════════════════════╣\n");
        try writer.print("║  OS:              {s:<45}║\n", .{info.os.name()});
        try writer.print("║  Architecture:    {s:<45}║\n", .{info.arch.name()});
        try writer.print("║  Bits:            {d:<45}║\n", .{info.arch.bits()});
        try writer.print("║  Endian:          {s:<45}║\n", .{@tagName(info.endian)});
        try writer.print("║  CPU Count:       {d:<45}║\n", .{info.cpu_count});
        try writer.print("║  Page Size:       {d} bytes{s:37}║\n", .{ info.page_size, "" });
        try writer.print("║  Build Mode:      {s:<45}║\n", .{
            if (info.is_debug) "Debug" else if (info.is_safe) "ReleaseSafe" else "Release",
        });
        try writer.writeAll("╚════════════════════════════════════════════════════════════╝\n");
        try writer.writeAll("\n");
    }
};

// تست‌ها
test "PlatformInfo: current" {
    const info = PlatformInfo.current();

    try std.testing.expect(info.cpu_count > 0);
    try std.testing.expect(info.page_size > 0);
    try std.testing.expect(info.page_size % 1024 == 0); // معمولاً مضربی از 1024
}

test "PlatformInfo: description" {
    const info = PlatformInfo.current();
    const desc = try info.description(std.testing.allocator);
    defer std.testing.allocator.free(desc);

    try std.testing.expect(desc.len > 0);
}

test "Platform: utilities" {
    const cpu_count = try Platform.cpuCount();
    try std.testing.expect(cpu_count > 0);

    const page_size = Platform.pageSize();
    try std.testing.expect(page_size > 0);

    const sep = Platform.pathSeparator();
    try std.testing.expect(sep == '/' or sep == '\\');

    const nl = Platform.newline();
    try std.testing.expect(nl.len > 0);
}
