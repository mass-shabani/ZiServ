const std = @import("std");
const platform = @import("ziserv-platform");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("\n", .{});
    std.debug.print("╔════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         ziserv-platform Example                            ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // 1. اطلاعات پلتفرم
    const info = platform.PlatformInfo.current();

    std.debug.print("OS: {s}\n", .{info.os.name()});
    std.debug.print("Architecture: {s} ({d}-bit)\n", .{ info.arch.name(), info.arch.bits() });
    std.debug.print("CPU Count: {d}\n", .{info.cpu_count});
    std.debug.print("Page Size: {d} bytes\n", .{info.page_size});
    std.debug.print("Endian: {s}\n", .{@tagName(info.endian)});
    std.debug.print("\n", .{});

    // 2. توضیحات کامل
    const desc = try info.description(allocator);
    defer allocator.free(desc);
    std.debug.print("Description: {s}\n\n", .{desc});

    // 3. Path separator
    std.debug.print("Path Separator: '{c}'\n", .{platform.Platform.pathSeparator()});
    std.debug.print("Exe Extension: '{s}'\n", .{platform.Platform.exeExtension()});
    std.debug.print("DLL Extension: '{s}'\n", .{platform.Platform.dynlibExtension()});
    std.debug.print("\n", .{});

    // 4. CPU Features
    std.debug.print("CPU Features:\n", .{});
    std.debug.print("  SIMD: {}\n", .{platform.features.CpuFeatures.hasSimd()});
    std.debug.print("  CRC32: {}\n", .{platform.features.CpuFeatures.hasCrc32()});

    if (info.arch.isX86()) {
        std.debug.print("  SSE: {}\n", .{platform.features.CpuFeatures.hasSse()});
        std.debug.print("  AVX: {}\n", .{platform.features.CpuFeatures.hasAvx()});
        std.debug.print("  AVX2: {}\n", .{platform.features.CpuFeatures.hasAvx2()});
    }
    std.debug.print("\n", .{});

    // 5. Environment Variables
    if (try platform.env.Env.Common.home(allocator)) |home| {
        defer allocator.free(home);
        std.debug.print("Home Directory: {s}\n", .{home});
    }

    if (try platform.env.Env.Common.user(allocator)) |user| {
        defer allocator.free(user);
        std.debug.print("Username: {s}\n", .{user});
    }
    std.debug.print("\n", .{});

    // 6. Syscalls
    const cwd = try platform.syscalls.Syscalls.getcwd(allocator);
    defer allocator.free(cwd);
    std.debug.print("Current Directory: {s}\n", .{cwd});

    const pid = platform.syscalls.Syscalls.getpid();
    std.debug.print("Process ID: {d}\n", .{pid});

    var hostname_buf: [256]u8 = undefined;
    const hostname = try platform.syscalls.Syscalls.hostname(&hostname_buf);
    std.debug.print("Hostname: {s}\n", .{hostname});

    std.debug.print("\n", .{});
    std.debug.print("╔════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         Example Completed Successfully!                    ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});
}
