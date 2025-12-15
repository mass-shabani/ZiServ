// examples/example-http/main.zig

const std = @import("std");
const http_server = @import("http-server");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const config = http_server.ServerConfig{
        .host = "127.0.0.1",
        .port = 8080,
        .max_connections = 10,
    };

    const server = try http_server.HttpServer.init(allocator, config);
    defer server.deinit();

    try server.start();
}
