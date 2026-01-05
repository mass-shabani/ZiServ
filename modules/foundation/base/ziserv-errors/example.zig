// ============================================================
// فایل: example.zig
// Examples for ziserv-errors
// ============================================================

const std = @import("std");
const errors = @import("ziserv-errors");

// ─────────────────────────────────────────────────────────
// Example 1: Basic Result Usage
// ─────────────────────────────────────────────────────────

fn exampleBasicResult() !void {
    const stdout = std.fs.File.stdout();
    const writer = stdout.deprecatedWriter();

    try writer.writeAll("\n");
    try writer.writeAll("╔════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║         Example 1: Basic Result Usage                      ║\n");
    try writer.writeAll("╚════════════════════════════════════════════════════════════╝\n");
    try writer.writeAll("\n");

    const R = errors.Result(i32, error{DivisionByZero});

    // تابع تقسیم که Result برمی‌گرداند
    const divide = struct {
        fn call(a: i32, b: i32) R {
            if (b == 0) return R.failure(error.DivisionByZero);
            return R.success(@divTrunc(a, b));
        }
    }.call;

    // استفاده
    const result1 = divide(10, 2);
    if (result1.isOk()) {
        try writer.print("10 / 2 = {d}\n", .{result1.unwrap()});
    }

    const result2 = divide(10, 0);
    if (result2.isErr()) {
        try writer.print("10 / 0 = Error: {}\n", .{result2.unwrapErr()});
    }

    // استفاده از unwrapOr
    const result3 = divide(10, 0);
    const value = result3.unwrapOr(-1);
    try writer.print("10 / 0 with default = {d}\n", .{value});

    try writer.writeAll("\n");
}

// ─────────────────────────────────────────────────────────
// Example 2: Result Chaining
// ─────────────────────────────────────────────────────────

fn exampleResultChaining() !void {
    const stdout = std.fs.File.stdout();
    const writer = stdout.deprecatedWriter();

    try writer.writeAll("╔════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║         Example 2: Result Chaining                         ║\n");
    try writer.writeAll("╚════════════════════════════════════════════════════════════╝\n");
    try writer.writeAll("\n");

    const R = errors.Result(i32, error{Failed});

    const result = R.success(10);

    // map: تبدیل مقدار
    const doubled = result.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);
    try writer.print("Doubled: {d}\n", .{doubled.unwrap()});

    // andThen: زنجیره‌سازی عملیات
    const squared = doubled.andThen(i32, struct {
        fn square(x: i32) R {
            return R.success(x * x);
        }
    }.square);
    try writer.print("Squared: {d}\n", .{squared.unwrap()});

    try writer.writeAll("\n");
}

// ─────────────────────────────────────────────────────────
// Example 3: Basic Option Usage
// ─────────────────────────────────────────────────────────

fn exampleBasicOption() !void {
    const stdout = std.fs.File.stdout();
    const writer = stdout.deprecatedWriter();

    try writer.writeAll("╔════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║         Example 3: Basic Option Usage                      ║\n");
    try writer.writeAll("╚════════════════════════════════════════════════════════════╝\n");
    try writer.writeAll("\n");

    const O = errors.Option([]const u8);

    // تابع جستجو
    const findUser = struct {
        fn call(id: u32) O {
            if (id == 0) return O.noneOption();
            if (id == 1) return O.someOption("Alice");
            if (id == 2) return O.someOption("Bob");
            return O.noneOption();
        }
    }.call;

    // استفاده
    const user1 = findUser(1);
    if (user1.isSome()) {
        try writer.print("User 1: {s}\n", .{user1.unwrap()});
    }

    const user3 = findUser(3);
    if (user3.isNone()) {
        try writer.writeAll("User 3: Not found\n");
    }

    // استفاده از unwrapOr
    const user0 = findUser(0);
    const name = user0.unwrapOr("Guest");
    try writer.print("User 0: {s}\n", .{name});

    try writer.writeAll("\n");
}

// ─────────────────────────────────────────────────────────
// Example 4: Option Chaining
// ─────────────────────────────────────────────────────────

fn exampleOptionChaining() !void {
    const stdout = std.fs.File.stdout();
    const writer = stdout.deprecatedWriter();

    try writer.writeAll("╔════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║         Example 4: Option Chaining                         ║\n");
    try writer.writeAll("╚════════════════════════════════════════════════════════════╝\n");
    try writer.writeAll("\n");

    const O = errors.Option(i32);

    const value = O.someOption(5);

    // map
    const doubled = value.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);
    try writer.print("Doubled: {d}\n", .{doubled.unwrap()});

    // filter
    const filtered = doubled.filter(struct {
        fn isEven(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.isEven);
    try writer.print("Filtered (even): {d}\n", .{filtered.unwrap()});

    // andThen
    const result = filtered.andThen(i32, struct {
        fn half(x: i32) O {
            return O.someOption(@divTrunc(x, 2));
        }
    }.half);
    try writer.print("Half: {d}\n", .{result.unwrap()});

    try writer.writeAll("\n");
}

// ─────────────────────────────────────────────────────────
// Example 5: Error Context
// ─────────────────────────────────────────────────────────

fn exampleErrorContext() !void {
    const stdout = std.fs.File.stdout();
    const writer = stdout.deprecatedWriter();

    try writer.writeAll("╔════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║         Example 5: Error Context                           ║\n");
    try writer.writeAll("╚════════════════════════════════════════════════════════════╝\n");
    try writer.writeAll("\n");

    const EWC = errors.ErrorWithContext(errors.Error);

    // ایجاد خطا با context
    const ctx = errors.Context.init("File not found: config.json", @src());
    const err = EWC.withContext(error.NotFound, ctx);

    // try writer.print("Error: {any}\n", .{err});
    try writer.print("Category: {s}\n", .{err.category().toString()});
    try writer.print("Severity: {s}\n", .{err.severity().toString()});

    try writer.writeAll("\n");
}

// ─────────────────────────────────────────────────────────
// Example 6: Combinators
// ─────────────────────────────────────────────────────────

fn exampleCombinators(allocator: std.mem.Allocator) !void {
    const stdout = std.fs.File.stdout();
    const writer = stdout.deprecatedWriter();

    try writer.writeAll("╔════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║         Example 6: Combinators                             ║\n");
    try writer.writeAll("╚════════════════════════════════════════════════════════════╝\n");
    try writer.writeAll("\n");

    const R = errors.Result(i32, error{Failed});

    // لیست از Result‌ها
    const results = [_]R{
        R.success(1),
        R.success(2),
        R.failure(error.Failed),
        R.success(3),
        R.success(4),
    };

    // فیلتر کردن موفق‌ها
    const ok_values = try errors.combinators.filterOk(i32, error{Failed}, allocator, &results);
    defer allocator.free(ok_values);

    try writer.writeAll("Ok values: [");
    for (ok_values, 0..) |val, i| {
        if (i > 0) try writer.writeAll(", ");
        try writer.print("{d}", .{val});
    }
    try writer.writeAll("]\n");

    // Partition
    const partition = try errors.combinators.partitionResults(i32, error{Failed}, allocator, &results);
    defer allocator.free(partition.ok);
    defer allocator.free(partition.err);

    try writer.print("Ok count: {d}\n", .{partition.ok.len});
    try writer.print("Err count: {d}\n", .{partition.err.len});

    try writer.writeAll("\n");
}

// ─────────────────────────────────────────────────────────
// Example 7: Real-world Usage
// ─────────────────────────────────────────────────────────

const User = struct {
    id: u32,
    name: []const u8,
    email: []const u8,
};

fn exampleRealWorld(allocator: std.mem.Allocator) !void {
    const stdout = std.fs.File.stdout();
    const writer = stdout.deprecatedWriter();

    try writer.writeAll("╔════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║         Example 7: Real-world Usage                        ║\n");
    try writer.writeAll("╚════════════════════════════════════════════════════════════╝\n");
    try writer.writeAll("\n");

    const R = errors.Result(User, errors.Error);
    _ = errors.Option(User);

    // تابع دریافت کاربر
    const getUser = struct {
        fn call(id: u32) R {
            if (id == 0) return R.failure(error.InvalidArgument);
            if (id > 1000) return R.failure(error.NotFound);

            return R.success(.{
                .id = id,
                .name = "Alice",
                .email = "alice@example.com",
            });
        }
    }.call;

    // استفاده با map
    const result = getUser(42);
    const name_result = result.map([]const u8, struct {
        fn getName(user: User) []const u8 {
            return user.name;
        }
    }.getName);

    if (name_result.isOk()) {
        try writer.print("User name: {s}\n", .{name_result.unwrap()});
    }

    // تبدیل به Option
    const option = errors.combinators.resultToOption(User, errors.Error, result);
    if (option.isSome()) {
        const user = option.unwrap();
        try writer.print("User email: {s}\n", .{user.email});
    }

    _ = allocator; // استفاده نشده اما برای consistency
    try writer.writeAll("\n");
}

// ─────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){
        .backing_allocator = std.heap.page_allocator,
    };
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout();
    const writer = stdout.deprecatedWriter();

    try writer.writeAll("\n");
    try writer.writeAll("╔════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║              ziserv-errors Examples                        ║\n");
    try writer.writeAll("╚════════════════════════════════════════════════════════════╝\n");

    try exampleBasicResult();
    try exampleResultChaining();
    try exampleBasicOption();
    try exampleOptionChaining();
    try exampleErrorContext();
    try exampleCombinators(allocator);
    try exampleRealWorld(allocator);

    try writer.writeAll("╔════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║         All Examples Completed Successfully!               ║\n");
    try writer.writeAll("╚════════════════════════════════════════════════════════════╝\n");
    try writer.writeAll("\n");
}
