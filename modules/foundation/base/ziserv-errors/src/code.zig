// ============================================================
// فایل: src/code.zig
// Error Codes - کدهای استاندارد خطا
// ============================================================

const std = @import("std");

/// Error Code - کد عددی برای خطا
pub const ErrorCode = struct {
    code: u32,
    name: []const u8,
    description: []const u8,

    pub fn init(code: u32, name: []const u8, description: []const u8) ErrorCode {
        return .{
            .code = code,
            .name = name,
            .description = description,
        };
    }

    pub fn format(
        self: ErrorCode,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("[{d}] {s}: {s}", .{ self.code, self.name, self.description });
    }
};

/// کدهای خطای رایج (HTTP-inspired)
pub const CommonCodes = struct {
    // 1xx: Informational
    pub const CONTINUE = ErrorCode.init(100, "Continue", "Continue operation");
    pub const PROCESSING = ErrorCode.init(102, "Processing", "Request is being processed");

    // 2xx: Success (برای completeness - معمولاً استفاده نمی‌شود)
    pub const OK = ErrorCode.init(200, "OK", "Operation successful");
    pub const CREATED = ErrorCode.init(201, "Created", "Resource created");

    // 4xx: Client Errors
    pub const BAD_REQUEST = ErrorCode.init(400, "BadRequest", "Invalid request");
    pub const UNAUTHORIZED = ErrorCode.init(401, "Unauthorized", "Authentication required");
    pub const FORBIDDEN = ErrorCode.init(403, "Forbidden", "Access denied");
    pub const NOT_FOUND = ErrorCode.init(404, "NotFound", "Resource not found");
    pub const METHOD_NOT_ALLOWED = ErrorCode.init(405, "MethodNotAllowed", "Method not allowed");
    pub const TIMEOUT = ErrorCode.init(408, "Timeout", "Request timeout");
    pub const CONFLICT = ErrorCode.init(409, "Conflict", "Resource conflict");
    pub const PAYLOAD_TOO_LARGE = ErrorCode.init(413, "PayloadTooLarge", "Request too large");
    pub const UNPROCESSABLE = ErrorCode.init(422, "Unprocessable", "Cannot process entity");
    pub const TOO_MANY_REQUESTS = ErrorCode.init(429, "TooManyRequests", "Rate limit exceeded");

    // 5xx: Server Errors
    pub const INTERNAL_ERROR = ErrorCode.init(500, "InternalError", "Internal server error");
    pub const NOT_IMPLEMENTED = ErrorCode.init(501, "NotImplemented", "Not implemented");
    pub const BAD_GATEWAY = ErrorCode.init(502, "BadGateway", "Bad gateway");
    pub const SERVICE_UNAVAILABLE = ErrorCode.init(503, "ServiceUnavailable", "Service unavailable");
    pub const GATEWAY_TIMEOUT = ErrorCode.init(504, "GatewayTimeout", "Gateway timeout");

    // Custom ZiServ codes (6xx)
    pub const PARSE_ERROR = ErrorCode.init(600, "ParseError", "Parse error");
    pub const VALIDATION_ERROR = ErrorCode.init(601, "ValidationError", "Validation failed");
    pub const ENCODING_ERROR = ErrorCode.init(602, "EncodingError", "Encoding error");
    pub const MEMORY_ERROR = ErrorCode.init(603, "MemoryError", "Memory allocation failed");
    pub const IO_ERROR = ErrorCode.init(604, "IoError", "I/O operation failed");
    pub const NETWORK_ERROR = ErrorCode.init(605, "NetworkError", "Network error");
    pub const PLATFORM_ERROR = ErrorCode.init(606, "PlatformError", "Platform-specific error");
    pub const SECURITY_ERROR = ErrorCode.init(607, "SecurityError", "Security violation");

    /// دریافت کد از عدد
    pub fn fromCode(code: u32) ?ErrorCode {
        return switch (code) {
            100 => CONTINUE,
            102 => PROCESSING,
            200 => OK,
            201 => CREATED,
            400 => BAD_REQUEST,
            401 => UNAUTHORIZED,
            403 => FORBIDDEN,
            404 => NOT_FOUND,
            405 => METHOD_NOT_ALLOWED,
            408 => TIMEOUT,
            409 => CONFLICT,
            413 => PAYLOAD_TOO_LARGE,
            422 => UNPROCESSABLE,
            429 => TOO_MANY_REQUESTS,
            500 => INTERNAL_ERROR,
            501 => NOT_IMPLEMENTED,
            502 => BAD_GATEWAY,
            503 => SERVICE_UNAVAILABLE,
            504 => GATEWAY_TIMEOUT,
            600 => PARSE_ERROR,
            601 => VALIDATION_ERROR,
            602 => ENCODING_ERROR,
            603 => MEMORY_ERROR,
            604 => IO_ERROR,
            605 => NETWORK_ERROR,
            606 => PLATFORM_ERROR,
            607 => SECURITY_ERROR,
            else => null,
        };
    }

    /// آیا کد موفقیت است؟ (2xx)
    pub fn isSuccess(code: u32) bool {
        return code >= 200 and code < 300;
    }

    /// آیا کد client error است؟ (4xx)
    pub fn isClientError(code: u32) bool {
        return code >= 400 and code < 500;
    }

    /// آیا کد server error است؟ (5xx یا 6xx)
    pub fn isServerError(code: u32) bool {
        return code >= 500 and code < 700;
    }
};

// تست‌ها
test "ErrorCode: basic" {
    const code = ErrorCode.init(404, "NotFound", "Resource not found");

    try std.testing.expectEqual(@as(u32, 404), code.code);
    try std.testing.expectEqualStrings("NotFound", code.name);
}

test "CommonCodes: fromCode" {
    const code = CommonCodes.fromCode(404);
    try std.testing.expect(code != null);
    try std.testing.expectEqual(@as(u32, 404), code.?.code);
}

test "CommonCodes: classification" {
    try std.testing.expect(CommonCodes.isSuccess(200));
    try std.testing.expect(CommonCodes.isClientError(404));
    try std.testing.expect(CommonCodes.isServerError(500));
    try std.testing.expect(CommonCodes.isServerError(600));
}

test "CommonCodes: formatting" {
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(std.testing.allocator);

    try CommonCodes.NOT_FOUND.format("", .{}, buffer.writer(std.testing.allocator));
    try std.testing.expect(buffer.items.len > 0);
}
