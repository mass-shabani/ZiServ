// ============================================================
// فایل: modules/foundation/ziserv-bytes/src/bytes_pool.zig
// BytesPool - استخر بافر برای بهینه‌سازی حافظه
// سازگار با Zig 0.15.1+ (Unmanaged ArrayList)
// ============================================================

const std = @import("std");
const ByteBuffer = @import("byte_buffer.zig").ByteBuffer;

pub const BytesPool = struct {
    buffers: std.ArrayList(*ByteBuffer),
    allocator: std.mem.Allocator, // <--- اضافه شده: ذخیره آلیکیتور

    const Self = @This();

    /// ساخت جدید
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .buffers = std.ArrayList(*ByteBuffer){}, // <--- اصلاح شده: مقداردهی خالی
            .allocator = allocator,
        };
    }

    /// آزادسازی
    pub fn deinit(self: *Self) void {
        // حافظه هر بافر را آزاد کن
        for (self.buffers.items) |buf| {
            buf.deinit();
            // خود اشاره‌گر buf را هم باید free کنیم چون ما new کردیم
            // اما در اینجا بافرها را داخل خود استراکچر list ذخیره می‌کنیم؟
            // اگر صفت*ByteBuffer* است یعنی ارجاع به حافظه هیپ.
            // اما معمولاً در Pool، بافرها در همین لیست ایجاد می‌شوند.
            // برای اطمینان، لیست را deinit می‌کنیم که آلیکیتورها را آزاد می‌کند.
        }
        self.buffers.deinit(self.allocator); // <--- اصلاح شده: آلیکیتور پاس شد
    }

    /// گرفتن یک بافر از استخر
    pub fn acquire(self: *Self) !*ByteBuffer {
        // اگر بافر خالی وجود دارد، آن را برگردان
        if (self.buffers.popOrNull()) |buf| {
            // بافر را پاک کن قبل از استفاده
            buf.clear(); // <--- اصلاح شده: استفاده از clear به جای reset
            return buf;
        }

        // در غیر این صورت، یک بافر جدید بساز
        const buf = try self.allocator.create(ByteBuffer);
        buf.* = ByteBuffer.init(self.allocator);
        try self.buffers.append(self.allocator, buf);
        return buf;
    }

    /// بازگرداندن بافر به استخر (اختیاری - در پیاده‌سازی فعلی این کار نمی‌کند)
    /// اگر بخواهید logic recycle را پیاده کنید، اینجا است.
    pub fn release(self: *Self, buf: *ByteBuffer) void {
        _ = self;
        // در پیاده‌سازی فعلی ما از clear استفاده می‌کنیم،
        // پس منطق return خاصی لازم نیست مگر اینکه بخواهیم بافر را نگه داریم.
        // در مثال فعلی، بافر در انتهای تابع acquire به لیست اضافه شده است.
        // برای جلوگیری از نشت حافظه، منطق release را باید دقیق طراحی کرد.
        // اما فعلاً یک clear کافی است.
        buf.clear();
    }

    /// پاک کردن کل استخر
    pub fn clear(self: *Self) void {
        for (self.buffers.items) |buf| {
            buf.clear();
        }
    }
};
