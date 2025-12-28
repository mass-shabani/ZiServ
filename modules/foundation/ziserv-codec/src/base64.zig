// ============================================================
// فایل: modules/foundation/ziserv-codec/src/base64.zig
// Base64 encoding/decoding - بهینه شده
// ============================================================

const std = @import("std");

/// Base64 encoding tables (compile-time)
const encode_table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

/// Base64 decoding table (compile-time)
const decode_table = blk: {
    var table: [256]u8 = [_]u8{0xFF} ** 256;
    for (encode_table, 0..) |c, i| {
        table[c] = @intCast(i);
    }
    table['='] = 0;
    break :blk table;
};

/// محاسبه اندازه encoded (inline برای بهینه‌سازی)
pub inline fn encodedLen(input_len: usize) usize {
    return ((input_len + 2) / 3) * 4;
}

/// محاسبه اندازه decoded (inline)
pub inline fn decodedLen(input_len: usize) usize {
    return (input_len / 4) * 3;
}

/// Encode - بهینه شده با SIMD در نظر
pub fn encode(input: []const u8, output: []u8) !usize {
    if (output.len < encodedLen(input.len)) return error.BufferTooSmall;

    var i: usize = 0;
    var j: usize = 0;

    // پردازش 3 byte در هر iteration (بهینه برای CPU)
    while (i + 2 < input.len) : (i += 3) {
        const b0 = input[i];
        const b1 = input[i + 1];
        const b2 = input[i + 2];

        output[j] = encode_table[b0 >> 2];
        output[j + 1] = encode_table[((b0 & 0x03) << 4) | (b1 >> 4)];
        output[j + 2] = encode_table[((b1 & 0x0F) << 2) | (b2 >> 6)];
        output[j + 3] = encode_table[b2 & 0x3F];

        j += 4;
    }

    // باقیمانده
    const remaining = input.len - i;
    if (remaining == 1) {
        const b0 = input[i];
        output[j] = encode_table[b0 >> 2];
        output[j + 1] = encode_table[(b0 & 0x03) << 4];
        output[j + 2] = '=';
        output[j + 3] = '=';
        j += 4;
    } else if (remaining == 2) {
        const b0 = input[i];
        const b1 = input[i + 1];
        output[j] = encode_table[b0 >> 2];
        output[j + 1] = encode_table[((b0 & 0x03) << 4) | (b1 >> 4)];
        output[j + 2] = encode_table[(b1 & 0x0F) << 2];
        output[j + 3] = '=';
        j += 4;
    }

    return j;
}

/// Decode - بهینه شده
pub fn decode(input: []const u8, output: []u8) !usize {
    if (input.len % 4 != 0) return error.InvalidLength;
    if (output.len < decodedLen(input.len)) return error.BufferTooSmall;

    var i: usize = 0;
    var j: usize = 0;

    while (i < input.len) : (i += 4) {
        const c0 = decode_table[input[i]];
        const c1 = decode_table[input[i + 1]];
        const c2 = decode_table[input[i + 2]];
        const c3 = decode_table[input[i + 3]];

        if (c0 == 0xFF or c1 == 0xFF) return error.InvalidCharacter;

        output[j] = (c0 << 2) | (c1 >> 4);
        j += 1;

        if (input[i + 2] != '=') {
            if (c2 == 0xFF) return error.InvalidCharacter;
            output[j] = (c1 << 4) | (c2 >> 2);
            j += 1;

            if (input[i + 3] != '=') {
                if (c3 == 0xFF) return error.InvalidCharacter;
                output[j] = (c2 << 6) | c3;
                j += 1;
            }
        }
    }

    return j;
}

/// Encode به allocator
pub fn encodeAlloc(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const output = try allocator.alloc(u8, encodedLen(input.len));
    const len = try encode(input, output);
    return output[0..len];
}

/// Decode به allocator
pub fn decodeAlloc(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const output = try allocator.alloc(u8, decodedLen(input.len));
    const len = try decode(input, output);
    return output[0..len];
}

test "base64 encode" {
    const input = "Hello, World!";
    var output: [100]u8 = undefined;

    const len = try encode(input, &output);
    try std.testing.expectEqualStrings("SGVsbG8sIFdvcmxkIQ==", output[0..len]);
}

test "base64 decode" {
    const input = "SGVsbG8sIFdvcmxkIQ==";
    var output: [100]u8 = undefined;

    const len = try decode(input, &output);
    try std.testing.expectEqualStrings("Hello, World!", output[0..len]);
}
