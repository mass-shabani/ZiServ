// ============================================================
// فایل: modules/foundation/ziserv-core/src/root.zig
// ماژول اصلی ziserv-core - نسخه کامل و تکمیل شده
// ============================================================

const std = @import("std");

// ===============================================
// زیرماژول‌های پایه (Foundation)
// ===============================================
/// Platform detection و utilities
pub const platform = @import("platform.zig");

/// Error types و error handling
pub const error_types = @import("error.zig");

/// Configuration system
pub const config = @import("config.zig");

/// Traits و interfaces مشترک
pub const traits = @import("traits.zig");

/// Memory management utilities
pub const memory = @import("memory.zig");

/// Time utilities
pub const time = @import("time.zig");

// ===============================================
// زیرماژول‌های جدید (New Features)
// ===============================================
/// Logger system - سیستم لاگ حرفه‌ای
pub const logger = @import("logger.zig");

/// Metrics/Telemetry system - سیستم اندازه‌گیری performance
pub const metrics = @import("metrics.zig");

/// Result type - بهبود error handling
pub const result = @import("result.zig");

/// Feature flags system - مدیریت ویژگی‌ها
pub const features = @import("features.zig");

// ===============================================
// Type Aliases (برای راحتی استفاده)
// ===============================================

// Platform
pub const Os = platform.Os;
pub const Arch = platform.Arch;
pub const PlatformInfo = platform.PlatformInfo;
pub const Platform = platform.Platform;

// Error
pub const Error = error_types.Error;
pub const ErrorContext = error_types.ErrorContext;
pub const ErrorWithContext = error_types.ErrorWithContext;

// Config
pub const Config = config.Config;
pub const ConfigBuilder = config.ConfigBuilder;

// Memory
pub const Arena = memory.Arena;
pub const MemoryStats = memory.MemoryStats;

// Time
pub const Time = time.Time;
pub const Stopwatch = time.Stopwatch;

// Logger
pub const Logger = logger.Logger;
pub const LogLevel = logger.Level;
pub const LoggerConfig = logger.LoggerConfig;
pub const ConsoleSink = logger.ConsoleSink;
pub const FileSink = logger.FileSink;
pub const LogFormat = logger.Format;

// Metrics
pub const MetricsRegistry = metrics.MetricsRegistry;
pub const Counter = metrics.Counter;
pub const Gauge = metrics.Gauge;
pub const Histogram = metrics.Histogram;
pub const Summary = metrics.Summary;
pub const Timer = metrics.Timer;
pub const MetricType = metrics.MetricType;
pub const Unit = metrics.Unit;

// Result
pub const Result = result.Result;
pub const Option = result.Option;
pub const ResultWithContext = result.ResultWithContext;
pub const wrapResult = result.wrapResult;

// Features
pub const FeatureFlags = features.FeatureFlags;
pub const Feature = features.Feature;
pub const FeatureValue = features.FeatureValue;
pub const FeatureType = features.FeatureType;

// ===============================================
// اطلاعات ماژول
// ===============================================
/// نسخه ماژول
pub const version = "0.1.0";

/// نام ماژول
pub const name = "ziserv-core";

/// توضیحات ماژول
pub const description = "Core foundation library for ZiServ framework";

/// سازنده
pub const author = "ZiServ Team";

/// لایسنس
pub const license = "MIT";

// ===============================================
// تنظیمات پیش‌فرض
// ===============================================
/// پیکربندی پیش‌فرض
pub const default_config = config.Config.default();

/// پیکربندی پیش‌فرض Logger
pub const default_logger_config = logger.LoggerConfig{
    .level = .info,
    .format = if (platform.Os.isWindows()) .text else .colored,
    .show_timestamp = true,
    .show_source = true,
    .show_thread_id = false,
    .buffer_size = 4096,
};

// ===============================================
// Helper Functions
// ===============================================
/// دریافت اطلاعات پلتفرم فعلی
pub fn getPlatformInfo() PlatformInfo {
    return PlatformInfo.current();
}

/// دریافت نام سیستم‌عامل
pub fn getOsName() []const u8 {
    return Os.name();
}

/// دریافت نام معماری CPU
pub fn getArchName() []const u8 {
    return Arch.name();
}

/// آیا پلتفرم POSIX است؟
pub fn isPosix() bool {
    return Os.isPosix();
}

/// آیا پلتفرم Windows است؟
pub fn isWindows() bool {
    return Os.isWindows();
}

// ===============================================
// Initialization Helpers
// ===============================================
/// ساخت یک Logger ساده با تنظیمات پیش‌فرض
pub fn createDefaultLogger(allocator: std.mem.Allocator) !Logger {
    var log = Logger.init(allocator, default_logger_config);

    var console_sink = ConsoleSink.init(default_logger_config, std.io.getStdOut());
    try log.addSink(console_sink.sink());

    return log;
}

/// ساخت یک MetricsRegistry ساده
pub fn createDefaultMetrics(allocator: std.mem.Allocator) MetricsRegistry {
    return MetricsRegistry.init(allocator);
}

/// ساخت یک FeatureFlags ساده
pub fn createDefaultFeatures(allocator: std.mem.Allocator) FeatureFlags {
    return FeatureFlags.init(allocator);
}

// ===============================================
// Global State Management
// ===============================================
/// ساختار Global Context برای ZiServ
pub const GlobalContext = struct {
    logger: ?*Logger,
    metrics: ?*MetricsRegistry,
    features: ?*FeatureFlags,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) GlobalContext {
        return .{
            .logger = null,
            .metrics = null,
            .features = null,
            .allocator = allocator,
        };
    }

    pub fn setLogger(self: *GlobalContext, log: *Logger) void {
        self.logger = log;
        logger.setGlobalLogger(log);
    }

    pub fn setMetrics(self: *GlobalContext, reg: *MetricsRegistry) void {
        self.metrics = reg;
        metrics.setGlobalRegistry(reg);
    }

    pub fn setFeatures(self: *GlobalContext, flags: *FeatureFlags) void {
        self.features = flags;
        features.setGlobalFeatures(flags);
    }

    pub fn getLogger(self: *const GlobalContext) ?*Logger {
        return self.logger;
    }

    pub fn getMetrics(self: *const GlobalContext) ?*MetricsRegistry {
        return self.metrics;
    }

    pub fn getFeatures(self: *const GlobalContext) ?*FeatureFlags {
        return self.features;
    }
};

var global_context: ?*GlobalContext = null;

/// تنظیم global context
pub fn setGlobalContext(ctx: *GlobalContext) void {
    global_context = ctx;
}

/// دریافت global context
pub fn getGlobalContext() ?*GlobalContext {
    return global_context;
}

// ===============================================
// Utility Macros (compile-time helpers)
// ===============================================
/// بررسی اینکه آیا در حالت debug هستیم
pub inline fn isDebugMode() bool {
    return @import("builtin").mode == .Debug;
}

/// بررسی اینکه آیا در حالت release هستیم
pub inline fn isReleaseMode() bool {
    return @import("builtin").mode == .ReleaseFast or
        @import("builtin").mode == .ReleaseSafe or
        @import("builtin").mode == .ReleaseSmall;
}

/// دریافت تعداد هسته‌های CPU
pub fn getCpuCount() !usize {
    return Platform.cpuCount();
}

/// دریافت اندازه صفحه حافظه
pub fn getPageSize() usize {
    return Platform.pageSize();
}

// ===============================================
// Version Information
// ===============================================
/// نسخه به صورت struct
pub const Version = struct {
    major: u32 = 0,
    minor: u32 = 1,
    patch: u32 = 0,

    pub fn toString(self: Version, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{d}.{d}.{d}", .{
            self.major,
            self.minor,
            self.patch,
        });
    }

    pub fn current() Version {
        return .{
            .major = 0,
            .minor = 1,
            .patch = 0,
        };
    }
};

/// نسخه فعلی
pub const version_info = Version.current();

// ===============================================
// Banner و Information
// ===============================================
/// نمایش banner ZiServ Core
pub fn printBanner(writer: anytype) !void {
    try writer.writeAll("\n");
    try writer.writeAll("╔════════════════════════════════════════════════════════════════╗\n");
    try writer.writeAll("║              ZiServ Core - Foundation Library                  ║\n");
    try writer.writeAll("╠════════════════════════════════════════════════════════════════╣\n");
    try writer.print("║  Version:     {s:<50}║\n", .{version});
    try writer.print("║  Platform:    {s:<50}║\n", .{getOsName()});
    try writer.print("║  Arch:        {s:<50}║\n", .{getArchName()});
    try writer.print("║  Mode:        {s:<50}║\n", .{if (isDebugMode()) "Debug" else "Release"});
    try writer.writeAll("╚════════════════════════════════════════════════════════════════╝\n");
    try writer.writeAll("\n");
}

/// نمایش اطلاعات سیستم
pub fn printSystemInfo(writer: anytype) !void {
    const cpu_count = try getCpuCount();
    const page_size = getPageSize();

    try writer.writeAll("System Information:\n");
    try writer.writeAll("───────────────────────────────────\n");
    try writer.print("  CPU Cores:      {d}\n", .{cpu_count});
    try writer.print("  Page Size:      {d} bytes\n", .{page_size});
    try writer.print("  OS:             {s}\n", .{getOsName()});
    try writer.print("  Architecture:   {s}\n", .{getArchName()});
    try writer.print("  POSIX:          {}\n", .{isPosix()});
    try writer.writeAll("\n");
}

// ===============================================
// Testing Support
// ===============================================
/// Helper برای تست‌ها
pub const testing = struct {
    /// ساخت logger برای تست
    pub fn createTestLogger() !Logger {
        var log = Logger.init(std.testing.allocator, .{
            .level = .debug,
            .format = .text,
            .show_timestamp = false,
            .show_source = false,
        });

        var console_sink = ConsoleSink.init(.{}, std.io.getStdOut());
        try log.addSink(console_sink.sink());

        return log;
    }

    /// ساخت metrics registry برای تست
    pub fn createTestMetrics() MetricsRegistry {
        return MetricsRegistry.init(std.testing.allocator);
    }

    /// ساخت feature flags برای تست
    pub fn createTestFeatures() FeatureFlags {
        return FeatureFlags.init(std.testing.allocator);
    }
};

// ===============================================
// Module Tests
// ===============================================

test "import all submodules" {
    std.testing.refAllDecls(@This());
}

test "platform detection" {
    const info = getPlatformInfo();
    try std.testing.expect(info.os != .unknown);
    try std.testing.expect(info.arch != .unknown);
}

test "version info" {
    const ver = Version.current();
    try std.testing.expectEqual(@as(u32, 0), ver.major);
    try std.testing.expectEqual(@as(u32, 1), ver.minor);
}

test "helper functions" {
    const os_name = getOsName();
    try std.testing.expect(os_name.len > 0);

    const arch_name = getArchName();
    try std.testing.expect(arch_name.len > 0);

    const cpu_count = try getCpuCount();
    try std.testing.expect(cpu_count > 0);

    const page_size = getPageSize();
    try std.testing.expect(page_size > 0);
}

test "global context" {
    var ctx = GlobalContext.init(std.testing.allocator);

    var log = try createDefaultLogger(std.testing.allocator);
    defer log.deinit();

    ctx.setLogger(&log);
    try std.testing.expect(ctx.getLogger() != null);

    var reg = createDefaultMetrics(std.testing.allocator);
    defer reg.deinit();

    ctx.setMetrics(&reg);
    try std.testing.expect(ctx.getMetrics() != null);

    var flags = createDefaultFeatures(std.testing.allocator);
    defer flags.deinit();

    ctx.setFeatures(&flags);
    try std.testing.expect(ctx.getFeatures() != null);
}

test "create default components" {
    var log = try createDefaultLogger(std.testing.allocator);
    defer log.deinit();

    log.info("Test log message", .{});

    var reg = createDefaultMetrics(std.testing.allocator);
    defer reg.deinit();

    const counter = try reg.registerCounter("test", "Test counter", .count);
    counter.inc();
    try std.testing.expectEqual(@as(u64, 1), counter.get());

    var flags = createDefaultFeatures(std.testing.allocator);
    defer flags.deinit();

    try flags.register("test_feature", "Test", .{ .boolean = true }, false);
    try std.testing.expect(flags.isEnabled("test_feature"));
}

test "banner and system info" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    try printBanner(buffer.writer());
    try std.testing.expect(buffer.items.len > 0);

    buffer.clearRetainingCapacity();
    try printSystemInfo(buffer.writer());
    try std.testing.expect(buffer.items.len > 0);
}

// تست‌ها
test {
    std.testing.refAllDecls(@This());
}
