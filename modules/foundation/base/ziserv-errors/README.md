# ziserv-errors

Comprehensive error handling system for ZiServ framework, inspired by Rust's Result/Option types.

## Features

- ✅ **Result Type** - Rust-style Result<T, E>
- ✅ **Option Type** - Rust-style Option<T>
- ✅ **Error Context** - Rich error information with source location
- ✅ **Error Codes** - Standardized error codes (HTTP-inspired)
- ✅ **Combinators** - map, andThen, orElse, filter, etc.
- ✅ **Zero-cost abstractions** - Compile-time optimizations
- ✅ **Collection utilities** - filterOk, partition, collect, etc.

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

pub fn main() !void {
    const result = divide(10, 2);
    if (result.isOk()) {
        std.debug.print("Result: {d}\n", .{result.unwrap()});
    }
    
    // Chaining operations
    const doubled = result.map(i32, doubleFunc).unwrapOr(0);
}
```

### Option Type

```zig
const errors = @import("ziserv-errors");

fn findUser(id: u32) errors.Option(User) {
    if (id == 0) return errors.Option(User).none();
    return errors.Option(User).some(User{ .id = id });
}

pub fn main() !void {
    const user = findUser(1);
    if (user.isSome()) {
        std.debug.print("User: {s}\n", .{user.unwrap().name});
    }
}
```

### Error Context

```zig
const errors = @import("ziserv-errors");

fn doSomething() !void {
    const ctx = errors.Context.init("Operation failed", @src());
    const err = errors.ErrorWithContext(errors.Error).withContext(error.Failed, ctx);
    
    std.debug.print("Error: {}\n", .{err});
}
```

### Combinators

```zig
const errors = @import("ziserv-errors");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    const R = errors.Result(i32, error{Failed});
    const results = [_]R{
        R.success(1),
        R.success(2),
        R.failure(error.Failed),
        R.success(3),
    };
    
    // Filter successful results
    const ok_values = try errors.combinators.filterOk(i32, error{Failed}, allocator, &results);
    defer allocator.free(ok_values);
    
    // Partition into Ok and Err
    const partition = try errors.combinators.partitionResults(i32, error{Failed}, allocator, &results);
    defer allocator.free(partition.ok);
    defer allocator.free(partition.err);
}
```

## API Reference

### Core Types

- **Result<T, E>** - Result type with Ok/Err variants
  - `ok: T` - Success variant
  - `failure: E` - Error variant (renamed from `err` to avoid keyword conflict)
  
- **Option<T>** - Optional value with Some/None variants
  - `some: T` - Value present
  - `none` - No value
  
- **Error** - Common error types
- **ErrorContext** - Rich error context with source location
- **ErrorCode** - HTTP-inspired error codes

### Methods

#### Result\<T, E\>

**Constructors:**
- `success(value: T)` - Create successful result
- `failure(err: E)` - Create failed result

**Query methods:**
- `isOk()` - Check if Ok
- `isErr()` - Check if Err

**Extract methods:**
- `unwrap()` - Get value or panic
- `unwrapErr()` - Get error or panic
- `unwrapOr(default: T)` - Get value or default
- `unwrapOrElse(f: fn(E) T)` - Get value or compute from error
- `ok()` - Convert to ?T
- `err()` - Convert error to ?E

**Combinators:**
- `map(U, f: fn(T) U)` - Transform success value
- `mapErr(F, f: fn(E) F)` - Transform error value
- `andThen(U, f: fn(T) Result(U, E))` - Chain operations
- `orElse(f: fn(E) Self)` - Handle error
- `andResult(other: Self)` - Combine results (AND)
- `orResult(other: Self)` - Combine results (OR)

#### Option\<T\>

**Constructors:**
- `some(value: T)` - Create Some
- `none()` - Create None
- `fromNullable(?T)` - Convert from nullable

**Query methods:**
- `isSome()` - Check if Some
- `isNone()` - Check if None

**Extract methods:**
- `unwrap()` - Get value or panic
- `unwrapOr(default: T)` - Get value or default
- `unwrapOrElse(f: fn() T)` - Get value or compute
- `toNullable()` - Convert to ?T

**Combinators:**
- `map(U, f: fn(T) U)` - Transform value
- `andThen(U, f: fn(T) Option(U))` - Chain operations
- `filter(predicate: fn(T) bool)` - Filter by condition
- `andOption(other: Self)` - Combine options (AND)
- `orOption(other: Self)` - Combine options (OR)
- `orElse(f: fn() Self)` - Provide alternative

**Conversion to Result:**
- `okOr(E, err: E)` - Convert to Result with error
- `okOrElse(E, f: fn() E)` - Convert to Result with computed error

#### Combinators Module

**Result utilities:**
- `filterOk(T, E, allocator, results)` - Filter successful results
- `filterErr(T, E, allocator, results)` - Filter failed results
- `partitionResults(T, E, allocator, results)` - Split into Ok/Err arrays
- `collectResults(T, E, allocator, results)` - Collect into single Result
- `mapResults(T, U, E, allocator, results, f)` - Map over successful results

**Option utilities:**
- `filterSome(T, allocator, options)` - Filter Some values
- `collectOptions(T, allocator, options)` - Collect into single Option
- `findSome(T, options)` - Find first Some
- `mapOptions(T, U, allocator, options, f)` - Map over Some values

**Mixed utilities:**
- `optionToResult(T, E, option, err)` - Convert Option to Result
- `resultToOption(T, E, result)` - Convert Result to Option
- `filter(T, value, predicate)` - Filter value into Option
- `tryCatch(T, E, f)` - Try function and wrap in Result

### Error Types

Common errors categorized by domain:

**Categories:**
- `general` - General errors
- `io` - I/O operations
- `network` - Network operations
- `parse` - Parsing errors
- `validation` - Validation errors
- `memory` - Memory allocation
- `platform` - Platform-specific
- `security` - Security violations
- `timeout` - Timeout errors
- `config` - Configuration errors

**Severity levels:**
- `info` - Informational
- `warning` - Needs attention
- `error` - Needs handling
- `critical` - Needs immediate action

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

## Examples

See `example.zig` for comprehensive usage examples including:
1. Basic Result usage
2. Result chaining
3. Basic Option usage
4. Option chaining
5. Error context
6. Combinators
7. Real-world scenarios

## Documentation

See [src/](src/) for detailed API documentation in code comments.

## Compatibility

- **Zig Version:** 0.15.2 or higher
- **Platforms:** Linux, Windows, macOS
- **Architectures:** x86_64, aarch64, arm

## License

MIT