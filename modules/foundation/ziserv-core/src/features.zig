// ============================================================
// فایل: modules/foundation/ziserv-core/src/features.zig
// Feature Flags System - Runtime + Compile-time
// اصلاح شده: toOwnedSlice سازگار با Unmanaged ArrayList
// ============================================================

const std = @import("std");
const builtin = @import("builtin");

/// نوع Feature Flag
pub const FeatureType = enum {
    boolean, // فعال/غیرفعال
    percentage, // درصد (برای A/B testing)
    string, // مقدار رشته‌ای
    integer, // مقدار عددی
};

/// مقدار Feature
pub const FeatureValue = union(FeatureType) {
    boolean: bool,
    percentage: u8, // 0-100
    string: []const u8,
    integer: i64,

    pub fn asBool(self: FeatureValue) ?bool {
        return switch (self) {
            .boolean => |v| v,
            else => null,
        };
    }

    pub fn asPercentage(self: FeatureValue) ?u8 {
        return switch (self) {
            .percentage => |v| v,
            else => null,
        };
    }

    pub fn asString(self: FeatureValue) ?[]const u8 {
        return switch (self) {
            .string => |v| v,
            else => null,
        };
    }

    pub fn asInt(self: FeatureValue) ?i64 {
        return switch (self) {
            .integer => |v| v,
            else => null,
        };
    }
};

/// Feature definition
pub const Feature = struct {
    name: []const u8,
    description: []const u8,
    value: FeatureValue,
    default_value: FeatureValue,
    enabled_at_compile: bool,

    pub fn init(
        name: []const u8,
        description: []const u8,
        default_value: FeatureValue,
        enabled_at_compile: bool,
    ) Feature {
        return .{
            .name = name,
            .description = description,
            .value = default_value,
            .default_value = default_value,
            .enabled_at_compile = enabled_at_compile,
        };
    }

    pub fn isEnabled(self: Feature) bool {
        return switch (self.value) {
            .boolean => |v| v,
            .percentage => |v| v > 0,
            else => true,
        };
    }

    pub fn reset(self: *Feature) void {
        self.value = self.default_value;
    }
};

/// Feature Flags Registry
pub const FeatureFlags = struct {
    features: std.StringHashMap(Feature),
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) FeatureFlags {
        return .{
            .features = std.StringHashMap(Feature).init(allocator),
            .allocator = allocator,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *FeatureFlags) void {
        self.features.deinit();
    }

    /// ثبت feature جدید
    pub fn register(
        self: *FeatureFlags,
        name: []const u8,
        description: []const u8,
        default_value: FeatureValue,
        enabled_at_compile: bool,
    ) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const feature = Feature.init(name, description, default_value, enabled_at_compile);
        try self.features.put(name, feature);
    }

    /// فعال/غیرفعال کردن feature
    pub fn setEnabled(self: *FeatureFlags, name: []const u8, enabled: bool) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.features.getPtr(name)) |feature| {
            feature.value = .{ .boolean = enabled };
        } else {
            return error.FeatureNotFound;
        }
    }

    /// تنظیم مقدار feature
    pub fn setValue(self: *FeatureFlags, name: []const u8, value: FeatureValue) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.features.getPtr(name)) |feature| {
            // بررسی نوع
            if (@intFromEnum(feature.value) != @intFromEnum(value)) {
                return error.TypeMismatch;
            }
            feature.value = value;
        } else {
            return error.FeatureNotFound;
        }
    }

    /// بررسی فعال بودن feature
    pub fn isEnabled(self: *FeatureFlags, name: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.features.get(name)) |feature| {
            return feature.isEnabled();
        }
        return false;
    }

    /// دریافت مقدار feature
    pub fn getValue(self: *FeatureFlags, name: []const u8) ?FeatureValue {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.features.get(name)) |feature| {
            return feature.value;
        }
        return null;
    }

    /// دریافت feature
    pub fn getFeature(self: *FeatureFlags, name: []const u8) ?Feature {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.features.get(name);
    }

    /// لیست همه features
    pub fn list(self: *FeatureFlags, allocator: std.mem.Allocator) ![]Feature {
        self.mutex.lock();
        defer self.mutex.unlock();

        var result = try allocator.alloc(Feature, self.features.count());
        var it = self.features.valueIterator();
        var i: usize = 0;
        while (it.next()) |feature| : (i += 1) {
            result[i] = feature.*;
        }
        return result;
    }

    /// بارگذاری از فایل JSON
    pub fn loadFromJson(self: *FeatureFlags, json_str: []const u8) !void {
        _ = self;
        _ = json_str;
        // TODO: پیاده‌سازی JSON parser
        return error.NotImplemented;
    }

    /// ذخیره به فایل JSON
    pub fn saveToJson(self: *FeatureFlags, allocator: std.mem.Allocator) ![]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        var buffer = std.ArrayList(u8){};
        const writer = buffer.writer(allocator);

        try writer.writeAll("{\n");

        var it = self.features.iterator();
        var first = true;
        while (it.next()) |entry| {
            if (!first) try writer.writeAll(",\n");
            first = false;

            const feature = entry.value_ptr;
            try writer.print("  \"{s}\": ", .{feature.name});

            switch (feature.value) {
                .boolean => |v| try writer.print("{}", .{v}),
                .percentage => |v| try writer.print("{d}", .{v}),
                .string => |v| try writer.print("\"{s}\"", .{v}),
                .integer => |v| try writer.print("{d}", .{v}),
            }
        }

        try writer.writeAll("\n}\n");
        return buffer.toOwnedSlice(allocator);
    }
    /// بارگذاری از environment variables
    pub fn loadFromEnv(self: *FeatureFlags, prefix: []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var it = self.features.iterator();
        while (it.next()) |entry| {
            const feature = entry.value_ptr;

            // ساخت نام environment variable
            var env_name_buf: [256]u8 = undefined;
            const env_name = try std.fmt.bufPrint(&env_name_buf, "{s}_{s}", .{ prefix, feature.name });

            if (std.process.getEnvVarOwned(self.allocator, env_name)) |value| {
                defer self.allocator.free(value);

                switch (feature.value) {
                    .boolean => {
                        if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1")) {
                            feature.value = .{ .boolean = true };
                        } else {
                            feature.value = .{ .boolean = false };
                        }
                    },
                    .percentage => {
                        const pct = std.fmt.parseInt(u8, value, 10) catch continue;
                        feature.value = .{ .percentage = pct };
                    },
                    .integer => {
                        const num = std.fmt.parseInt(i64, value, 10) catch continue;
                        feature.value = .{ .integer = num };
                    },
                    .string => {
                        // Note: این یک copy است، در production باید managed شود
                        feature.value = .{ .string = value };
                    },
                }
            } else |_| {
                // Environment variable وجود ندارد
            }
        }
    }

    /// Reset all features to defaults
    pub fn resetAll(self: *FeatureFlags) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var it = self.features.valueIterator();
        while (it.next()) |feature| {
            feature.reset();
        }
    }
};

/// Compile-time feature checks
pub fn comptime_feature(comptime name: []const u8) bool {
    // این می‌تواند با build options کار کند
    return @hasDecl(@import("build_options"), name);
}

/// A/B Testing helper
pub fn isInPercentage(feature: Feature, user_id: u64) bool {
    if (feature.value != .percentage) return false;

    const pct = feature.value.percentage;
    if (pct == 0) return false;
    if (pct == 100) return true;

    // Hash user_id برای توزیع یکنواخت
    const hash = std.hash.Wyhash.hash(0, std.mem.asBytes(&user_id));
    const bucket = @as(u8, @intCast(hash % 100));

    return bucket < pct;
}

/// Global feature flags instance
var global_features: ?*FeatureFlags = null;

pub fn setGlobalFeatures(features: *FeatureFlags) void {
    global_features = features;
}

pub fn getGlobalFeatures() ?*FeatureFlags {
    return global_features;
}

/// Convenience functions for global instance
pub fn isEnabled(name: []const u8) bool {
    if (global_features) |features| {
        return features.isEnabled(name);
    }
    return false;
}

pub fn getValue(name: []const u8) ?FeatureValue {
    if (global_features) |features| {
        return features.getValue(name);
    }
    return null;
}

/// Feature decorator (macro simulation)
pub fn withFeature(
    comptime feature_name: []const u8,
    comptime enabled_fn: anytype,
    comptime disabled_fn: anytype,
) @TypeOf(enabled_fn, disabled_fn) {
    return if (isEnabled(feature_name)) enabled_fn else disabled_fn;
}

test "feature flags basic" {
    var flags = FeatureFlags.init(std.testing.allocator);
    defer flags.deinit();

    try flags.register("test_feature", "A test feature", .{ .boolean = false }, false);

    try std.testing.expect(!flags.isEnabled("test_feature"));

    try flags.setEnabled("test_feature", true);
    try std.testing.expect(flags.isEnabled("test_feature"));
}

test "feature percentage" {
    var flags = FeatureFlags.init(std.testing.allocator);
    defer flags.deinit();

    try flags.register("ab_test", "A/B test feature", .{ .percentage = 50 }, false);

    const feature = flags.getFeature("ab_test").?;

    // تست با چند user_id
    var enabled_count: u32 = 0;
    var i: u64 = 0;
    while (i < 1000) : (i += 1) {
        if (isInPercentage(feature, i)) {
            enabled_count += 1;
        }
    }

    // باید تقریباً 50% باشد (با تلرانس)
    try std.testing.expect(enabled_count > 400 and enabled_count < 600);
}

test "feature value types" {
    var flags = FeatureFlags.init(std.testing.allocator);
    defer flags.deinit();

    try flags.register("int_feature", "Integer feature", .{ .integer = 42 }, false);
    try flags.register("str_feature", "String feature", .{ .string = "hello" }, false);

    const int_val = flags.getValue("int_feature").?.asInt();
    try std.testing.expectEqual(@as(i64, 42), int_val.?);

    const str_val = flags.getValue("str_feature").?.asString();
    try std.testing.expectEqualStrings("hello", str_val.?);
}

test "feature save to json" {
    var flags = FeatureFlags.init(std.testing.allocator);
    defer flags.deinit();

    try flags.register("feature1", "First feature", .{ .boolean = true }, false);
    try flags.register("feature2", "Second feature", .{ .integer = 100 }, false);

    const json = try flags.saveToJson(std.testing.allocator);
    defer std.testing.allocator.free(json);

    try std.testing.expect(json.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "feature1") != null);
}
