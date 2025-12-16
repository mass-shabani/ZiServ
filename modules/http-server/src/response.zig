// modules/http-server/src/response.zig

const std = @import("std");

pub const Response = struct {
    status_code: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Response {
        return .{
            .status_code = 200,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = "",
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Response) void {
        self.headers.deinit();
    }

    pub fn send(self: *Response, stream: std.net.Stream) !void {
        var buf: [1024]u8 = undefined;
        var writer = stream.writer(&buf);
        const w = &writer.interface;

        try w.print("HTTP/1.1 {d} OK\r\n", .{self.status_code});
        try w.writeAll("Content-Type: text/plain\r\n");
        try w.print("Content-Length: {d}\r\n", .{self.body.len});
        try w.writeAll("\r\n");
        try w.writeAll(self.body);
        try w.flush();
    }
};

test "response creation" {
    var resp = Response.init(std.testing.allocator);
    defer resp.deinit();

    try std.testing.expectEqual(@as(u16, 200), resp.status_code);
}
