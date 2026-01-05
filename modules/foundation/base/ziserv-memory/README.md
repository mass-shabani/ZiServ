# ziserv-memory

High-performance memory management system for ZiServ framework with multiple allocator strategies and comprehensive tracking capabilities.

## Features

- ✅ **Allocator Wrapper** - Enhanced std.mem.Allocator with utilities
- ✅ **Arena Allocator** - Fast temporary allocations with batch deallocation
- ✅ **Bump Allocator** - Ultra-fast linear allocation
- ✅ **Object Pool** - High-performance object reuse
- ✅ **Memory Tracking** - Debug and profiling with leak detection
- ✅ **Memory Statistics** - Comprehensive usage metrics
- ✅ **Thread-Safe Variants** - Safe concurrent allocations
- ✅ **Bounded Allocators** - Memory limit enforcement
- ✅ **Growing Allocators** - Auto-expanding buffers

## Installation

```zig
// build.zig.zon
.dependencies = .{
    .ziserv_memory = .{
        .path = "../ziserv-memory",
    },
}
```

## Quick Start

### Basic Allocator

```zig
const memory = @import("ziserv-memory");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();

var alloc = memory.Allocator.init(gpa.allocator());

const slice = try alloc.alloc(u8, 100);
defer alloc.free(slice);
```

### Arena Allocator

```zig
var arena = memory.Arena.init(gpa.allocator());
defer arena.deinit();

const allocator = arena.allocator();

// همه allocations با یک deinit آزاد می‌شوند
const slice1 = try allocator.alloc(u8, 100);
const slice2 = try allocator.alloc(u32, 50);
```

### Bump Allocator

```zig
var buffer: [4096]u8 = undefined;
var bump = memory.BumpAllocator.init(&buffer);

const allocator = bump.allocator();

const slice = try allocator.alloc(u8, 1024);

// Reset برای reuse
bump.reset();
```

### Object Pool

```zig
const Connection = struct {
    id: u32,
    active: bool,
};

var pool = try memory.Pool(Connection).init(allocator, 10);
defer pool.deinit();

const conn = try pool.acquire();
defer pool.release(conn);

conn.id = 42;
```

### Memory Tracker

```zig
var tracker = memory.Tracker.init(allocator);
defer tracker.deinit();

const alloc = tracker.allocator();

const slice = try alloc.alloc(u8, 1000);
alloc.free(slice);

const stats = tracker.report();
stats.print(std.io.getStdOut().writer());
```

## Performance Characteristics

### Allocator Comparison (1KB allocations)

| Allocator Type | Speed | Memory Overhead | Use Case |
|---------------|-------|-----------------|----------|
| Bump | ⚡ Fastest | 🟢 None | Temporary, sequential |
| Arena | ⚡ Very Fast | 🟢 Low | Per-request, batch |
| Pool | ⚡ Very Fast | 🟡 Medium | Object reuse |
| GPA | 🟡 Moderate | 🟡 Medium | General purpose |
| Tracker | 🔴 Slower | 🔴 High | Debug/profiling |

### When to Use Each

**Bump Allocator:**
- Ultra-fast temporary allocations
- Sequential access patterns
- No individual frees needed
- Perfect for parsing, temporary buffers

**Arena Allocator:**
- Per-request memory management
- Batch allocations with single cleanup
- HTTP request handlers
- Command processing

**Object Pool:**
- Frequently allocated/deallocated objects
- Consistent object sizes
- Connection pools
- Worker threads

**Memory Tracker:**
- Development/debugging
- Memory leak detection
- Performance profiling
- Production monitoring

## API Reference

### Core Types

#### Allocator
```zig
pub const Allocator = struct {
    pub fn init(backing: std.mem.Allocator) Allocator;
    pub fn allocator(self: *Allocator) std.mem.Allocator;
    pub fn alloc(self: *Allocator, comptime T: type, n: usize) ![]T;
    pub fn free(self: *Allocator, memory: anytype) void;
    pub fn create(self: *Allocator, comptime T: type) !*T;
    pub fn destroy(self: *Allocator, ptr: anytype) void;
};
```

#### Arena
```zig
pub const Arena = struct {
    pub fn init(child: std.mem.Allocator) Arena;
    pub fn deinit(self: *Arena) void;
    pub fn allocator(self: *Arena) std.mem.Allocator;
    pub fn reset(self: *Arena) void;
};
```

#### BumpAllocator
```zig
pub const BumpAllocator = struct {
    pub fn init(buffer: []u8) BumpAllocator;
    pub fn allocator(self: *BumpAllocator) std.mem.Allocator;
    pub fn reset(self: *BumpAllocator) void;
    pub fn used(self: BumpAllocator) usize;
    pub fn remaining(self: BumpAllocator) usize;
};
```

#### Pool(T)
```zig
pub fn Pool(comptime T: type) type {
    return struct {
        pub fn init(allocator: std.mem.Allocator, capacity: usize) !Pool(T);
        pub fn deinit(self: *Pool(T)) void;
        pub fn acquire(self: *Pool(T)) !*T;
        pub fn release(self: *Pool(T), item: *T) void;
        pub fn available_count(self: Pool(T)) usize;
        pub fn in_use_count(self: Pool(T)) usize;
    };
}
```

#### Tracker
```zig
pub const Tracker = struct {
    pub fn init(child: std.mem.Allocator) Tracker;
    pub fn deinit(self: *Tracker) void;
    pub fn allocator(self: *Tracker) std.mem.Allocator;
    pub fn report(self: *Tracker) Stats;
    pub fn check_leaks(self: *Tracker, writer: anytype) !bool;
};
```

#### Stats
```zig
pub const Stats = struct {
    total_allocated: usize,
    total_freed: usize,
    peak_usage: usize,
    current_usage: usize,
    allocation_count: usize,
    free_count: usize,
    
    pub fn print(self: Stats, writer: anytype) !void;
    pub fn utilizationPercent(self: Stats) f64;
    pub fn averageAllocationSize(self: Stats) usize;
};
```

### Advanced Features

#### BoundedArena
Arena with memory limit enforcement:
```zig
var arena = memory.BoundedArena.init(allocator, 2048);
defer arena.deinit();

const alloc = arena.allocator();
// Allocations exceeding 2048 bytes will fail
```

#### GrowingBumpAllocator
Bump allocator that can grow:
```zig
var bump = try memory.GrowingBumpAllocator.init(allocator, 1024);
defer bump.deinit();

const alloc = bump.allocator_interface();
// Automatically allocates new buffers when needed
```

#### ThreadSafePool
Thread-safe object pool:
```zig
var pool = try memory.ThreadSafePool(T).init(allocator, 100);
defer pool.deinit();
// Safe for concurrent access
```

## Running Tests

```bash
zig build test
```

## Running Benchmarks

```bash
zig build bench
```

## Running Examples

```bash
zig build example
```

## Best Practices

### Arena for Request Handling
```zig
fn handleRequest(req: Request) !void {
    var arena = memory.Arena.init(global_allocator);
    defer arena.deinit();
    
    const allocator = arena.allocator();
    // All request-scoped allocations use arena
    // Automatic cleanup on function exit
}
```

### Pool for Connection Management
```zig
var connection_pool = try memory.Pool(Connection).init(allocator, 100);
defer connection_pool.deinit();

fn getConnection() !*Connection {
    return connection_pool.acquire();
}

fn releaseConnection(conn: *Connection) void {
    connection_pool.release(conn);
}
```

### Bump for Parsing
```zig
fn parseData(data: []const u8) !ParseResult {
    var buffer: [8192]u8 = undefined;
    var bump = memory.BumpAllocator.init(&buffer);
    
    const allocator = bump.allocator();
    // Ultra-fast allocations during parsing
    // No cleanup code needed
}
```

### Tracker in Development
```zig
test "no memory leaks" {
    var tracker = memory.Tracker.init(std.testing.allocator);
    defer tracker.deinit();
    
    const allocator = tracker.allocator();
    
    // Your test code here
    
    try tracker.check_leaks(std.io.getStdErr().writer());
}
```

## Examples

See `example.zig` for comprehensive usage examples including:
1. Basic Allocator
2. Arena Allocator
3. Bump Allocator
4. Object Pool
5. Memory Tracker
6. Bounded Arena
7. Growing Bump Allocator

## Documentation

See [src/](src/) for detailed API documentation in code comments.

## Compatibility

- **Zig Version:** 0.15.2 or higher
- **Platforms:** Linux, Windows, macOS
- **Architectures:** x86_64, aarch64, arm

## Performance Tips

1. **Use Bump for temporary data** - 10-100x faster than GPA
2. **Use Arena for request scope** - Simple cleanup, good performance
3. **Use Pool for hot paths** - Eliminates allocation overhead
4. **Reserve Tracker for debug** - Significant overhead in production

## License

MIT