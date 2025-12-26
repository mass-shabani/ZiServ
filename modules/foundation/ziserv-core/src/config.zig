// ============================================================
// فایل: modules/foundation/ziserv-core/src/config.zig
// سیستم پیکربندی
// ============================================================

const std = @import("std");

/// پیکربندی پایه
pub const Config = struct {
    /// نام برنامه
    app_name: []const u8,

    /// نسخه
    version: []const u8,

    /// محیط اجرا
    environment: Environment,

    /// سطح لاگ
    log_level: LogLevel,

    /// تنظیمات حافظه
    memory: MemoryConfig,

    pub const Environment = enum {
        development,
        staging,
        production,

        pub fn fromString(s: []const u8) ?Environment {
            if (std.mem.eql(u8, s, "development")) return .development;
            if (std.mem.eql(u8, s, "staging")) return .staging;
            if (std.mem.eql(u8, s, "production")) return .production;
            return null;
        }
    };

    pub const LogLevel = enum {
        debug,
        info,
        warn,
        err,
        none,

        pub fn fromString(s: []const u8) ?LogLevel {
            if (std.mem.eql(u8, s, "debug")) return .debug;
            if (std.mem.eql(u8, s, "info")) return .info;
            if (std.mem.eql(u8, s, "warn")) return .warn;
            if (std.mem.eql(u8, s, "error")) return .err;
            if (std.mem.eql(u8, s, "none")) return .none;
            return null;
        }
    };

    pub const MemoryConfig = struct {
        max_heap_size: usize,
        use_arena: bool,
        pool_size: usize,
    };

    pub fn default() Config {
        return .{
            .app_name = "ZiServ App",
            .version = "0.1.0",
            .environment = .development,
            .log_level = .info,
            .memory = .{
                .max_heap_size = 1024 * 1024 * 1024, // 1GB
                .use_arena = true,
                .pool_size = 64,
            },
        };
    }
};

/// Builder برای Config
pub const ConfigBuilder = struct {
    config: Config,

    pub fn init() ConfigBuilder {
        return .{ .config = Config.default() };
    }

    pub fn withAppName(self: *ConfigBuilder, name: []const u8) *ConfigBuilder {
        self.config.app_name = name;
        return self;
    }

    pub fn withVersion(self: *ConfigBuilder, version: []const u8) *ConfigBuilder {
        self.config.version = version;
        return self;
    }

    pub fn withEnvironment(self: *ConfigBuilder, env: Config.Environment) *ConfigBuilder {
        self.config.environment = env;
        return self;
    }

    pub fn withLogLevel(self: *ConfigBuilder, level: Config.LogLevel) *ConfigBuilder {
        self.config.log_level = level;
        return self;
    }

    pub fn build(self: ConfigBuilder) Config {
        return self.config;
    }
};

test "config builder" {
    var builder = ConfigBuilder.init();
    const config = builder
        .withAppName("Test App")
        .withEnvironment(.production)
        .withLogLevel(.warn)
        .build();

    try std.testing.expectEqualStrings("Test App", config.app_name);
    try std.testing.expectEqual(Config.Environment.production, config.environment);
}
