// ============================================================
// فایل: modules/foundation/ziserv-core/src/result.zig
// Result Type - بهبود یافته برای error handling
// ============================================================

const std = @import("std");
const error_types = @import("error.zig");

/// Result Type - Rust-inspired
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,

        const Self = @This();

        /// ساخت Result موفق
        pub inline fn ok(value: T) Self {
            return .{ .ok = value };
        }

        /// ساخت Result خطا
        pub inline fn err(value: E) Self {
            return .{ .err = value };
        }

        /// آیا موفق است؟
        pub inline fn isOk(self: Self) bool {
            return self == .ok;
        }

        /// آیا خطا است؟
        pub inline fn isErr(self: Self) bool {
            return self == .err;
        }

        /// دریافت مقدار (panic اگر خطا باشد)
        pub fn unwrap(self: Self) T {
            return switch (self) {
                .ok => |val| val,
                .err => |e| std.debug.panic("called unwrap on error: {any}", .{e}),
            };
        }

        /// دریافت مقدار با پیام سفارشی
        pub fn expect(self: Self, msg: []const u8) T {
            return switch (self) {
                .ok => |val| val,
                .err => |e| std.debug.panic("{s}: {any}", .{ msg, e }),
            };
        }

        /// دریافت مقدار یا مقدار پیش‌فرض
        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .ok => |val| val,
                .err => default,
            };
        }

        /// دریافت مقدار یا محاسبه مقدار پیش‌فرض
        pub fn unwrapOrElse(self: Self, comptime f: fn (E) T) T {
            return switch (self) {
                .ok => |val| val,
                .err => |e| f(e),
            };
        }

        /// تبدیل Result<T,E> به Result<U,E>
        pub fn map(self: Self, comptime f: fn (T) anytype) Result(@TypeOf(f(@as(T, undefined))), E) {
            return switch (self) {
                .ok => |val| .{ .ok = f(val) },
                .err => |e| .{ .err = e },
            };
        }

        /// تبدیل خطا
        pub fn mapErr(self: Self, comptime f: fn (E) anytype) Result(T, @TypeOf(f(@as(E, undefined)))) {
            return switch (self) {
                .ok => |val| .{ .ok = val },
                .err => |e| .{ .err = f(e) },
            };
        }

        /// Chain operations
        pub fn andThen(self: Self, comptime f: fn (T) anytype) @TypeOf(f(@as(T, undefined))) {
            return switch (self) {
                .ok => |val| f(val),
                .err => |e| .{ .err = e },
            };
        }

        /// دریافت مقدار یا خطا (Zig-style error union)
        pub fn toErrorUnion(self: Self) E!T {
            return switch (self) {
                .ok => |val| val,
                .err => |e| e,
            };
        }

        /// ساخت از error union
        pub fn fromErrorUnion(result: E!T) Self {
            if (result) |val| {
                return .{ .ok = val };
            } else |e| {
                return .{ .err = e };
            }
        }
    };
}

/// Option Type (Result without error)
pub fn Option(comptime T: type) type {
    return union(enum) {
        some: T,
        none,

        const Self = @This();

        pub inline fn some(value: T) Self {
            return .{ .some = value };
        }

        pub inline fn none() Self {
            return .none;
        }

        pub inline fn isSome(self: Self) bool {
            return self == .some;
        }

        pub inline fn isNone(self: Self) bool {
            return self == .none;
        }

        pub fn unwrap(self: Self) T {
            return switch (self) {
                .some => |val| val,
                .none => std.debug.panic("called unwrap on None", .{}),
            };
        }

        pub fn expect(self: Self, msg: []const u8) T {
            return switch (self) {
                .some => |val| val,
                .none => std.debug.panic("{s}", .{msg}),
            };
        }

        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .some => |val| val,
                .none => default,
            };
        }

        pub fn map(self: Self, comptime f: fn (T) anytype) Option(@TypeOf(f(@as(T, undefined)))) {
            return switch (self) {
                .some => |val| .{ .some = f(val) },
                .none => .none,
            };
        }

        pub fn andThen(self: Self, comptime f: fn (T) anytype) @TypeOf(f(@as(T, undefined))) {
            return switch (self) {
                .some => |val| f(val),
                .none => .none,
            };
        }

        pub fn toResult(self: Self, err: anytype) Result(T, @TypeOf(err)) {
            return switch (self) {
                .some => |val| .{ .ok = val },
                .none => .{ .err = err },
            };
        }
    };
}

/// Try macro simulation (compile-time)
pub inline fn try_(result: anytype) @TypeOf(result.unwrap()) {
    return result.unwrap();
}

/// Context-aware Result
pub fn ResultWithContext(comptime T: type, comptime E: type) type {
    return struct {
        result: Result(T, E),
        context: ?error_types.ErrorContext,

        const Self = @This();

        pub fn ok(value: T) Self {
            return .{
                .result = .{ .ok = value },
                .context = null,
            };
        }

        pub fn err(value: E, ctx: error_types.ErrorContext) Self {
            return .{
                .result = .{ .err = value },
                .context = ctx,
            };
        }

        pub fn errSimple(value: E) Self {
            return .{
                .result = .{ .err = value },
                .context = null,
            };
        }

        pub fn isOk(self: Self) bool {
            return self.result.isOk();
        }

        pub fn isErr(self: Self) bool {
            return self.result.isErr();
        }

        pub fn unwrap(self: Self) T {
            if (self.result.isErr() and self.context != null) {
                std.debug.panic("Error with context: {}", .{self.context.?});
            }
            return self.result.unwrap();
        }

        pub fn getContext(self: Self) ?error_types.ErrorContext {
            return self.context;
        }
    };
}

/// Helper: wrap zig error union to Result
pub inline fn wrapResult(result: anytype) Result(@typeInfo(@TypeOf(result)).error_union.payload, @typeInfo(@TypeOf(result)).error_union.error_set) {
    if (result) |val| {
        return .{ .ok = val };
    } else |e| {
        return .{ .err = e };
    }
}

/// Helper: chain multiple Results
pub fn chain(comptime results: anytype) !void {
    inline for (results) |r| {
        if (r.isErr()) return r.err;
    }
}

test "result basic" {
    const R = Result(i32, error{Failed});

    const success = R.ok(42);
    try std.testing.expect(success.isOk());
    try std.testing.expectEqual(@as(i32, 42), success.unwrap());

    const failure = R.err(error.Failed);
    try std.testing.expect(failure.isErr());
}

test "result map" {
    const R = Result(i32, error{Failed});

    const success = R.ok(10);
    const mapped = success.map(struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expectEqual(@as(i32, 20), mapped.unwrap());
}

test "option basic" {
    const O = Option(i32);

    const some = O.some(42);
    try std.testing.expect(some.isSome());
    try std.testing.expectEqual(@as(i32, 42), some.unwrap());

    const none = O.none();
    try std.testing.expect(none.isNone());
    try std.testing.expectEqual(@as(i32, 0), none.unwrapOr(0));
}

test "option map" {
    const O = Option(i32);

    const some = O.some(5);
    const mapped = some.map(struct {
        fn square(x: i32) i32 {
            return x * x;
        }
    }.square);

    try std.testing.expectEqual(@as(i32, 25), mapped.unwrap());
}

test "result with context" {
    const R = ResultWithContext(i32, error{Failed});

    const ctx = error_types.ErrorContext.init("Test error", @src());
    const failure = R.err(error.Failed, ctx);

    try std.testing.expect(failure.isErr());
    try std.testing.expect(failure.getContext() != null);
}

test "wrap result" {
    const zigResult: error{Failed}!i32 = 42;
    const wrapped = wrapResult(zigResult);

    try std.testing.expect(wrapped.isOk());
    try std.testing.expectEqual(@as(i32, 42), wrapped.unwrap());
}