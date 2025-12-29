// ============================================================
// فایل: modules/foundation/ziserv-bytes/src/byte_buffer.zig
// ByteBuffer - بافر بافر استاندارد
// سازگار با Zig 0.15.1+ (Unmanaged ArrayList)
// ============================================================

const std = @import("std");

pub const ByteBuffer = struct {
    data: std.ArrayList(u8),
    allocator: std.mem.Allocator, // <--- اضافه شده: ذخیره آلیکیتور

    const Self = @This();

    /// ساخت جدید
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .data = std.ArrayList(u8){}, // <--- اصلاح شده: مقداردهی خالی
            .allocator = allocator,
        };
    }

    /// ساخت با ظرفیت اولیه
    pub fn initCapacity(allocator: std.mem.Allocator, capacity: usize) !Self {
        var lst = std.ArrayList(u8){};
        try lst.ensureTotalCapacity(allocator, capacity); // <--- اصلاح شده: آلیکیتور پاس شد
        return .{
            .data = lst,
            .allocator = allocator,
        };
    }

    /// آزادسازی
    pub fn deinit(self: *Self) void {
        self.data.deinit(self.allocator); // <--- اصلاح شده: آلیکیتور پاس شد
    }

    /// نوشتن داده
    pub fn write(self: *Self, data: []const u8) !void {
        try self.data.appendSlice(self.allocator, data); // <--- اصلاح شده: آلیکیتور پاس شد
    }

    /// پاک کردن بافر (با حفظ حافظه)
    pub fn clear(self: *Self) void {
        self.data.clearRetainingCapacity();
    }

    /// خواندن به slice
    pub fn slice(self: *Self) []u8 {
        return self.data.items;
    }

    /// برگرداندن اشاره‌گر به لیست برای کارهای پیشرفته
    pub fn list(self: *Self) *std.ArrayList(u8) {
        return &self.data;
    }
};
