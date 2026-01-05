// ============================================================
// فایل: src/combinators.zig
// Combinator functions - Helper utilities
// ============================================================

const std = @import("std");
const Result = @import("result.zig").Result;
const Option = @import("option.zig").Option;

// ─────────────────────────────────────────────────────────
// Result Combinators
// ─────────────────────────────────────────────────────────

/// اعمال تابع به همه موارد موفق در یک slice
pub fn mapResults(
    comptime T: type,
    comptime U: type,
    comptime E: type,
    allocator: std.mem.Allocator,
    results: []const Result(T, E),
    f: fn (T) U,
) ![]U {
    var output = std.ArrayList(U){};
    errdefer output.deinit(allocator);

    for (results) |result| {
        if (result == .ok) {
            try output.append(allocator, f(result.ok));
        }
    }

    return output.toOwnedSlice(allocator);
}

/// فیلتر کردن Result‌های موفق
pub fn filterOk(
    comptime T: type,
    comptime E: type,
    allocator: std.mem.Allocator,
    results: []const Result(T, E),
) ![]T {
    var output = std.ArrayList(T){};
    errdefer output.deinit(allocator);

    for (results) |result| {
        if (result == .ok) {
            try output.append(allocator, result.ok);
        }
    }

    return output.toOwnedSlice(allocator);
}

/// فیلتر کردن Result‌های ناموفق
pub fn filterErr(
    comptime T: type,
    comptime E: type,
    allocator: std.mem.Allocator,
    results: []const Result(T, E),
) ![]E {
    var output = std.ArrayList(E){};
    errdefer output.deinit(allocator);

    for (results) |result| {
        if (result == .err) {
            try output.append(allocator, result.err);
        }
    }

    return output.toOwnedSlice(allocator);
}

/// تبدیل slice از Result به Result از slice
/// اگر همه Ok باشند، Ok(slice) برمی‌گرداند
/// اگر یکی Err باشد، اولین Err را برمی‌گرداند
pub fn collectResults(
    comptime T: type,
    comptime E: type,
    allocator: std.mem.Allocator,
    results: []const Result(T, E),
) Result([]T, E) {
    var output = std.ArrayList(T){};

    for (results) |result| {
        switch (result) {
            .ok => |val| {
                output.append(allocator, val) catch {
                    output.deinit(allocator);
                    // ✅ فقط error.OutOfMemory را return کنیم اگر E شامل آن است
                    // یا یک خطای generic از E استفاده کنیم
                    // برای سادگی، فرض می‌کنیم E حتماً یک خطای مناسب دارد
                    // در غیر این صورت باید compile error بدهد
                    return Result([]T, E).failure(@field(E, "OutOfMemory"));
                };
            },
            .err => |e| {
                output.deinit(allocator);
                return Result([]T, E).failure(e);
            },
        }
    }

    const slice = output.toOwnedSlice(allocator) catch {
        output.deinit(allocator);
        return Result([]T, E).failure(@field(E, "OutOfMemory"));
    };

    return Result([]T, E).success(slice);
}

/// Partition: جدا کردن Ok و Err به دو slice
pub fn partitionResults(
    comptime T: type,
    comptime E: type,
    allocator: std.mem.Allocator,
    results: []const Result(T, E),
) !struct { ok: []T, err: []E } {
    var ok_list = std.ArrayList(T){};
    var err_list = std.ArrayList(E){};
    errdefer {
        ok_list.deinit(allocator);
        err_list.deinit(allocator);
    }

    for (results) |result| {
        switch (result) {
            .ok => |val| try ok_list.append(allocator, val),
            .err => |e| try err_list.append(allocator, e),
        }
    }

    return .{
        .ok = try ok_list.toOwnedSlice(allocator),
        .err = try err_list.toOwnedSlice(allocator),
    };
}

// ─────────────────────────────────────────────────────────
// Option Combinators
// ─────────────────────────────────────────────────────────

/// اعمال تابع به همه موارد Some در یک slice
pub fn mapOptions(
    comptime T: type,
    comptime U: type,
    allocator: std.mem.Allocator,
    options: []const Option(T),
    f: fn (T) U,
) ![]U {
    var output = std.ArrayList(U){};
    errdefer output.deinit(allocator);

    for (options) |opt| {
        if (opt == .some) {
            try output.append(allocator, f(opt.some));
        }
    }

    return output.toOwnedSlice(allocator);
}

/// فیلتر کردن Option‌های Some
pub fn filterSome(
    comptime T: type,
    allocator: std.mem.Allocator,
    options: []const Option(T),
) ![]T {
    var output = std.ArrayList(T){};
    errdefer output.deinit(allocator);

    for (options) |opt| {
        if (opt == .some) {
            try output.append(allocator, opt.some);
        }
    }

    return output.toOwnedSlice(allocator);
}

/// تبدیل slice از Option به Option از slice
/// اگر همه Some باشند، Some(slice) برمی‌گرداند
/// اگر یکی None باشد، None برمی‌گرداند
pub fn collectOptions(
    comptime T: type,
    allocator: std.mem.Allocator,
    options: []const Option(T),
) Option([]T) {
    var output = std.ArrayList(T){};
    errdefer output.deinit(allocator);

    for (options) |opt| {
        switch (opt) {
            .some => |val| output.append(allocator, val) catch {
                output.deinit(allocator);
                return Option([]T).none();
            },
            .none => {
                output.deinit(allocator);
                return Option([]T).none();
            },
        }
    }

    return Option([]T).some(output.toOwnedSlice(allocator) catch {
        output.deinit(allocator);
        return Option([]T).none();
    });
}

/// پیدا کردن اولین Some
pub fn findSome(comptime T: type, options: []const Option(T)) Option(T) {
    for (options) |opt| {
        if (opt == .some) {
            return opt;
        }
    }
    return Option(T).noneOption();
}

// ─────────────────────────────────────────────────────────
// Mixed Combinators (Result + Option)
// ─────────────────────────────────────────────────────────

/// تبدیل Option به Result
pub fn optionToResult(
    comptime T: type,
    comptime E: type,
    option: Option(T),
    err: E,
) Result(T, E) {
    return switch (option) {
        .some => |val| Result(T, E).success(val),
        .none => Result(T, E).failure(err),
    };
}

/// تبدیل Result به Option (Err را نادیده می‌گیرد)
pub fn resultToOption(
    comptime T: type,
    comptime E: type,
    result: Result(T, E),
) Option(T) {
    return switch (result) {
        .ok => |val| Option(T).someOption(val),
        .err => Option(T).noneOption(),
    };
}

// ─────────────────────────────────────────────────────────
// Utility Functions
// ─────────────────────────────────────────────────────────

/// اگر predicate true بود، Some(value) وگرنه None
pub fn filter(comptime T: type, value: T, predicate: fn (T) bool) Option(T) {
    if (predicate(value)) {
        return Option(T).someOption(value);
    } else {
        return Option(T).noneOption();
    }
}

/// تلاش برای اجرای تابع و wrap کردن نتیجه در Result
pub fn tryCatch(
    comptime T: type,
    comptime E: type,
    f: fn () E!T,
) Result(T, E) {
    if (f()) |value| {
        return Result(T, E).success(value);
    } else |err| {
        return Result(T, E).failure(err);
    }
}

// ─────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────

test "combinators: mapResults" {
    const R = Result(i32, error{Failed});
    const results = [_]R{
        R.success(1),
        R.success(2),
        R.failure(error.Failed),
        R.success(3),
    };

    const mapped = try mapResults(i32, i32, error{Failed}, std.testing.allocator, &results, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);
    defer std.testing.allocator.free(mapped);

    try std.testing.expectEqual(@as(usize, 3), mapped.len);
    try std.testing.expectEqual(@as(i32, 2), mapped[0]);
    try std.testing.expectEqual(@as(i32, 4), mapped[1]);
    try std.testing.expectEqual(@as(i32, 6), mapped[2]);
}

test "combinators: filterOk" {
    const R = Result(i32, error{Failed});
    const results = [_]R{
        R.success(1),
        R.failure(error.Failed),
        R.success(2),
    };

    const filtered = try filterOk(i32, error{Failed}, std.testing.allocator, &results);
    defer std.testing.allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 2), filtered.len);
    try std.testing.expectEqual(@as(i32, 1), filtered[0]);
    try std.testing.expectEqual(@as(i32, 2), filtered[1]);
}

test "combinators: filterErr" {
    const R = Result(i32, error{Failed});
    const results = [_]R{
        R.success(1),
        R.failure(error.Failed),
        R.success(2),
        R.failure(error.Failed),
    };

    const filtered = try filterErr(i32, error{Failed}, std.testing.allocator, &results);
    defer std.testing.allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 2), filtered.len);
}

test "combinators: partitionResults" {
    const R = Result(i32, error{Failed});
    const results = [_]R{
        R.success(1),
        R.failure(error.Failed),
        R.success(2),
        R.failure(error.Failed),
    };

    const partition = try partitionResults(i32, error{Failed}, std.testing.allocator, &results);
    defer std.testing.allocator.free(partition.ok);
    defer std.testing.allocator.free(partition.err);

    try std.testing.expectEqual(@as(usize, 2), partition.ok.len);
    try std.testing.expectEqual(@as(usize, 2), partition.err.len);
}

test "combinators: mapOptions" {
    const O = Option(i32);
    const options = [_]O{
        O.someOption(1),
        O.noneOption(),
        O.someOption(2),
    };

    const mapped = try mapOptions(i32, i32, std.testing.allocator, &options, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);
    defer std.testing.allocator.free(mapped);

    try std.testing.expectEqual(@as(usize, 2), mapped.len);
    try std.testing.expectEqual(@as(i32, 2), mapped[0]);
    try std.testing.expectEqual(@as(i32, 4), mapped[1]);
}

test "combinators: filterSome" {
    const O = Option(i32);
    const options = [_]O{
        O.someOption(1),
        O.noneOption(),
        O.someOption(2),
    };

    const filtered = try filterSome(i32, std.testing.allocator, &options);
    defer std.testing.allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 2), filtered.len);
}

test "combinators: findSome" {
    const O = Option(i32);
    const options = [_]O{
        O.noneOption(),
        O.noneOption(),
        O.someOption(42),
        O.someOption(100),
    };

    const found = findSome(i32, &options);
    try std.testing.expect(found.isSome());
    try std.testing.expectEqual(@as(i32, 42), found.unwrap());
}

test "combinators: optionToResult" {
    const O = Option(i32);
    _ = Result(i32, error{Failed});

    const some_val = O.someOption(42);
    const result = optionToResult(i32, error{Failed}, some_val, error.Failed);
    try std.testing.expect(result.isOk());
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());

    const none_val = O.noneOption();
    const err_result = optionToResult(i32, error{Failed}, none_val, error.Failed);
    try std.testing.expect(err_result.isErr());
}

test "combinators: resultToOption" {
    const R = Result(i32, error{Failed});
    _ = Option(i32);

    const ok_result = R.success(42);
    const option = resultToOption(i32, error{Failed}, ok_result);
    try std.testing.expect(option.isSome());
    try std.testing.expectEqual(@as(i32, 42), option.unwrap());

    const err_result = R.failure(error.Failed);
    const none_option = resultToOption(i32, error{Failed}, err_result);
    try std.testing.expect(none_option.isNone());
}

test "combinators: filter" {
    const result = filter(i32, 42, struct {
        fn isEven(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.isEven);

    try std.testing.expect(result.isSome());
    try std.testing.expectEqual(@as(i32, 42), result.unwrap());

    const filtered = filter(i32, 43, struct {
        fn isEven(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.isEven);

    try std.testing.expect(filtered.isNone());
}
