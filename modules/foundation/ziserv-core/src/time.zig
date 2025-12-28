// ============================================================
// فایل: modules/foundation/ziserv-core/src/time.zig
// ابزارهای زمان
// ============================================================

const std = @import("std");

/// مدیریت زمان
pub const Time = struct {
    /// زمان فعلی (nanoseconds)
    pub fn now() i128 {
        return std.time.nanoTimestamp();
    }

    /// زمان فعلی (milliseconds)
    pub fn nowMillis() i128 {
        return @divTrunc(now(), 1_000_000);
    }

    /// زمان فعلی (seconds)
    pub fn nowSeconds() i128 {
        return @divTrunc(now(), 1_000_000_000);
    }

    /// تبدیل nanoseconds به milliseconds
    pub fn nsToMs(ns: i128) i128 {
        return @divTrunc(ns, 1_000_000);
    }

    /// تبدیل milliseconds به nanoseconds
    pub fn msToNs(ms: i128) i128 {
        return ms * 1_000_000;
    }
};

/// Stopwatch برای اندازه‌گیری زمان
pub const Stopwatch = struct {
    start_time: i128,
    elapsed: i128,
    running: bool,

    pub fn init() Stopwatch {
        return .{
            .start_time = 0,
            .elapsed = 0,
            .running = false,
        };
    }

    pub fn start(self: *Stopwatch) void {
        self.start_time = Time.now();
        self.running = true;
    }

    pub fn stop(self: *Stopwatch) void {
        if (self.running) {
            self.elapsed += Time.now() - self.start_time;
            self.running = false;
        }
    }

    pub fn reset(self: *Stopwatch) void {
        self.start_time = 0;
        self.elapsed = 0;
        self.running = false;
    }

    pub fn elapsedNs(self: *const Stopwatch) i128 {
        if (self.running) {
            return self.elapsed + (Time.now() - self.start_time);
        }
        return self.elapsed;
    }

    pub fn elapsedMs(self: *const Stopwatch) i128 {
        return Time.nsToMs(self.elapsedNs());
    }
};

test "time utilities" {
    const t1 = Time.now();
    std.Thread.sleep(1 * std.time.ns_per_ms);
    const t2 = Time.now();

    try std.testing.expect(t2 > t1);
}

test "stopwatch" {
    var sw = Stopwatch.init();
    sw.start();
    std.Thread.sleep(10 * std.time.ns_per_ms);
    sw.stop();

    const elapsed = sw.elapsedMs();
    try std.testing.expect(elapsed >= 10);
}
