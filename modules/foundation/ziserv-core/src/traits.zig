// ============================================================
// فایل: modules/foundation/ziserv-core/src/traits.zig
// Traits و Interfaces مشترک
// ============================================================

const std = @import("std");

/// Interface برای Disposable resources
pub fn Disposable(comptime T: type) type {
    return struct {
        pub fn dispose(self: *T) void {
            if (@hasDecl(T, "deinit")) {
                self.deinit();
            }
        }
    };
}

/// Interface برای Cloneable types
pub fn Cloneable(comptime T: type) type {
    return struct {
        pub fn clone(self: *const T, allocator: std.mem.Allocator) !T {
            _ = allocator;
            if (@hasDecl(T, "clone")) {
                return self.clone();
            }
            @compileError("Type must implement 'clone' method");
        }
    };
}

/// Interface برای Serializable types
pub fn Serializable(comptime T: type) type {
    return struct {
        pub fn serialize(self: *const T, writer: anytype) !void {
            if (@hasDecl(T, "serialize")) {
                return self.serialize(writer);
            }
            @compileError("Type must implement 'serialize' method");
        }

        pub fn deserialize(reader: anytype, allocator: std.mem.Allocator) !T {
            if (@hasDecl(T, "deserialize")) {
                return T.deserialize(reader, allocator);
            }
            @compileError("Type must implement 'deserialize' method");
        }
    };
}

/// Trait برای Display
pub fn Display(comptime T: type) type {
    return struct {
        pub fn format(
            self: *const T,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            if (@hasDecl(T, "format")) {
                return self.format(fmt, options, writer);
            }
            try writer.print("{any}", .{self});
        }
    };
}

/// بررسی اینکه آیا type یک trait را پیاده کرده
pub fn implements(comptime T: type, comptime method: []const u8) bool {
    return @hasDecl(T, method);
}

test "traits" {
    const TestType = struct {
        value: i32,

        pub fn deinit(self: *@This()) void {
            self.value = 0;
        }
    };

    try std.testing.expect(implements(TestType, "deinit"));
    try std.testing.expect(!implements(TestType, "clone"));
}
