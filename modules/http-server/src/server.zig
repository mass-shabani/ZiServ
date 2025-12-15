// modules/http-server/src/server.zig

const std = @import("std");
const core = @import("core");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;

pub const ServerConfig = struct {
    host: []const u8,
    port: u16,
    max_connections: usize,
};

pub const HttpServer = struct {
    config: ServerConfig,
    allocator: std.mem.Allocator,
    running: bool,

    pub fn init(allocator: std.mem.Allocator, config: ServerConfig) !*HttpServer {
        const srv = try allocator.create(HttpServer);
        srv.* = .{
            .config = config,
            .allocator = allocator,
            .running = false,
        };
        return srv;
    }

    pub fn deinit(self: *HttpServer) void {
        self.allocator.destroy(self);
    }

    pub fn start(self: *HttpServer) !void {
        const logger = core.logger.Logger.init(self.allocator, .info);
        try logger.info("Starting HTTP server on {s}:{d}", .{ self.config.host, self.config.port });

        const address = try std.net.Address.parseIp(self.config.host, self.config.port);
        var listener = try address.listen(.{
            .reuse_address = true,
        });
        defer listener.deinit();

        try logger.info("Server listening...", .{});
        self.running = true;

        while (self.running) {
            const connection = try listener.accept();
            defer connection.stream.close();

            try self.handleConnection(connection);
        }
    }

    pub fn stop(self: *HttpServer) !void {
        const logger = core.logger.Logger.init(self.allocator, .info);
        try logger.info("Stopping HTTP server", .{});
        self.running = false;
    }

    fn handleConnection(self: *HttpServer, connection: std.net.Server.Connection) !void {
        var buffer: [4096]u8 = undefined;
        const bytes_read = try connection.stream.read(&buffer);

        if (bytes_read == 0) return;

        const req = try Request.parse(self.allocator, buffer[0..bytes_read]);
        defer req.deinit();

        var resp = Response.init(self.allocator);
        defer resp.deinit();

        resp.status_code = 200;
        resp.body = "Hello from ZiServ HTTP Server!";

        try resp.send(connection.stream);
    }
};

test "server creation" {
    const config = ServerConfig{
        .host = "127.0.0.1",
        .port = 8080,
        .max_connections = 10,
    };

    const srv = try HttpServer.init(std.testing.allocator, config);
    defer srv.deinit();

    try std.testing.expectEqual(@as(u16, 8080), srv.config.port);
}

test "server start and stop" {
    const config = ServerConfig{
        .host = "127.0.0.1",
        .port = 8080,
        .max_connections = 10,
    };

    const srv = try HttpServer.init(std.testing.allocator, config);
    defer srv.deinit();

    try srv.start();
    try srv.stop();
}
