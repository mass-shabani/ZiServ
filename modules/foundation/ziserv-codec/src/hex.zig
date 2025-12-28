// ============================================================
// فایل: modules/foundation/ziserv-codec/src/hex.zig
// Hex encoding/decoding - بهینه شده
// ============================================================

const std = @import("std");

/// Hex encoding table (lowercase)
const hex_chars_lower = "0123456789abcdef";
const hex_chars_upper = "0123456789ABCDEF";

/// Hex decoding table
const hex_decode_table = blk: {
    var table: [256]u8 = [_]u8{0xFF} ** 256;
    for (hex_chars_lower, 0..) |c, i| {
        table[c] = @intCast(i);
    }
    for (hex_chars_upper, 0..) |c, i| {
        table[c] = @intCast(i);
    }
    break :blk table;
};

/// محاسبه اندازه encoded
pub inline fn encodedLen(input_len: usize) usize {
    return input_len * 2;
}

/// محاسبه اندازه decoded
pub inline fn decodedLen(input_len: usize) usize {
    return input_len / 2;
}

/// Encode - lowercase
pub fn encodeLower(input: []const u8, output: []u8) !usize {
    if (output.len < encodedLen(input.len)) return error.BufferTooSmall;

    for (input, 0..) |byte, i| {
        output[i * 2] = hex_chars_lower[byte >> 4];
        output[i * 2 + 1] = hex_chars_lower[byte & 0x0F];
    }

    return input.len * 2;
}

/// Encode - uppercase
pub fn encodeUpper(input: []const u8, output: []u8) !usize {
    if (output.len < encodedLen(input.len)) return error.BufferTooSmall;

    for (input, 0..) |byte, i| {
        output[i * 2] = hex_chars_upper[byte >> 4];
        output[i * 2 + 1] = hex_chars_upper[byte & 0x0F];
    }

    return input.len * 2;
}

/// Decode
pub fn decode(input: []const u8, output: []u8) !usize {
    if (input.len % 2 != 0) return error.InvalidLength;
    if (output.len < decodedLen(input.len)) return error.BufferTooSmall;

    var i: usize = 0;
    while (i < input.len) : (i += 2) {
        const high = hex_decode_table[input[i]];
        const low = hex_decode_table[input[i + 1]];

        if (high == 0xFF or low == 0xFF) return error.InvalidCharacter;

        output[i / 2] = (high << 4) | low;
    }

    return input.len / 2;
}

/// Encode به allocator
pub fn encodeAlloc(input: []const u8, allocator: std.mem.Allocator, uppercase: bool) ![]u8 {
    const output = try allocator.alloc(u8, encodedLen(input.len));
    const len = if (uppercase)
        try encodeUpper(input, output)
    else
        try encodeLower(input, output);
    return output[0..len];
}

/// Decode به allocator
pub fn decodeAlloc(input: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const output = try allocator.alloc(u8, decodedLen(input.len));
    const len = try decode(input, output);
    return output[0..len];
}

test "hex encode" {
    const input = "Hello";
    var output: [100]u8 = undefined;

    const len = try encodeLower(input, &output);
    try std.testing.expectEqualStrings("48656c6c6f", output[0..len]);
}

test "hex decode" {
    const input = "48656c6c6f";
    var output: [100]u8 = undefined;

    const len = try decode(input, &output);
    try std.testing.expectEqualStrings("Hello", output[0..len]);
}
