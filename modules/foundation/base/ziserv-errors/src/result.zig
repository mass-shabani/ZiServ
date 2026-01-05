// ============================================================
// فایل: src/result.zig
// Result Type - Rust-style Result<T, E>
// ============================================================

const std = @import("std");

/// Result Type - مشابه Rust
///
/// نمایش نتیجه یک عملیات که ممکن است موفق (Ok) یا ناموفق (Err) باشد
///
/// # Example
/// ```zig
/// const R = Result(i32, error{Failed});
///
/// fn divide(a: i32, b: i32) R {
///     if (b == 0) return R.failure(error.Failed);
///     return R.success(@divTrunc(a, b));
/// }
///
/// const result = divide(10, 2);
/// if (result.isOk()) {
///     std.debug.print("Result: {d}\n", .{result.unwrap()});
/// }
/// ```
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,

        const Self = @This();

        // ─────────────────────────────────────────────────────────
        // Constructors
        // ─────────────────────────────────────────────────────────

        /// ایجاد نتیجه موفق
        pub fn success(value: T) Self {
            return .{ .ok = value };
        }

        /// ایجاد نتیجه ناموفق
        pub fn failure(e: E) Self {
            return .{ .err = e };
        }

        // ─────────────────────────────────────────────────────────
        // Query methods
        // ─────────────────────────────────────────────────────────

        /// آیا نتیجه موفق است؟
        pub fn isOk(self: Self) bool {
            return self == .ok;
        }

        /// آیا نتیجه ناموفق است؟
        pub fn isErr(self: Self) bool {
            return self == .err;
        }

        // ─────────────────────────────────────────────────────────
        // Extract methods
        // ─────────────────────────────────────────────────────────

        /// دریافت مقدار موفق - panic اگر Err
        pub fn unwrap(self: Self) T {
            return switch (self) {
                .ok => |val| val,
                .err => |e| std.debug.panic("Called unwrap on Err: {}", .{e}),
            };
        }

        /// دریافت مقدار خطا - panic اگر Ok
        pub fn unwrapErr(self: Self) E {
            return switch (self) {
                .ok => |val| std.debug.panic("Called unwrapErr on Ok: {}", .{val}),
                .err => |e| e,
            };
        }

        /// دریافت مقدار موفق یا مقدار پیش‌فرض
        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .ok => |val| val,
                .err => default,
            };
        }

        /// دریافت مقدار موفق یا محاسبه از تابع
        pub fn unwrapOrElse(self: Self, f: fn (E) T) T {
            return switch (self) {
                .ok => |val| val,
                .err => |e| f(e),
            };
        }

        /// دریافت به صورت Option
        pub fn successOr(self: Self) ?T {
            return switch (self) {
                .ok => |val| val,
                .err => null,
            };
        }

        /// دریافت خطا به صورت Option
        pub fn failureOr(self: Self) ?E {
            return switch (self) {
                .ok => null,
                .err => |e| e,
            };
        }

        // ─────────────────────────────────────────────────────────
        // Combinators
        // ─────────────────────────────────────────────────────────

        /// تبدیل مقدار موفق با تابع
        pub fn map(self: Self, comptime U: type, f: fn (T) U) Result(U, E) {
            return switch (self) {
                .ok => |val| Result(U, E).success(f(val)),
                .err => |e| Result(U, E).failure(e),
            };
        }

        /// تبدیل خطا با تابع
        pub fn mapErr(self: Self, comptime F: type, f: fn (E) F) Result(T, F) {
            return switch (self) {
                .ok => |val| Result(T, F).success(val),
                .err => |e| Result(T, F).failure(f(e)),
            };
        }

        /// اعمال تابع اگر Ok
        pub fn andThen(self: Self, comptime U: type, f: fn (T) Result(U, E)) Result(U, E) {
            return switch (self) {
                .ok => |val| f(val),
                .err => |e| Result(U, E).failure(e),
            };
        }

        /// بازگشت self اگر Ok، وگرنه other
        pub fn orElse(self: Self, f: fn (E) Self) Self {
            return switch (self) {
                .ok => self,
                .err => |e| f(e),
            };
        }

        /// ترکیب دو Result - هر دو باید Ok باشند
        pub fn andResult(self: Self, other: Self) Self {
            return switch (self) {
                .ok => other,
                .err => self,
            };
        }

        /// ترکیب دو Result - حداقل یکی Ok باشد
        pub fn orResult(self: Self, other: Self) Self {
            return switch (self) {
                .ok => self,
                .err => other,
            };
        }

        // ─────────────────────────────────────────────────────────
        // Utility
        // ─────────────────────────────────────────────────────────

        /// Formatting support
        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            switch (self) {
                .ok => |val| try writer.print("Ok({any})", .{val}),
                .err => |e| try writer.print("Err({any})", .{e}),
            }
        }
    };
}

// ─────────────────────────────────────────────────────────
// Helper functions
// ─────────────────────────────────────────────────────────

/// تبدیل Zig error union به Result
pub fn wrapResult(comptime T: type, comptime E: type, result: E!T) Result(T, E) {
    if (result) |value| {
        return Result(T, E).success(value);
    } else |err| {
        return Result(T, E).failure(err);
    }
}

/// تبدیل Result به Zig error union
pub fn unwrapResult(comptime T: type, comptime E: type, result: Result(T, E)) E!T {
    return switch (result) {
        .ok => |val| val,
        .err => |e| e,
    };
}

// ─────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────

test "Result: basic usage" {
    const R = Result(i32, error{Failed});

    const ok_result = R.success(42);
    const err_result = R.failure(error.Failed);

    try std.testing.expect(ok_result.isOk());
    try std.testing.expect(err_result.isErr());
    try std.testing.expectEqual(@as(i32, 42), ok_result.unwrap());
    try std.testing.expectEqual(error.Failed, err_result.unwrapErr());
}

test "Result: unwrapOr" {
    const R = Result(i32, error{Failed});

    const ok_result = R.success(42);
    const err_result = R.failure(error.Failed);

    try std.testing.expectEqual(@as(i32, 42), ok_result.unwrapOr(0));
    try std.testing.expectEqual(@as(i32, 0), err_result.unwrapOr(0));
}

test "Result: map" {
    const R = Result(i32, error{Failed});

    const result = R.success(21);
    const doubled = result.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expectEqual(@as(i32, 42), doubled.unwrap());
}

test "Result: mapErr" {
    const R1 = Result(i32, error{Failed});
    _ = Result(i32, error{OtherError}); // ✅ استفاده می‌کنیم

    const result = R1.failure(error.Failed);
    const mapped = result.mapErr(error{OtherError}, struct {
        fn convert(_: error{Failed}) error{OtherError} {
            return error.OtherError;
        }
    }.convert);

    try std.testing.expectEqual(error.OtherError, mapped.unwrapErr());
}

test "Result: andThen" {
    const R = Result(i32, error{Failed});

    const result = R.success(21);
    const chained = result.andThen(i32, struct {
        fn double(x: i32) R {
            return R.success(x * 2);
        }
    }.double);

    try std.testing.expectEqual(@as(i32, 42), chained.unwrap());
}

test "Result: formatting" {
    const R = Result(i32, error{Failed});

    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(std.testing.allocator);

    const ok_result = R.success(42);
    try ok_result.format("", .{}, buffer.writer(std.testing.allocator));
    try std.testing.expect(buffer.items.len > 0);
}

test "Result: wrapResult" {
    const value: error{Failed}!i32 = 42;
    const result = wrapResult(i32, error{Failed}, value);

    try std.testing.expect(result.isOk());
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "Result: wrapResult with error" {
    const value: error{Failed}!i32 = error.Failed;
    const result = wrapResult(i32, error{Failed}, value);

    try std.testing.expect(result.isErr());
    try std.testing.expectEqual(error.Failed, result.unwrapErr());
}
