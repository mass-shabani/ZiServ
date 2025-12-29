// ============================================================
// فایل: modules/foundation/ziserv-codec/src/utf8.zig
// UTF-8 validation و utilities - بهینه شده
// ============================================================

const std = @import("std");

/// بررسی معتبر بودن UTF-8 (بهینه شده)
pub fn validate(data: []const u8) bool {
    var i: usize = 0;
    while (i < data.len) {
        const byte = data[i];

        if (byte < 0x80) {
            // ASCII - 1 byte
            i += 1;
        } else if (byte < 0xC0) {
            // Invalid start byte
            return false;
        } else if (byte < 0xE0) {
            // 2 bytes
            if (i + 1 >= data.len) return false;
            if (!isContinuation(data[i + 1])) return false;
            i += 2;
        } else if (byte < 0xF0) {
            // 3 bytes
            if (i + 2 >= data.len) return false;
            if (!isContinuation(data[i + 1])) return false;
            if (!isContinuation(data[i + 2])) return false;
            i += 3;
        } else if (byte < 0xF8) {
            // 4 bytes
            if (i + 3 >= data.len) return false;
            if (!isContinuation(data[i + 1])) return false;
            if (!isContinuation(data[i + 2])) return false;
            if (!isContinuation(data[i + 3])) return false;
            i += 4;
        } else {
            // Invalid
            return false;
        }
    }
    return true;
}

/// بررسی continuation byte
inline fn isContinuation(byte: u8) bool {
    return (byte & 0xC0) == 0x80;
}

/// دریافت تعداد طول بایت های یک رشته
pub fn charCount(str: []const u8) usize {
    if (str.len == 0) return 0;

    var count: usize = 0;
    var i: usize = 0;
    const len = str.len;

    while (i < len) {
        const byte = str[i];

        // استفاده از بلوک شرطی بهینه (Branch Prediction-friendly)
        const next_step: usize = blk: {
            if (byte < 0x80) {
                break :blk 1; // ASCII
            } else if (byte < 0xC0) {
                break :blk 1; // Continuation/Invalid (نامعتبر، اما 1 بایت رد می‌شویم)
            } else if (byte < 0xE0) {
                break :blk 2; // 2 bytes
            } else if (byte < 0xF0) {
                break :blk 3; // 3 bytes
            } else {
                break :blk 4; // 4 bytes
            }
        };

        i += next_step;
        count += 1;
    }

    return count;
}

/// دریافت طول byte برای یک کاراکتر
pub fn charLen(first_byte: u8) u3 {
    if (first_byte < 0x80) return 1;
    if (first_byte < 0xE0) return 2;
    if (first_byte < 0xF0) return 3;
    return 4;
}

test "utf8 validate" {
    try std.testing.expect(validate("Hello, World!"));
    try std.testing.expect(validate("سلام دنیا"));
    try std.testing.expect(validate("こんにちは"));
}

test "utf8 char count" {
    try std.testing.expectEqual(@as(usize, 5), charCount("Hello"));
    try std.testing.expectEqual(@as(usize, 4), charCount("سلام"));
}
