// ============================================================
// فایل: src/option.zig
// Option Type - Rust-style Option<T>
// ============================================================

const std = @import("std");

/// Option Type - مشابه Rust
///
/// نمایش یک مقدار که ممکن است وجود داشته باشد (Some) یا نداشته باشد (None)
///
/// # Example
/// ```zig
/// const O = Option(i32);
///
/// fn findValue(id: u32) O {
///     if (id == 0) return O.noneOption();
///     return O.someOption(@intCast(id * 10));
/// }
///
/// const result = findValue(5);
/// if (result.isSome()) {
///     std.debug.print("Found: {d}\n", .{result.unwrap()});
/// }
/// ```
pub fn Option(comptime T: type) type {
    return union(enum) {
        some: T,
        none,

        const Self = @This();

        // ─────────────────────────────────────────────────────────
        // Constructors
        // ─────────────────────────────────────────────────────────

        /// ایجاد Option با مقدار
        pub fn someOption(value: T) Self {
            return .{ .some = value };
        }

        /// ایجاد Option خالی
        pub fn noneOption() Self {
            return .{ .none = {} };
        }

        /// تبدیل از ?T به Option
        pub fn fromNullable(value: ?T) Self {
            if (value) |v| {
                return Self.someOption(v);
            } else {
                return Self.noneOption();
            }
        }

        // ─────────────────────────────────────────────────────────
        // Query methods
        // ─────────────────────────────────────────────────────────

        /// آیا مقدار دارد؟
        pub fn isSome(self: Self) bool {
            return self == .some;
        }

        /// آیا خالی است؟
        pub fn isNone(self: Self) bool {
            return self == .none;
        }

        // ─────────────────────────────────────────────────────────
        // Extract methods
        // ─────────────────────────────────────────────────────────

        /// دریافت مقدار - panic اگر None
        pub fn unwrap(self: Self) T {
            return switch (self) {
                .some => |val| val,
                .none => std.debug.panic("Called unwrap on None", .{}),
            };
        }

        /// دریافت مقدار یا پیش‌فرض
        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .some => |val| val,
                .none => default,
            };
        }

        /// دریافت مقدار یا محاسبه از تابع
        pub fn unwrapOrElse(self: Self, f: fn () T) T {
            return switch (self) {
                .some => |val| val,
                .none => f(),
            };
        }

        /// تبدیل به ?T
        pub fn toNullable(self: Self) ?T {
            return switch (self) {
                .some => |val| val,
                .none => null,
            };
        }

        // ─────────────────────────────────────────────────────────
        // Combinators
        // ─────────────────────────────────────────────────────────

        /// تبدیل مقدار با تابع
        pub fn map(self: Self, comptime U: type, f: fn (T) U) Option(U) {
            return switch (self) {
                .some => |val| Option(U).someOption(f(val)),
                .none => Option(U).noneOption(),
            };
        }

        /// تبدیل به Option دیگر با تابع
        pub fn andThen(self: Self, comptime U: type, f: fn (T) Option(U)) Option(U) {
            return switch (self) {
                .some => |val| f(val),
                .none => Option(U).noneOption(),
            };
        }

        /// فیلتر کردن مقدار
        pub fn filter(self: Self, predicate: fn (T) bool) Self {
            return switch (self) {
                .some => |val| if (predicate(val)) self else Self.noneOption(),
                .none => Self.noneOption(),
            };
        }

        /// ترکیب دو Option - هر دو باید Some باشند
        pub fn andOption(self: Self, other: Self) Self {
            return switch (self) {
                .some => other,
                .none => Self.noneOption(),
            };
        }

        /// ترکیب دو Option - حداقل یکی Some باشد
        pub fn orOption(self: Self, other: Self) Self {
            return switch (self) {
                .some => self,
                .none => other,
            };
        }

        /// اگر None است، دیگری را برگردان
        pub fn orElse(self: Self, f: fn () Self) Self {
            return switch (self) {
                .some => self,
                .none => f(),
            };
        }

        /// بررسی برابری با مقدار
        pub fn contains(self: Self, value: T) bool {
            return switch (self) {
                .some => |val| std.meta.eql(val, value),
                .none => false,
            };
        }

        // ─────────────────────────────────────────────────────────
        // Conversion to Result
        // ─────────────────────────────────────────────────────────

        /// تبدیل به Result
        pub fn okOr(self: Self, comptime E: type, err: E) @import("result.zig").Result(T, E) {
            const Result = @import("result.zig").Result(T, E);
            return switch (self) {
                .some => |val| Result.success(val),
                .none => Result.failure(err),
            };
        }

        /// تبدیل به Result با محاسبه خطا
        pub fn okOrElse(self: Self, comptime E: type, f: fn () E) @import("result.zig").Result(T, E) {
            const Result = @import("result.zig").Result(T, E);
            return switch (self) {
                .some => |val| Result.success(val),
                .none => Result.failure(f()),
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
                .some => |val| try writer.print("Some({any})", .{val}),
                .none => try writer.writeAll("None"),
            }
        }

        /// اعمال یک تابع اگر Some
        pub fn inspect(self: Self, f: fn (T) void) Self {
            if (self == .some) {
                f(self.some);
            }
            return self;
        }
    };
}

// ─────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────

test "Option: basic usage" {
    const O = Option(i32);

    const some_val = O.someOption(42);
    const none_val = O.noneOption();

    try std.testing.expect(some_val.isSome());
    try std.testing.expect(none_val.isNone());
    try std.testing.expectEqual(@as(i32, 42), some_val.unwrap());
}

test "Option: unwrapOr" {
    const O = Option(i32);

    const some_val = O.someOption(42);
    const none_val = O.noneOption();

    try std.testing.expectEqual(@as(i32, 42), some_val.unwrapOr(0));
    try std.testing.expectEqual(@as(i32, 0), none_val.unwrapOr(0));
}

test "Option: map" {
    const O = Option(i32);

    const value = O.someOption(21);
    const doubled = value.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expectEqual(@as(i32, 42), doubled.unwrap());

    const none_val = O.noneOption();
    const mapped_none = none_val.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);
    try std.testing.expect(mapped_none.isNone());
}

test "Option: andThen" {
    const O = Option(i32);

    const value = O.someOption(21);
    const result = value.andThen(i32, struct {
        fn double(x: i32) O {
            return O.someOption(x * 2);
        }
    }.double);

    try std.testing.expectEqual(@as(i32, 42), result.unwrap());
}

test "Option: filter" {
    const O = Option(i32);

    const value = O.someOption(42);
    const filtered = value.filter(struct {
        fn isEven(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.isEven);

    try std.testing.expect(filtered.isSome());

    const filtered_odd = value.filter(struct {
        fn isOdd(x: i32) bool {
            return @mod(x, 2) != 0;
        }
    }.isOdd);

    try std.testing.expect(filtered_odd.isNone());
}

test "Option: fromNullable" {
    const O = Option(i32);

    const value: ?i32 = 42;
    const opt = O.fromNullable(value);
    try std.testing.expect(opt.isSome());
    try std.testing.expectEqual(@as(i32, 42), opt.unwrap());

    const null_value: ?i32 = null;
    const opt_none = O.fromNullable(null_value);
    try std.testing.expect(opt_none.isNone());
}

test "Option: toNullable" {
    const O = Option(i32);

    const some_val = O.someOption(42);
    const nullable = some_val.toNullable();
    try std.testing.expectEqual(@as(?i32, 42), nullable);

    const none_val = O.noneOption();
    const null_nullable = none_val.toNullable();
    try std.testing.expectEqual(@as(?i32, null), null_nullable);
}

test "Option: formatting" {
    const O = Option(i32);

    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(std.testing.allocator);

    const some_val = O.someOption(42);
    try some_val.format("", .{}, buffer.writer(std.testing.allocator));
    try std.testing.expect(buffer.items.len > 0);

    buffer.clearRetainingCapacity();

    const none_val = O.noneOption();
    try none_val.format("", .{}, buffer.writer(std.testing.allocator));
    try std.testing.expect(buffer.items.len > 0);
}

test "Option: contains" {
    const O = Option(i32);

    const value = O.someOption(42);
    try std.testing.expect(value.contains(42));
    try std.testing.expect(!value.contains(0));

    const none_val = O.noneOption();
    try std.testing.expect(!none_val.contains(42));
}

test "Option: okOr" {
    const O = Option(i32);
    _ = @import("result.zig").Result(i32, error{Failed}); // ✅ استفاده

    const some_val = O.someOption(42);
    const result = some_val.okOr(error{Failed}, error.Failed);
    try std.testing.expect(result.isOk());
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());

    const none_val = O.noneOption();
    const err_result = none_val.okOr(error{Failed}, error.Failed);
    try std.testing.expect(err_result.isErr());
}
