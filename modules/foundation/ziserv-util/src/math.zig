// ============================================================
// فایل: modules/foundation/ziserv-util/src/math.zig
// Math utilities - بهینه‌سازی شده
// ============================================================

const std = @import("std");

/// Min - generic
pub inline fn min(comptime T: type, a: T, b: T) T {
    return @min(a, b);
}

/// Max - generic
pub inline fn max(comptime T: type, a: T, b: T) T {
    return @max(a, b);
}

/// Clamp value between min and max
pub inline fn clamp(comptime T: type, value: T, minimum: T, maximum: T) T {
    return @max(minimum, @min(maximum, value));
}

/// Absolute value
pub inline fn abs(comptime T: type, value: T) T {
    return if (value < 0) -value else value;
}

/// Sign (-1, 0, or 1)
pub inline fn sign(comptime T: type, value: T) T {
    if (value > 0) return 1;
    if (value < 0) return -1;
    return 0;
}

/// Power of 2 check
pub inline fn isPowerOfTwo(value: anytype) bool {
    return value > 0 and (value & (value - 1)) == 0;
}

/// Next power of 2
pub fn nextPowerOfTwo(comptime T: type, value: T) T {
    if (value == 0) return 1;
    if (isPowerOfTwo(value)) return value;

    var v = value - 1;
    var shift: u6 = 1;
    while (shift < @bitSizeOf(T)) : (shift <<= 1) {
        v |= v >> shift;
    }
    return v + 1;
}

/// Align up to multiple
pub inline fn alignUp(value: usize, alignment: usize) usize {
    const mask = alignment - 1;
    return (value + mask) & ~mask;
}

/// Align down to multiple
pub inline fn alignDown(value: usize, alignment: usize) usize {
    return value & ~(alignment - 1);
}

/// Linear interpolation
pub inline fn lerp(comptime T: type, a: T, b: T, t: T) T {
    return a + (b - a) * t;
}

/// Map value from one range to another
pub fn map(comptime T: type, value: T, in_min: T, in_max: T, out_min: T, out_max: T) T {
    return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

/// Average
pub fn average(comptime T: type, values: []const T) T {
    if (values.len == 0) return 0;

    var sum: T = 0;
    for (values) |v| {
        sum += v;
    }
    return @divTrunc(sum, @as(T, @intCast(values.len)));
}

/// Sum
pub fn sum(comptime T: type, values: []const T) T {
    var result: T = 0;
    for (values) |v| {
        result += v;
    }
    return result;
}

/// Product
pub fn product(comptime T: type, values: []const T) T {
    if (values.len == 0) return 0;

    var result: T = 1;
    for (values) |v| {
        result *= v;
    }
    return result;
}

/// GCD (Greatest Common Divisor)
pub fn gcd(comptime T: type, a: T, b: T) T {
    var x = a;
    var y = b;
    while (y != 0) {
        const temp = y;
        y = @mod(x, y);
        x = temp;
    }
    return x;
}

/// LCM (Least Common Multiple)
pub fn lcm(comptime T: type, a: T, b: T) T {
    if (a == 0 or b == 0) return 0;
    return @divTrunc(abs(T, a * b), gcd(T, a, b));
}

/// Factorial
pub fn factorial(n: u64) u64 {
    if (n <= 1) return 1;
    var result: u64 = 1;
    var i: u64 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    return result;
}

/// Fibonacci (iterative)
pub fn fibonacci(n: u64) u64 {
    if (n <= 1) return n;

    var a: u64 = 0;
    var b: u64 = 1;
    var i: u64 = 2;
    while (i <= n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

/// Fast integer square root
pub fn isqrt(value: u64) u64 {
    if (value < 2) return value;

    var x = value;
    var y = (x + 1) / 2;

    while (y < x) {
        x = y;
        y = (x + value / x) / 2;
    }

    return x;
}

/// Check if prime
pub fn isPrime(n: u64) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;

    var i: u64 = 3;
    const sqrt_n = isqrt(n);
    while (i <= sqrt_n) : (i += 2) {
        if (n % i == 0) return false;
    }
    return true;
}

/// Random number generator utilities
pub const Random = struct {
    /// Random integer in range [min, max]
    pub fn intRange(rng: std.Random, comptime T: type, min: T, max: T) T {
        return rng.intRangeAtMost(T, min, max);
    }

    /// Random float in range [0, 1)
    pub fn float(rng: std.Random, comptime T: type) T {
        return rng.float(T);
    }

    /// Random float in range [min, max)
    pub fn floatRange(rng: std.Random, comptime T: type, minimum: T, maximum: T) T {
        return minimum + rng.float(T) * (maximum - minimum);
    }

    /// Random boolean
    pub fn boolean(rng: std.Random) bool {
        return rng.boolean();
    }

    /// Shuffle slice
    pub fn shuffle(rng: std.Random, comptime T: type, slice: []T) void {
        if (slice.len < 2) return;

        var i = slice.len - 1;
        while (i > 0) : (i -= 1) {
            const j = rng.intRangeLessThan(usize, 0, i + 1);
            const tmp = slice[i];
            slice[i] = slice[j];
            slice[j] = tmp;
        }
    }

    /// Random choice from slice
    pub fn choice(rng: std.Random, comptime T: type, slice: []const T) T {
        const index = rng.intRangeLessThan(usize, 0, slice.len);
        return slice[index];
    }
};

/// Statistics utilities
pub const Stats = struct {
    /// Mean (average)
    pub fn mean(comptime T: type, values: []const T) f64 {
        if (values.len == 0) return 0;

        var sum: f64 = 0;
        for (values) |v| {
            sum += @as(f64, @floatFromInt(v));
        }
        return sum / @as(f64, @floatFromInt(values.len));
    }

    /// Median
    pub fn median(comptime T: type, values: []const T, buffer: []T) f64 {
        if (values.len == 0) return 0;

        @memcpy(buffer[0..values.len], values);
        std.mem.sort(T, buffer[0..values.len], {}, std.sort.asc(T));

        const mid = values.len / 2;
        if (values.len % 2 == 0) {
            return (@as(f64, @floatFromInt(buffer[mid - 1])) + @as(f64, @floatFromInt(buffer[mid]))) / 2.0;
        }
        return @as(f64, @floatFromInt(buffer[mid]));
    }

    /// Variance
    pub fn variance(comptime T: type, values: []const T) f64 {
        if (values.len == 0) return 0;

        const m = mean(T, values);
        var sum: f64 = 0;
        for (values) |v| {
            const diff = @as(f64, @floatFromInt(v)) - m;
            sum += diff * diff;
        }
        return sum / @as(f64, @floatFromInt(values.len));
    }

    /// Standard deviation
    pub fn stddev(comptime T: type, values: []const T) f64 {
        return @sqrt(variance(T, values));
    }

    /// Min value
    pub fn minValue(comptime T: type, values: []const T) ?T {
        if (values.len == 0) return null;

        var result = values[0];
        for (values[1..]) |v| {
            if (v < result) result = v;
        }
        return result;
    }

    /// Max value
    pub fn maxValue(comptime T: type, values: []const T) ?T {
        if (values.len == 0) return null;

        var result = values[0];
        for (values[1..]) |v| {
            if (v > result) result = v;
        }
        return result;
    }
};

test "basic math" {
    try std.testing.expectEqual(@as(i32, 5), min(i32, 5, 10));
    try std.testing.expectEqual(@as(i32, 10), max(i32, 5, 10));
    try std.testing.expectEqual(@as(i32, 5), clamp(i32, 3, 5, 10));
    try std.testing.expectEqual(@as(i32, 5), abs(i32, -5));
}

test "power of two" {
    try std.testing.expect(isPowerOfTwo(8));
    try std.testing.expect(!isPowerOfTwo(7));
    try std.testing.expectEqual(@as(u32, 8), nextPowerOfTwo(u32, 5));
}

test "gcd and lcm" {
    try std.testing.expectEqual(@as(i32, 6), gcd(i32, 48, 18));
    try std.testing.expectEqual(@as(i32, 144), lcm(i32, 48, 18));
}

test "factorial" {
    try std.testing.expectEqual(@as(u64, 120), factorial(5));
    try std.testing.expectEqual(@as(u64, 1), factorial(0));
}

test "fibonacci" {
    try std.testing.expectEqual(@as(u64, 0), fibonacci(0));
    try std.testing.expectEqual(@as(u64, 1), fibonacci(1));
    try std.testing.expectEqual(@as(u64, 55), fibonacci(10));
}

test "is prime" {
    try std.testing.expect(isPrime(7));
    try std.testing.expect(!isPrime(8));
    try std.testing.expect(isPrime(97));
}

test "statistics" {
    const values = [_]i32{ 1, 2, 3, 4, 5 };
    try std.testing.expectEqual(@as(f64, 3.0), Stats.mean(i32, &values));
    try std.testing.expectEqual(@as(i32, 1), Stats.minValue(i32, &values).?);
    try std.testing.expectEqual(@as(i32, 5), Stats.maxValue(i32, &values).?);
}
