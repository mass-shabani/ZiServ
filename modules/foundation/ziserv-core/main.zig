// ============================================================
// مثال استفاده از تمام قابلیت‌های جدید ziserv-core
// ============================================================

const std = @import("std");
const core = @import("ziserv-core");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("\n", .{});
    std.debug.print("────────────────────────────────────────\n", .{});
    std.debug.print("  ZiServ Core - Complete Feature Demo\n", .{});
    std.debug.print("────────────────────────────────────────\n", .{});
    std.debug.print("\n", .{});

    // ========================================
    // 1. Logger System
    // ========================================
    std.debug.print("1. Logger System Demo\n", .{});
    std.debug.print("────────────────────────────────────────\n", .{});

    var logger = core.Logger.init(allocator, .{
        .level = .debug,
        .format = .colored,
        .show_timestamp = true,
        .show_source = true,
    });
    defer logger.deinit();

    // اضافه کردن console sink
    var console_sink = core.logger.ConsoleSink.init(.{}, std.io.getStdOut());
    try logger.addSink(console_sink.sink());

    // اضافه کردن file sink
    var file_sink = try core.logger.FileSink.init(allocator, "app.log", .{});
    defer file_sink.deinit();
    try logger.addSink(file_sink.sink());

    logger.info("Application started", .{});
    logger.debug("Debug message with value: {d}", .{42});
    logger.warn("Warning: Something might be wrong", .{});
    logger.err("Error occurred: {s}", .{"Connection timeout"});

    // Global logger
    core.logger.setGlobalLogger(&logger);
    core.logger.info("Global logger message", .{});

    std.debug.print("\n", .{});

    // ========================================
    // 2. Metrics System
    // ========================================
    std.debug.print("2. Metrics System Demo\n", .{});
    std.debug.print("────────────────────────────────────────\n", .{});

    var registry = core.MetricsRegistry.init(allocator);
    defer registry.deinit();

    // Counter
    const requests_counter = try registry.registerCounter(
        "http_requests_total",
        "Total HTTP requests",
        .count,
    );
    requests_counter.inc();
    requests_counter.add(5);
    std.debug.print("Requests counter: {d}\n", .{requests_counter.get()});

    // Gauge
    const active_connections = try registry.registerGauge(
        "active_connections",
        "Number of active connections",
        .count,
    );
    active_connections.set(10);
    active_connections.inc();
    active_connections.inc();
    std.debug.print("Active connections: {d}\n", .{active_connections.get()});

    // Histogram
    const buckets = [_]f64{ 10, 50, 100, 500, 1000 };
    const response_time = try registry.registerHistogram(
        "http_response_time_ms",
        "HTTP response time in milliseconds",
        .milliseconds,
        &buckets,
    );

    // Simulate some requests
    response_time.observe(25);
    response_time.observe(75);
    response_time.observe(150);
    response_time.observe(450);

    std.debug.print("Response time - Count: {d}, Mean: {d:.2}ms\n", .{
        response_time.getCount(),
        response_time.getMean(),
    });

    // Summary
    const memory_usage = try registry.registerSummary(
        "memory_usage_bytes",
        "Memory usage in bytes",
        .bytes,
    );
    memory_usage.observe(1024);
    memory_usage.observe(2048);
    memory_usage.observe(4096);

    std.debug.print("Memory usage - Min: {d}, Max: {d}, Mean: {d:.2}\n", .{
        memory_usage.getMin(),
        memory_usage.getMax(),
        memory_usage.getMean(),
    });

    // Export to Prometheus format
    var prometheus_output = std.ArrayList(u8).init(allocator);
    defer prometheus_output.deinit();
    try registry.exportPrometheus(prometheus_output.writer());

    std.debug.print("\nPrometheus export (first 200 chars):\n{s}...\n", .{
        prometheus_output.items[0..@min(200, prometheus_output.items.len)],
    });

    std.debug.print("\n", .{});

    // ========================================
    // 3. Result Type
    // ========================================
    std.debug.print("3. Result Type Demo\n", .{});
    std.debug.print("────────────────────────────────────────\n", .{});

    // Basic Result
    const R = core.Result(i32, error{Failed});

    const success = R.ok(42);
    if (success.isOk()) {
        std.debug.print("Success value: {d}\n", .{success.unwrap()});
    }

    const failure = R.err(error.Failed);
    if (failure.isErr()) {
        std.debug.print("Failed with error\n", .{});
        std.debug.print("Using default: {d}\n", .{failure.unwrapOr(0)});
    }

    // Map operation
    const doubled = success.map(struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);
    std.debug.print("Doubled value: {d}\n", .{doubled.unwrap()});

    // Option Type
    const O = core.Option([]const u8);

    const some = O.some("Hello");
    std.debug.print("Option value: {s}\n", .{some.unwrap()});

    const none = O.none();
    std.debug.print("None with default: {s}\n", .{none.unwrapOr("Default")});

    // Wrap Zig error union
    const zigResult: error{Failed}!i32 = 100;
    const wrapped = core.result.wrapResult(zigResult);
    std.debug.print("Wrapped result: {d}\n", .{wrapped.unwrap()});

    std.debug.print("\n", .{});

    // ========================================
    // 4. Feature Flags
    // ========================================
    std.debug.print("4. Feature Flags Demo\n", .{});
    std.debug.print("────────────────────────────────────────\n", .{});

    var flags = core.FeatureFlags.init(allocator);
    defer flags.deinit();

    // Register features
    try flags.register("new_ui", "Enable new UI", .{ .boolean = false }, false);
    try flags.register("max_connections", "Max connections", .{ .integer = 100 }, true);
    try flags.register("ab_test", "A/B test", .{ .percentage = 50 }, false);
    try flags.register("api_version", "API version", .{ .string = "v1" }, true);

    std.debug.print("New UI enabled: {}\n", .{flags.isEnabled("new_ui")});

    // Enable feature
    try flags.setEnabled("new_ui", true);
    std.debug.print("New UI enabled (after): {}\n", .{flags.isEnabled("new_ui")});

    // Get values
    const max_conn = flags.getValue("max_connections").?.asInt().?;
    std.debug.print("Max connections: {d}\n", .{max_conn});

    const api_ver = flags.getValue("api_version").?.asString().?;
    std.debug.print("API version: {s}\n", .{api_ver});

    // A/B testing
    const ab_feature = flags.getFeature("ab_test").?;
    var enabled_users: u32 = 0;
    var i: u64 = 0;
    while (i < 100) : (i += 1) {
        if (core.features.isInPercentage(ab_feature, i)) {
            enabled_users += 1;
        }
    }
    std.debug.print("A/B test enabled for {d}/100 users\n", .{enabled_users});

    // Export to JSON
    const json = try flags.saveToJson(allocator);
    defer allocator.free(json);
    std.debug.print("\nFeature flags JSON:\n{s}\n", .{json});

    // Set global
    core.features.setGlobalFeatures(&flags);
    std.debug.print("Global check - new_ui: {}\n", .{core.features.isEnabled("new_ui")});

    std.debug.print("\n", .{});

    // ========================================
    // 5. Integration Example
    // ========================================
    std.debug.print("5. Integration Example\n", .{});
    std.debug.print("────────────────────────────────────────\n", .{});

    // Simulate handling a request
    const request_result = handleRequest(&logger, &registry, &flags);

    if (request_result.isOk()) {
        std.debug.print("Request handled successfully: {s}\n", .{request_result.unwrap()});
    } else {
        logger.err("Request failed", .{});
    }

    std.debug.print("\n", .{});
    std.debug.print("────────────────────────────────────────\n", .{});
    std.debug.print("  Demo Completed Successfully!\n", .{});
    std.debug.print("────────────────────────────────────────\n", .{});
    std.debug.print("\n", .{});
}

fn handleRequest(
    logger: *core.Logger,
    registry: *core.MetricsRegistry,
    flags: *core.FeatureFlags,
) core.Result([]const u8, error{RequestFailed}) {
    logger.info("Handling request...", .{});

    // Increment counter
    if (registry.getCounter("http_requests_total")) |counter| {
        counter.inc();
    }

    // Check feature flag
    if (!flags.isEnabled("new_ui")) {
        logger.debug("Using old UI", .{});
    }

    // Simulate work with timer
    const response_time = registry.getHistogram("http_response_time_ms") orelse {
        return .{ .err = error.RequestFailed };
    };

    var timer = core.metrics.Timer.start(response_time);
    std.time.sleep(10 * std.time.ns_per_ms);
    timer.stop();

    return .{ .ok = "Request processed successfully" };
}
