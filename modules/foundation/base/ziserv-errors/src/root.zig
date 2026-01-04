// ============================================================
// فایل: src/root.zig
// نقطه ورود اصلی ماژول ziserv-errors
// ============================================================

const std = @import("std");

// Re-exports
pub const Error = @import("errors.zig").Error;
pub const ErrorCategory = @import("errors.zig").ErrorCategory;
pub const ErrorSeverity = @import("errors.zig").ErrorSeverity;

pub const Context = @import("context.zig").Context;
pub const ErrorWithContext = @import("context.zig").ErrorWithContext;

pub const ErrorCode = @import("code.zig").ErrorCode;
pub const CommonCodes = @import("code.zig").CommonCodes;

pub const Result = @import("result.zig").Result;
pub const wrapResult = @import("result.zig").wrapResult;

pub const Option = @import("option.zig").Option;

// Combinators (helper functions)
pub const combinators = @import("combinators.zig");

// اطلاعات ماژول
pub const version = "0.1.0";
pub const name = "ziserv-errors";

// تست‌ها
test {
    std.testing.refAllDecls(@This());
}
