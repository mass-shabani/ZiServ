// ============================================================
// فایل: modules/foundation/ziserv-core/src/result.zig
// Result & Option Type - نسخه اصلاح شده (رفع تداخل نام‌ها)
// ============================================================

const std = @import("std");
const error_types = @import("error.zig");

/// Result Type - Rust-inspired
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,

        const Self = @This();

        /// ساخت Result موفق (success به جای ok برای جلوگیری از تداخل با فیلد ok)
        pub inline fn success(value: T) Self {
            return .{ .ok = value };
        }

        /// ساخت Result خطا (failure به جای err برای جلوگیری از تداخل با فیلد err)
        pub inline fn failure(value: E) Self {
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

        // --- Diagnostics (دیباگینگ) ---

        /// اجرای تابع f روی مقدار در صورت موفقیت (برای لاگ یا بررسی)
        pub fn inspect(self: Self, f: fn (T) void) Self {
            if (self == .ok) f(self.ok);
            return self;
        }

        /// اجرای تابع f روی خطا در صورت وجود (برای لاگ خطا)
        pub fn inspectErr(self: Self, f: fn (E) void) Self {
            if (self == .err) f(self.err);
            return self;
        }

        // --- Transformers (تبدیل‌گرها) ---

        /// تبدیل Result<T,E> به Result<U,E>
        /// نوع جدید U باید اول مشخص شود، سپس تابع تبدیل
        pub fn map(self: Self, comptime U: type, f: fn (T) U) Result(U, E) {
            return switch (self) {
                .ok => |val| .{ .ok = f(val) },
                .err => |e| .{ .err = e },
            };
        }

        /// تبدیل خطا از نوع E به نوع F
        /// نوع جدید F باید اول مشخص شود
        pub fn mapErr(self: Self, comptime F: type, f: fn (E) F) Result(T, F) {
            return switch (self) {
                .ok => |val| .{ .ok = val },
                .err => |e| .{ .err = f(e) },
            };
        }

        /// Chain operations (Flattening)
        /// تابع f خروجی نهایی را برمی‌گرداند
        pub fn andThen(self: Self, comptime U: type, f: fn (T) Result(U, E)) Result(U, E) {
            return switch (self) {
                .ok => |val| f(val),
                .err => |e| .{ .err = e },
            };
        }

        /// مدیریت خطا و تلاش برای رفع آن (Chain روی خطا)
        /// اگر خطا باشد، تابع f اجرا می‌شود
        pub fn orElse(self: Self, comptime U: type, f: fn (E) Result(U, E)) Result(U, E) {
            return switch (self) {
                .ok => |val| Result(U, E).success(val),
                .err => |e| f(e),
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

        /// ساخت Option با مقدار (init به جای some برای جلوگیری از تداخل با فیلد some)
        pub inline fn init(value: T) Self {
            return .{ .some = value };
        }

        /// ساخت Option خالی (empty به جای none برای جلوگیری از تداخل با فیلد none)
        pub inline fn empty() Self {
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

        // --- Diagnostics (دیباگینگ) ---

        /// اجرای تابع f روی مقدار در صورت وجود (برای لاگ)
        pub fn inspect(self: Self, f: fn (T) void) Self {
            if (self == .some) f(self.some);
            return self;
        }

        // --- Transformers (تبدیل‌گرها) ---

        /// تبدیل Option<T> به Option<U>
        /// نوع جدید U باید اول مشخص شود (سازگار با Result)
        pub fn map(self: Self, comptime U: type, f: fn (T) U) Option(U) {
            return switch (self) {
                .some => |val| .{ .some = f(val) },
                .none => .none,
            };
        }

        /// Chain operations (Flattening)
        /// تابع f خروجی نهایی را برمی‌گرداند
        pub fn andThen(self: Self, comptime U: type, f: fn (T) Option(U)) Option(U) {
            return switch (self) {
                .some => |val| f(val),
                .none => .none,
            };
        }

        /// مدیریت وضعیت None (Chain روی None)
        /// اگر مقدار None باشد، تابع f اجرا می‌شود
        pub fn orElse(self: Self, comptime U: type, f: fn () Option(U)) Option(U) {
            return switch (self) {
                .some => |val| Option(U).init(val),
                .none => f(),
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

        pub fn success(value: T) Self { // تغییر نام از ok به success
            return .{
                .result = .{ .ok = value },
                .context = null,
            };
        }

        pub fn failure(value: E, ctx: error_types.ErrorContext) Self { // تغییر نام از err به failure
            return .{
                .result = .{ .err = value },
                .context = ctx,
            };
        }

        pub fn failureSimple(value: E) Self {
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

// --- Tests (Updated) ---

test "result basic" {
    const R = Result(i32, error{Failed});

    const success = R.success(42); // تغییر ok به success
    try std.testing.expect(success.isOk());
    try std.testing.expectEqual(@as(i32, 42), success.unwrap());

    const failure = R.failure(error.Failed); // تغییر err به failure
    try std.testing.expect(failure.isErr());
}

test "result map" {
    const R = Result(i32, error{Failed});

    const success = R.success(10); // تغییر ok به success
    const mapped = success.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expectEqual(@as(i32, 20), mapped.unwrap());
}

test "option basic" {
    const O = Option(i32);

    const some = O.init(42); // تغییر some به init
    try std.testing.expect(some.isSome());
    try std.testing.expectEqual(@as(i32, 42), some.unwrap());

    const none = O.empty(); // تغییر none به empty
    try std.testing.expect(none.isNone());
    try std.testing.expectEqual(@as(i32, 0), none.unwrapOr(0));
}

test "option map" {
    const O = Option(i32);

    const some = O.init(5); // تغییر some به init
    const mapped = some.map(i32, struct {
        fn square(x: i32) i32 {
            return x * x;
        }
    }.square);

    try std.testing.expectEqual(@as(i32, 25), mapped.unwrap());
}

test "result with context" {
    const R = ResultWithContext(i32, error{Failed});

    const ctx = error_types.ErrorContext.init("Test error", @src());
    const failure = R.failure(error.Failed, ctx); // تغییر err به failure

    try std.testing.expect(failure.isErr());
    try std.testing.expect(failure.getContext() != null);
}

test "wrap result" {
    const zigResult: error{Failed}!i32 = 42;
    const wrapped = wrapResult(zigResult);

    try std.testing.expect(wrapped.isOk());
    try std.testing.expectEqual(@as(i32, 42), wrapped.unwrap());
}
