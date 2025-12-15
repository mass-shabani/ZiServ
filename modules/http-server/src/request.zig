// modules/http-server/src/request.zig

const std = @import("std");

pub const Request = struct {
    method: []const u8,
    path: []const u8,
    version: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn parse(allocator: std.mem.Allocator, data: []const u8) !*Request {
        const req = try allocator.create(Request);
        req.* = .{
            .method = "",
            .path = "",
            .version = "",
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = "",
            .allocator = allocator,
        };

        var lines = std.mem.splitScalar(u8, data, '\n');

        if (lines.next()) |first_line| {
            var parts = std.mem.splitScalar(u8, first_line, ' ');
            if (parts.next()) |method| req.method = method;
            if (parts.next()) |path| req.path = path;
            if (parts.next()) |version| req.version = version;
        }

        return req;
    }

    pub fn deinit(self: *Request) void {
        self.headers.deinit();
        self.allocator.destroy(self);
    }
};

test "request parsing" {
    const data = "GET / HTTP/1.1\r\n";
    const req = try Request.parse(std.testing.allocator, data);
    defer req.deinit();

    try std.testing.expect(std.mem.startsWith(u8, req.method, "GET"));
}
