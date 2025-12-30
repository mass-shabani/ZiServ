// ============================================================
// فایل: modules/foundation/ziserv-util/src/root.zig
// ماژول اصلی ziserv-util
// ============================================================

const std = @import("std");
const core = @import("ziserv-core");

/// زیرماژول‌ها
pub const string = @import("string.zig");
pub const path = @import("path.zig");
pub const collections = @import("collections.zig");
pub const math = @import("math.zig");
pub const random = @import("random.zig");

/// Type aliases برای راحتی
pub const StringBuilder = string.StringBuilder;
pub const SplitIterator = string.SplitIterator;

pub const HashMap = collections.HashMap;
pub const ArrayList = collections.ArrayList;
pub const HashSet = collections.HashSet;
pub const RingBuffer = collections.RingBuffer;
pub const PriorityQueue = collections.PriorityQueue;

pub const Uuid = random.Uuid;
pub const PasswordOptions = random.PasswordOptions;

/// اطلاعات ماژول
pub const version = "0.1.0";
pub const name = "ziserv-util";
pub const description = "Utility library for ZiServ framework";

// تست‌ها
test {
    std.testing.refAllDecls(@This());
}
