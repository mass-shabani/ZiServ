// ============================================================
// فایل: modules/foundation/ziserv-codec/src/bench.zig
// Benchmarks - نسخه تکمیل شده
// ============================================================

const std = @import("std");
const core = @import("ziserv-core");
const codec = @import("ziserv-codec");
const bytes = @import("ziserv-bytes"); // برای تست Frame نیاز است

fn benchBase64(iterations: usize) !void {
    const data = "The quick brown fox jumps over the lazy dog";
    var output: [100]u8 = undefined;
    var decoded: [100]u8 = undefined;

    var timer = core.time.Stopwatch.init();

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = try codec.base64.encode(data, &output);
    }
    timer.stop();
    std.debug.print("Base64 encode: {d} iterations in {d}ms ({d} MB/s)\n", .{
        iterations,
        timer.elapsedMs(),
        if (timer.elapsedMs() > 0) @divTrunc(@as(i128, iterations * data.len), @as(i128, timer.elapsedMs() * 1000)) else @as(i128, iterations / 1000 * data.len),
    });
    std.debug.print("    -> output result: {s}\n", .{output});

    const encoded_len = try codec.base64.encode(data, &output);
    timer.reset();
    timer.start();
    i = 0;
    while (i < iterations) : (i += 1) {
        _ = try codec.base64.decode(output[0..encoded_len], &decoded);
    }
    timer.stop();
    std.debug.print("Base64 decode: {d} iterations in {d}ms ({d} MB/s)\n", .{
        iterations,
        timer.elapsedMs(),
        if (timer.elapsedMs() > 0) @divTrunc(@as(i128, iterations * data.len), @as(i128, timer.elapsedMs() * 1000)) else @as(i128, iterations / 1000 * data.len),
    });
    std.debug.print("    -> decoded result: {s}\n", .{decoded});
}

fn benchHex(iterations: usize) !void {
    const data = "The quick brown fox jumps over the lazy dog";
    var output: [100]u8 = undefined;
    var decoded: [100]u8 = undefined;

    var timer = core.time.Stopwatch.init();

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = try codec.hex.encodeLower(data, &output);
    }
    timer.stop();

    std.debug.print("Hex encode: {d} iterations in {d}ms ({d} MB/s)\n", .{
        iterations,
        timer.elapsedMs(),
        if (timer.elapsedMs() > 0) @divTrunc(@as(i128, iterations * data.len), @as(i128, timer.elapsedMs() * 1000)) else @as(i128, iterations / 1000 * data.len),
    });
    std.debug.print("    -> output result: {s}\n", .{output});

    const encoded_len = try codec.hex.encodeLower(data, &output);

    timer.reset();
    timer.start();
    i = 0;
    while (i < iterations) : (i += 1) {
        _ = try codec.hex.decode(output[0..encoded_len], &decoded);
    }
    timer.stop();
    std.debug.print("Hex decode: {d} iterations in {d}ms ({d} MB/s)\n", .{
        iterations,
        timer.elapsedMs(),
        if (timer.elapsedMs() > 0) @divTrunc(@as(i128, iterations * data.len), @as(i128, timer.elapsedMs() * 1000)) else @as(i128, iterations / 1000 * data.len),
    });
    std.debug.print("    -> decoded result: {s}\n", .{decoded});
}

fn benchVarint(iterations: usize) !void {
    var output: [10]u8 = undefined;
    var timer = core.time.Stopwatch.init();

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = try codec.varint.encodeU64(9488784884512894, &output);
    }
    timer.stop();

    std.debug.print("Varint encode: {d} iterations in {d}ns\n", .{
        iterations,
        timer.elapsedNs(),
    });

    const len = try codec.varint.encodeU64(1234155678, &output);
    timer.reset();
    timer.start();
    i = 0;
    while (i < iterations) : (i += 1) {
        _ = try codec.varint.decodeU64(output[0..len]);
    }
    timer.stop();

    std.debug.print("Varint decode: {d} iterations in {d}ns\n", .{
        iterations,
        timer.elapsedNs(),
    });
    // std.debug.print("    -> output result: {any}\n", .{output});
}

// بنچمارک جدید برای UTF8
fn benchUtf8(iterations: usize) !void {
    const data = "Hello, 世界! مرحبا بالعالم 🌍"; // داده چند زبانه
    var timer = core.time.Stopwatch.init();

    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = codec.utf8.validate(data);
    }
    timer.stop();

    std.debug.print("UTF8 validate: {d} iterations in {d}ms ({d} MB/s)\n", .{
        iterations,
        timer.elapsedMs(),
        if (timer.elapsedMs() > 0) @divTrunc(@as(i128, iterations * data.len), @as(i128, timer.elapsedMs() * 1000)) else @as(i128, iterations / 1000 * data.len),
    });
    std.debug.print("    -> data validated\n", .{});
}

// بنچمارک جدید برای Frame (Length-Prefixed Frame)
fn benchFrame(iterations: usize) !void {
    // استفاده از Page Allocator برای BytesMut
    const allocator = std.heap.page_allocator;
    const data = "Frame data packet #12345 for testing ZiServ codec performance";

    // بافر خروجی برای encoding
    var output_buf = bytes.BytesMut.init(allocator);
    defer output_buf.deinit();

    var timer = core.time.Stopwatch.init();

    // --- Test Encode ---
    timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        output_buf.clear(); // پاک کردن بافر برای استفاده مجدد
        try codec.frame.LengthPrefixedFrame.encode(data, &output_buf);
    }
    timer.stop();

    std.debug.print("Frame encode: {d} iterations in {d}ms ({d} MB/s)\n", .{
        iterations,
        timer.elapsedMs(),
        if (timer.elapsedMs() > 0) @divTrunc(@as(i128, iterations * data.len), @as(i128, timer.elapsedMs() * 1000)) else @as(i128, iterations / 1000 * data.len),
    });

    // آماده‌سازی دیتای رمزگذاری شده برای تست دیکد
    output_buf.clear();
    try codec.frame.LengthPrefixedFrame.encode(data, &output_buf);
    const encoded_frame = output_buf.readBytes(); // گرفتن اسلایس ثابت بایت‌ها

    // --- Test Decode ---
    timer.reset();
    timer.start();
    i = 0;
    while (i < iterations) : (i += 1) {
        _ = try codec.frame.LengthPrefixedFrame.decode(encoded_frame);
    }
    timer.stop();

    std.debug.print("Frame decode: {d} iterations in {d}ms ({d} MB/s)\n", .{
        iterations,
        timer.elapsedMs(),
        if (timer.elapsedMs() > 0) @divTrunc(@as(i128, iterations * data.len), @as(i128, timer.elapsedMs() * 1000)) else @as(i128, iterations / 1000 * data.len),
    });
}

pub fn main() !void {
    std.debug.print("\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("  ZiServ Codec - Performance Benchmarks (Full)\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("\n", .{});

    const iterations = 1_000_000;

    // اجرای بنچمارک‌های موجود
    try benchBase64(iterations);
    std.debug.print("\n", .{});

    try benchHex(iterations);
    std.debug.print("\n", .{});

    try benchVarint(iterations);
    std.debug.print("\n", .{});

    // اجرای بنچمارک‌های اضافه شده
    try benchUtf8(iterations);
    std.debug.print("\n", .{});

    try benchFrame(iterations);

    std.debug.print("\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("  Benchmarks Completed!\n", .{});
    std.debug.print("====================================================================\n", .{});
    std.debug.print("\n", .{});
}
