// ============================================================
// فایل: modules/foundation/ziserv-util/src/random.zig
// Random utilities - UUID, token generation
// ============================================================

const std = @import("std");

/// UUID v4 generator
pub const Uuid = struct {
    bytes: [16]u8,

    pub fn v4(rng: std.Random) Uuid {
        var uuid: Uuid = undefined;
        rng.bytes(&uuid.bytes);

        // Set version (4) and variant (RFC 4122)
        uuid.bytes[6] = (uuid.bytes[6] & 0x0F) | 0x40;
        uuid.bytes[8] = (uuid.bytes[8] & 0x3F) | 0x80;

        return uuid;
    }

    pub fn toString(self: Uuid, buffer: []u8) ![]u8 {
        if (buffer.len < 36) return error.BufferTooSmall;

        const hex = "0123456789abcdef";
        var pos: usize = 0;

        for (self.bytes, 0..) |byte, i| {
            if (i == 4 or i == 6 or i == 8 or i == 10) {
                buffer[pos] = '-';
                pos += 1;
            }
            buffer[pos] = hex[byte >> 4];
            buffer[pos + 1] = hex[byte & 0x0F];
            pos += 2;
        }

        return buffer[0..36];
    }

    pub fn toStringAlloc(self: Uuid, allocator: std.mem.Allocator) ![]u8 {
        const buffer = try allocator.alloc(u8, 36);
        _ = try self.toString(buffer);
        return buffer;
    }
};

/// Random token generator
pub fn generateToken(rng: std.Random, buffer: []u8) void {
    rng.bytes(buffer);
}

/// Random hex string
pub fn generateHexToken(rng: std.Random, allocator: std.mem.Allocator, length: usize) ![]u8 {
    const bytes = try allocator.alloc(u8, length / 2);
    defer allocator.free(bytes);

    rng.bytes(bytes);

    const hex = "0123456789abcdef";
    const result = try allocator.alloc(u8, length);

    for (bytes, 0..) |byte, i| {
        result[i * 2] = hex[byte >> 4];
        result[i * 2 + 1] = hex[byte & 0x0F];
    }

    return result;
}

/// Random alphanumeric string
pub fn generateAlphanumeric(rng: std.Random, allocator: std.mem.Allocator, length: usize) ![]u8 {
    const charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    const result = try allocator.alloc(u8, length);

    for (result) |*c| {
        c.* = charset[rng.intRangeLessThan(usize, 0, charset.len)];
    }

    return result;
}

/// Password generator
pub fn generatePassword(rng: std.Random, allocator: std.mem.Allocator, length: usize, options: PasswordOptions) ![]u8 {
    var charset = std.ArrayList(u8).init(allocator);
    defer charset.deinit();

    if (options.lowercase) try charset.appendSlice("abcdefghijklmnopqrstuvwxyz");
    if (options.uppercase) try charset.appendSlice("ABCDEFGHIJKLMNOPQRSTUVWXYZ");
    if (options.numbers) try charset.appendSlice("0123456789");
    if (options.symbols) try charset.appendSlice("!@#$%^&*()_+-=[]{}|;:,.<>?");

    if (charset.items.len == 0) return error.NoCharset;

    const result = try allocator.alloc(u8, length);
    for (result) |*c| {
        c.* = charset.items[rng.intRangeLessThan(usize, 0, charset.items.len)];
    }

    return result;
}

pub const PasswordOptions = struct {
    lowercase: bool = true,
    uppercase: bool = true,
    numbers: bool = true,
    symbols: bool = false,
};

/// Shuffle slice
pub fn shuffle(comptime T: type, rng: std.Random, slice: []T) void {
    if (slice.len < 2) return;

    var i = slice.len - 1;
    while (i > 0) : (i -= 1) {
        const j = rng.intRangeLessThan(usize, 0, i + 1);
        const tmp = slice[i];
        slice[i] = slice[j];
        slice[j] = tmp;
    }
}

/// Random choice
pub fn choice(comptime T: type, rng: std.Random, slice: []const T) T {
    const index = rng.intRangeLessThan(usize, 0, slice.len);
    return slice[index];
}

/// Random sample (without replacement)
pub fn sample(comptime T: type, rng: std.Random, allocator: std.mem.Allocator, slice: []const T, count: usize) ![]T {
    if (count > slice.len) return error.SampleTooLarge;

    const indices = try allocator.alloc(usize, slice.len);
    defer allocator.free(indices);

    for (indices, 0..) |*idx, i| {
        idx.* = i;
    }

    shuffle(usize, rng, indices);

    const result = try allocator.alloc(T, count);
    for (result, 0..) |*item, i| {
        item.* = slice[indices[i]];
    }

    return result;
}

/// Weighted random choice
pub fn weightedChoice(comptime T: type, rng: std.Random, items: []const T, weights: []const f64) !T {
    if (items.len != weights.len) return error.LengthMismatch;
    if (items.len == 0) return error.EmptyInput;

    var total: f64 = 0;
    for (weights) |w| {
        total += w;
    }

    const r = rng.float(f64) * total;
    var cumulative: f64 = 0;

    for (items, weights) |item, weight| {
        cumulative += weight;
        if (r <= cumulative) return item;
    }

    return items[items.len - 1];
}

test "uuid generation" {
    var prng = std.Random.DefaultPrng.init(0);
    const rng = prng.random();

    const uuid = Uuid.v4(rng);
    var buffer: [36]u8 = undefined;
    const str = try uuid.toString(&buffer);

    try std.testing.expectEqual(@as(usize, 36), str.len);
    try std.testing.expectEqual(@as(u8, '-'), str[8]);
    try std.testing.expectEqual(@as(u8, '-'), str[13]);
}

test "token generation" {
    var prng = std.Random.DefaultPrng.init(0);
    const rng = prng.random();

    const token = try generateHexToken(rng, std.testing.allocator, 32);
    defer std.testing.allocator.free(token);

    try std.testing.expectEqual(@as(usize, 32), token.len);
}

test "password generation" {
    var prng = std.Random.DefaultPrng.init(0);
    const rng = prng.random();

    const password = try generatePassword(rng, std.testing.allocator, 16, .{
        .symbols = true,
    });
    defer std.testing.allocator.free(password);

    try std.testing.expectEqual(@as(usize, 16), password.len);
}

test "shuffle" {
    var prng = std.Random.DefaultPrng.init(0);
    const rng = prng.random();

    var items = [_]i32{ 1, 2, 3, 4, 5 };
    shuffle(i32, rng, &items);

    // Just check it doesn't crash
    try std.testing.expect(items.len == 5);
}

test "weighted choice" {
    var prng = std.Random.DefaultPrng.init(0);
    const rng = prng.random();

    const items = [_][]const u8{ "rare", "common", "uncommon" };
    const weights = [_]f64{ 0.1, 0.7, 0.2 };

    const choice_result = try weightedChoice([]const u8, rng, &items, &weights);
    try std.testing.expect(choice_result.len > 0);
}
