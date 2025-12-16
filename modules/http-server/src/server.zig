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
        const logger = core.logger.Logger.init(self.allocator, .info);
        try logger.info("New connection accepted", .{});

        var buffer: [4096]u8 = undefined;
        const bytes_read = connection.stream.read(&buffer) catch |err| {
            try logger.err("Failed to read from connection: {}", .{err});
            return;
        };
        try logger.info("Read {d} bytes from connection", .{bytes_read});

        if (bytes_read == 0) {
            try logger.info("Connection closed by client", .{});
            return;
        }

        const req = Request.parse(self.allocator, buffer[0..bytes_read]) catch |err| {
            try logger.err("Failed to parse request: {}", .{err});
            return;
        };
        defer req.deinit();
        try logger.info("Parsed request: {s} {s}", .{ req.method, req.path });

        var resp = Response.init(self.allocator);
        defer resp.deinit();

        resp.status_code = 200;
        resp.body = "Hello from ZiServ HTTP Server!";

        resp.send(connection.stream) catch |err| {
            try logger.err("Failed to send response: {}", .{err});
            return;
        };
        try logger.info("Response sent", .{});
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
