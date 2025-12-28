// ============================================================
// فایل: modules/foundation/ziserv-codec/src/frame.zig
// Frame encoding - برای پروتکل‌ها
// ============================================================

const std = @import("std");
const bytes = @import("ziserv-bytes");

/// Frame format: [length: u32][data: bytes]
pub const LengthPrefixedFrame = struct {
    const Self = @This();

    /// Encode frame
    pub fn encode(data: []const u8, output: *bytes.BytesMut) !void {
        const len: u32 = @intCast(data.len);

        // نوشتن length (big-endian)
        var len_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &len_bytes, len, .big);

        try output.write(&len_bytes);
        try output.write(data);
    }

    /// Decode frame (returns null if incomplete)
    pub fn decode(input: []const u8) !?struct { data: []const u8, consumed: usize } {
        if (input.len < 4) return null;

        const len = std.mem.readInt(u32, input[0..4], .big);

        if (input.len < 4 + len) return null;

        return .{
            .data = input[4 .. 4 + len],
            .consumed = 4 + len,
        };
    }
};

test "frame codec" {
    var output = bytes.BytesMut.init(std.testing.allocator);
    defer output.deinit();

    try LengthPrefixedFrame.encode("Hello", &output);

    const result = try LengthPrefixedFrame.decode(output.readBytes());
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("Hello", result.?.data);
    try std.testing.expectEqual(@as(usize, 9), result.?.consumed);
}
