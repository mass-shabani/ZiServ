const std = @import("std");
const core = @import("core");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;

pub const ServerConfig = struct {
    host: []const u8,
    port: u16,
    max_connections: usize,
    read_timeout_ms: u32 = 5000,
    buffer_size: usize = 8192,
};

pub const HttpServer = struct {
    config: ServerConfig,
    allocator: std.mem.Allocator,
    running: bool,
    logger: core.logger.Logger,

    pub fn init(allocator: std.mem.Allocator, config: ServerConfig) !*HttpServer {
        const srv = try allocator.create(HttpServer);
        srv.* = .{
            .config = config,
            .allocator = allocator,
            .running = false,
            .logger = core.logger.Logger.init(allocator, .info),
        };
        return srv;
    }

    pub fn deinit(self: *HttpServer) void {
        self.allocator.destroy(self);
    }

    pub fn start(self: *HttpServer) !void {
        try self.logger.info("========================================", .{});
        try self.logger.info("Starting ZiServ HTTP Server", .{});
        try self.logger.info("Host: {s}", .{self.config.host});
        try self.logger.info("Port: {d}", .{self.config.port});
        try self.logger.info("Platform: {s}", .{core.platform.Os.name()});
        try self.logger.info("========================================", .{});

        const address = try std.net.Address.parseIp(self.config.host, self.config.port);
        var listener = try address.listen(.{
            .reuse_address = true,
            .force_nonblocking = false,
        });
        defer listener.deinit();

        try self.logger.info("Server is listening and ready to accept connections", .{});
        try self.logger.info("Press Ctrl+C to stop", .{});
        self.running = true;

        var connection_count: usize = 0;
        while (self.running) {
            const connection = listener.accept() catch |err| {
                try self.logger.err("Failed to accept connection: {}", .{err});
                continue;
            };

            connection_count += 1;
            try self.logger.info("Connection #{d} accepted from {any}", .{ connection_count, connection.address });

            self.handleConnection(connection, connection_count) catch |err| {
                try self.logger.err("Error handling connection #{d}: {}", .{ connection_count, err });
            };

            connection.stream.close();
            try self.logger.info("Connection #{d} closed", .{connection_count});
        }

        try self.logger.info("Server stopped", .{});
    }

    pub fn stop(self: *HttpServer) !void {
        try self.logger.info("Stopping HTTP server...", .{});
        self.running = false;
    }

    fn handleConnection(self: *HttpServer, connection: std.net.Server.Connection, conn_id: usize) !void {
        // تخصیص بافر دینامیک
        const buffer = try self.allocator.alloc(u8, self.config.buffer_size);
        defer self.allocator.free(buffer);

        // خواندن داده با مدیریت خطا
        const bytes_read = self.readFromStream(connection.stream, buffer) catch |err| {
            try self.logger.err("Connection #{d}: Failed to read: {}", .{ conn_id, err });
            return err;
        };

        if (bytes_read == 0) {
            try self.logger.warn("Connection #{d}: Client closed connection before sending data", .{conn_id});
            return;
        }

        try self.logger.info("Connection #{d}: Received {d} bytes", .{ conn_id, bytes_read });

        // پارس کردن درخواست
        const req = Request.parse(self.allocator, buffer[0..bytes_read]) catch |err| {
            try self.logger.err("Connection #{d}: Failed to parse request: {}", .{ conn_id, err });
            try self.sendErrorResponse(connection.stream, 400, "Bad Request");
            return;
        };
        defer req.deinit();

        try self.logger.info("Connection #{d}: {s} {s} {s}", .{ conn_id, req.method, req.path, req.version });

        // ساخت و ارسال پاسخ
        var resp = Response.init(self.allocator);
        defer resp.deinit();

        resp.status_code = 200;
        resp.body = "Hello from ZiServ HTTP Server!";
        try resp.headers.put("Server", "ZiServ/0.1.0");
        try resp.headers.put("Connection", "close");

        resp.send(connection.stream) catch |err| {
            try self.logger.err("Connection #{d}: Failed to send response: {}", .{ conn_id, err });
            return err;
        };

        try self.logger.info("Connection #{d}: Response sent successfully (200 OK)", .{conn_id});
    }

    fn readFromStream(self: *HttpServer, stream: std.net.Stream, buffer: []u8) !usize {
        // در Windows باید از recv استفاده کنیم نه read مستقیم
        if (core.platform.Os.current() == .windows) {
            const socket = stream.handle;
            const result = std.os.windows.ws2_32.recv(
                socket,
                buffer.ptr,
                @intCast(buffer.len),
                0,
            );

            if (result == std.os.windows.ws2_32.SOCKET_ERROR) {
                const err = std.os.windows.ws2_32.WSAGetLastError();
                try self.logger.err("Windows socket error: {d}", .{err});
                return error.WindowsSocketError;
            }

            return @intCast(result);
        } else {
            // Linux/POSIX
            return try stream.read(buffer);
        }
    }

    fn sendErrorResponse(self: *HttpServer, stream: std.net.Stream, status_code: u16, message: []const u8) !void {
        var resp = Response.init(self.allocator);
        defer resp.deinit();

        resp.status_code = status_code;
        resp.body = message;
        try resp.headers.put("Content-Type", "text/plain");
        try resp.headers.put("Connection", "close");

        _ = resp.send(stream) catch {};
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
