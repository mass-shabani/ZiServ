# ziserv-platform

Platform detection and system utilities for ZiServ framework.

## Features

- ✅ Operating system detection (Linux, Windows, macOS, BSD)
- ✅ CPU architecture detection (x86_64, ARM64, RISC-V)
- ✅ System information (page size, CPU count, endianness)
- ✅ Environment variable utilities
- ✅ CPU feature detection (SIMD, AVX)
- ✅ Cross-platform syscall wrappers

## Installation
```zig
// build.zig.zon
.dependencies = .{
    .ziserv_platform = .{
        .path = "../ziserv-platform",
    },
}
```

## Quick Start
```zig
const platform = @import("ziserv-platform");

pub fn main() void {
    const info = platform.PlatformInfo.current();
    
    std.debug.print("OS: {s}\n", .{info.os.name()});
    std.debug.print("Arch: {s}\n", .{info.arch.name()});
    std.debug.print("CPU Count: {d}\n", .{info.cpu_count});
    std.debug.print("Page Size: {d}\n", .{info.page_size});
}
```

## API Reference

See [src/root.zig](src/root.zig) for complete API.

## License

MIT