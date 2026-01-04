# ziserv-errors

Comprehensive error handling system for ZiServ framework, inspired by Rust's Result/Option types.

## Features

- ✅ **Result Type** - Rust-style Result<T, E>
- ✅ **Option Type** - Rust-style Option<T>
- ✅ **Error Context** - Rich error information with source location
- ✅ **Error Codes** - Standardized error codes
- ✅ **Combinators** - map, andThen, orElse, etc.
- ✅ **Zero-cost abstractions** - Compile-time optimizations

## Installation
```zig
// build.zig.zon
.dependencies = .{
    .ziserv_errors = .{
        .path = "../ziserv-errors",
    },
}
```

## Quick Start

### Result Type
```zig
const errors = @import("ziserv-errors");

fn divide(a: i32, b: i32) errors.Result(i32, error{DivisionByZero}) {
    if (b == 0) return errors.Result(i32, error{DivisionByZero}).failure(error.DivisionByZero);
    return errors.Result(i32, error{DivisionByZero}).success(@divTrunc(a, b));
}

pub fn main() void {
    const result = divide(10, 2);
    if (result.isOk()) {
        std.debug.print("Result: {d}\n", .{result.unwrap()});
    }
}
```

### Option Type
```zig
const errors = @import("ziserv-errors");

fn findUser(id: u32) errors.Option(User) {
    if (id == 0) return errors.Option(User).none();
    return errors.Option(User).some(User{ .id = id });
}
```

## API Reference

See [src/root.zig](src/root.zig) for complete API.

## License

MIT