// ============================================================
// فایل: modules/foundation/ziserv-codec/src/varint.zig
// Variable-length integer encoding (LEB128) - بهینه شده
// ============================================================

const std = @import("std");

/// Encode u64 به varint (max 10 bytes)
pub fn encodeU64(value: u64, output: []u8) !usize {
    if (output.len < 10) return error.BufferTooSmall;

    var v = value;
    var i: usize = 0;

    while (v >= 0x80) {
        output[i] = @intCast((v & 0x7F) | 0x80);
        v >>= 7;
        i += 1;
    }
    output[i] = @intCast(v & 0x7F);
    i += 1;

    return i;
}

/// Decode varint به u64
pub fn decodeU64(input: []const u8) !struct { value: u64, len: usize } {
    var result: u64 = 0;
    var shift: u6 = 0;
    var i: usize = 0;

    while (i < input.len and i < 10) : (i += 1) {
        const byte = input[i];
        result |= @as(u64, byte & 0x7F) << shift;

        if (byte < 0x80) {
            return .{ .value = result, .len = i + 1 };
        }

        shift += 7;
        if (shift >= 64) return error.Overflow;
    }

    return error.Incomplete;
}

/// Encode i64 به signed varint (zigzag encoding)
pub fn encodeI64(value: i64, output: []u8) !usize {
    const unsigned = zigzagEncode(value);
    return encodeU64(unsigned, output);
}

/// Decode signed varint به i64
pub fn decodeI64(input: []const u8) !struct { value: i64, len: usize } {
    const result = try decodeU64(input);
    return .{
        .value = zigzagDecode(result.value),
        .len = result.len,
    };
}

/// ZigZag encoding (i64 -> u64)
inline fn zigzagEncode(value: i64) u64 {
    const shifted: u64 = @bitCast(value << 1);
    const sign: u64 = @bitCast(value >> 63);
    return shifted ^ sign;
}

/// ZigZag decoding (u64 -> i64)
inline fn zigzagDecode(value: u64) i64 {
    return @as(i64, @intCast(value >> 1)) ^ -@as(i64, @intCast(value & 1));
}

test "varint u64" {
    var buf: [10]u8 = undefined;

    const len = try encodeU64(300, &buf);
    try std.testing.expectEqual(@as(usize, 2), len);

    const result = try decodeU64(buf[0..len]);
    try std.testing.expectEqual(@as(u64, 300), result.value);
    try std.testing.expectEqual(@as(usize, 2), result.len);
}

test "varint i64" {
    var buf: [10]u8 = undefined;

    const len = try encodeI64(-300, &buf);
    const result = try decodeI64(buf[0..len]);
    try std.testing.expectEqual(@as(i64, -300), result.value);
}
