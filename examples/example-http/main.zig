// examples/example-http/main.zig

const std = @import("std");
const http_server = @import("http-server");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // نمایش اطلاعات
    std.debug.print("=================================\n", .{});
    std.debug.print("ZiServ HTTP Server Example\n", .{});
    std.debug.print("=================================\n", .{});
    std.debug.print("Version: {s}\n", .{http_server.version});
    std.debug.print("\n", .{});

    // تنظیمات سرور
    const config = http_server.ServerConfig{
        .host = "127.0.0.1",
        .port = 8080,
        .max_connections = 100,
    };

    std.debug.print("Server Configuration:\n", .{});
    std.debug.print("  Host: {s}\n", .{config.host});
    std.debug.print("  Port: {d}\n", .{config.port});
    std.debug.print("  Max Connections: {d}\n", .{config.max_connections});
    std.debug.print("\n", .{});

    // ایجاد سرور
    const srv = try http_server.HttpServer.init(allocator, config);
    defer srv.deinit();

    std.debug.print("Starting HTTP server...\n", .{});
    std.debug.print("Server is listening on http://{s}:{d}\n", .{ config.host, config.port });
    std.debug.print("Press Ctrl+C to stop the server\n", .{});
    std.debug.print("\n", .{});

    // شروع سرور
    try srv.start();
}
