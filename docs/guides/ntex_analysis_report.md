# گزارش تحلیل ساختار پروژه ntex
## تحلیل معماری برای الگوگیری در فریم‌ورک ZiServ

---

## 🎯 خلاصه اجرایی

پروژه **ntex** یک فریم‌ورک Rust برای ساخت سرویس‌های شبکه‌ای composable است که توسط Nikolay Kim توسعه یافته و بیش از 2400 ستاره در GitHub دارد. این پروژه یک الگوی عالی برای ساختار ماژولار و قابل توسعه ارائه می‌دهد.

---

## 📦 معماری کلی پروژه

### 1. ساختار Mono-Repo با Workspace

ntex از یک repository واحد با ساختار workspace استفاده می‌کند که شامل چندین crate مستقل است:

```
ntex/
├── Cargo.toml              # Workspace root
├── ntex/                   # Main crate
├── ntex-bytes/             # Byte utilities
├── ntex-codec/             # Codec implementations
├── ntex-http/              # HTTP protocol
├── ntex-io/                # I/O abstractions
├── ntex-net/               # Network utilities
├── ntex-router/            # URL routing
├── ntex-server/            # Server implementation
├── ntex-service/           # Service trait
├── ntex-tls/               # TLS support
└── ntex-util/              # Utilities
```

### مزایای این ساختار:
✅ **تفکیک مسئولیت**: هر crate یک مسئولیت مشخص دارد
✅ **قابلیت استفاده مجدد**: هر crate مستقل قابل استفاده است
✅ **مدیریت آسان**: همه در یک repository
✅ **وابستگی‌های مشخص**: هر crate وابستگی‌های خود را مدیریت می‌کند

---

## 🏗️ ساختار هر Crate

### الگوی استاندارد:

```
ntex-[module]/
├── Cargo.toml          # تنظیمات crate
├── src/
│   ├── lib.rs         # نقطه ورود (برای library)
│   ├── [modules].rs   # ماژول‌های اصلی
│   └── ...
├── tests/             # تست‌های یکپارچگی
└── benches/           # بنچمارک‌ها
```

---

## 🔑 اصول کلیدی معماری ntex

### 1. **Service-Oriented Architecture**

ntex بر اساس trait `Service` ساخته شده که یک abstraction برای عملیات async است:

```rust
pub trait Service {
    type Request;
    type Response;
    type Error;
    type Future: Future<Output = Result<Self::Response, Self::Error>>;
    
    fn call(&self, req: Self::Request) -> Self::Future;
}
```

**درس برای ZiServ**: استفاده از trait‌های مشترک برای abstraction

### 2. **Composability (ترکیب‌پذیری)**

هر سرویس می‌تواند با سرویس‌های دیگر ترکیب شود (middleware pattern).

**کاربرد در ZiServ**: 
- ماژول‌های قابل ترکیب (مثلاً http-server + logging + metrics)
- middleware برای request/response processing

### 3. **Multiple Runtime Support**

ntex از چندین async runtime پشتیبانی می‌کند: tokio, compio, neon

**الگو برای ZiServ**:
```zig
// در ZiServ می‌توانیم پلتفرم‌های مختلف را پشتیبانی کنیم
pub const Runtime = enum {
    native,
    libuv,
    iocp,  // Windows
    epoll, // Linux
};
```

### 4. **Feature Flags برای انتخاب قابلیت‌ها**

```toml
[dependencies]
ntex = { version = "2", features = ["tokio", "http"] }
```

**در ZiServ**:
```zon
.dependencies = .{
    .ziserv_http = .{ 
        .path = "...",
        .features = .{ "tls", "compression" }
    },
}
```

---

## 📊 سازماندهی Crate‌ها در ntex

### Crate‌های Foundation (پایه):

| Crate | مسئولیت | وابستگی |
|-------|---------|----------|
| `ntex-service` | Service trait | هیچ |
| `ntex-util` | Utilities | minimal |
| `ntex-bytes` | Byte handling | هیچ |
| `ntex-codec` | Encoding/Decoding | ntex-bytes |

### Crate‌های Protocol:

| Crate | مسئولیت | وابستگی |
|-------|---------|----------|
| `ntex-http` | HTTP protocol | ntex-bytes, ntex-codec |
| `ntex-io` | I/O abstractions | ntex-service |
| `ntex-net` | Network utils | ntex-io |

### Crate‌های High-Level:

| Crate | مسئولیت | وابستگی |
|-------|---------|----------|
| `ntex-server` | Server impl | ntex-net, ntex-service |
| `ntex-router` | URL routing | minimal |
| `ntex` | Main crate | همه موارد بالا |

---

## 🎨 مقایسه با ساختار فعلی ZiServ

### ساختار فعلی ZiServ:
```
ziserv/
└── modules/
    ├── core/           # ✅ مشابه ntex-util
    ├── os-service/     # ✅ ماژول تخصصی
    └── http-server/    # ✅ ماژول تخصصی
```

### پیشنهادات بهبود بر اساس ntex:

#### 1. **تفکیک بیشتر core**

```
ziserv/
└── modules/
    ├── core/              # اصول پایه
    ├── service/           # Service trait (مثل ntex-service)
    ├── io/                # I/O abstractions
    ├── net/               # Network utilities
    ├── os-service/
    └── http-server/
```

#### 2. **اضافه کردن لایه‌های abstraction**

```zig
// modules/service/src/root.zig
pub const Service = struct {
    vtable: *const VTable,
    context: *anyopaque,
    
    pub const VTable = struct {
        call: *const fn(*anyopaque, Request) Error!Response,
        deinit: *const fn(*anyopaque) void,
    };
};
```

#### 3. **ساختار بهتر برای Protocol‌ها**

```
modules/
├── protocols/
│   ├── http/
│   │   ├── http1/
│   │   ├── http2/
│   │   └── http3/
│   ├── ws/        # WebSocket
│   └── mqtt/      # MQTT (آینده)
```

---

## 💡 درس‌های کلیدی از ntex

### 1. **تفکیک Concerns**
- هر crate یک مسئولیت مشخص
- وابستگی‌های کم و مشخص
- API‌های تمیز و documented

### 2. **Extensibility (قابلیت توسعه)**
- استفاده از trait‌ها برای abstraction
- پشتیبانی از plugin pattern
- Feature flags برای انتخاب قابلیت‌ها

### 3. **Testing Strategy**
```
ntex-[module]/
├── src/
│   └── lib.rs
├── tests/           # Integration tests
│   ├── test_basic.rs
│   └── test_advanced.rs
└── benches/         # Performance tests
    └── bench_server.rs
```

### 4. **Documentation**
- مستندات کامل برای هر crate
- مثال‌های کاربردی
- Architecture decision records (ADR)

---

## 🔄 پروژه‌های مرتبط در اکوسیستم ntex

ntex یک اکوسیستم کامل دارد:

| پروژه | توضیحات |
|-------|----------|
| `ntex-mqtt` | MQTT Client/Server (353 ستاره) |
| `ntex-amqp` | AMQP 1.0 Server (67 ستاره) |
| `ntex-grpc` | gRPC support (40 ستاره) |
| `ntex-redis` | Redis client |
| `ntex-h2` | HTTP/2 implementation |
| `examples` | مثال‌های کاربردی (92 ستاره) |

**درس**: ساخت اکوسیستم به جای یک ماژول monolithic

---

## 📋 چک‌لیست پیاده‌سازی برای ZiServ

### مرحله 1: بازسازی ساختار (Refactoring)
- [ ] تفکیک `core` به ماژول‌های کوچک‌تر
- [ ] ایجاد لایه `service` abstraction
- [ ] جداسازی `io` و `net` از core
- [ ] ایجاد ساختار workspace

### مرحله 2: بهبود معماری
- [ ] پیاده‌سازی Service trait
- [ ] اضافه کردن middleware support
- [ ] Feature flags برای قابلیت‌های اختیاری
- [ ] Plugin system

### مرحله 3: مستندات و تست
- [ ] مستندات کامل برای هر ماژول
- [ ] Integration tests
- [ ] Performance benchmarks
- [ ] مثال‌های کاربردی

### مرحله 4: اکوسیستم
- [ ] جدا کردن ماژول‌ها به repository‌های جداگانه (اختیاری)
- [ ] ایجاد پروژه‌های companion (مثل ntex-mqtt)
- [ ] Community engagement

---

## 🎯 پیشنهادات فوری برای ZiServ

### 1. **ساختار پیشنهادی جدید:**

```
ziserv/
├── Cargo.toml (برای docs)
├── modules/
│   ├── ziserv-core/           # Platform abstractions
│   ├── ziserv-service/        # Service trait
│   ├── ziserv-io/             # I/O abstractions
│   ├── ziserv-net/            # Network utilities
│   ├── ziserv-http/           # HTTP protocol
│   ├── ziserv-server/         # HTTP server
│   ├── ziserv-os-service/     # OS service management
│   └── ziserv/                # Main crate (re-exports)
├── examples/
│   ├── hello-world/
│   ├── middleware/
│   ├── database/
│   └── production/
└── docs/

```

### 2. **ایجاد Main Crate**

```zig
// modules/ziserv/src/root.zig
pub const core = @import("ziserv_core");
pub const service = @import("ziserv_service");
pub const http = @import("ziserv_http");
pub const server = @import("ziserv_server");

// Re-export commonly used items
pub const HttpServer = server.HttpServer;
pub const Service = service.Service;
```

### 3. **API Design بهتر**

```zig
// Simple API برای شروع سریع
const ziserv = @import("ziserv");

pub fn main() !void {
    var server = try ziserv.HttpServer.init(.{
        .host = "0.0.0.0",
        .port = 8080,
    });
    
    try server.route("GET", "/", handleIndex);
    try server.run();
}
```

---

## 📈 نتیجه‌گیری

### نقاط قوت ntex که باید در ZiServ پیاده شود:

1. ✅ **ساختار ماژولار**: تفکیک واضح مسئولیت‌ها
2. ✅ **Composability**: قابلیت ترکیب ماژول‌ها
3. ✅ **Abstraction layers**: لایه‌های مختلف از low-level تا high-level
4. ✅ **Testing infrastructure**: تست‌های جامع
5. ✅ **Documentation**: مستندات عالی
6. ✅ **Ecosystem**: پروژه‌های companion

### مسیر پیشنهادی:

**فاز 1 (فعلی)**: ✅ ساختار اولیه ماژولار
**فاز 2 (بعدی)**: 🔄 بازسازی با لایه‌های abstraction
**فاز 3 (آینده)**: 🎯 اکوسیستم کامل

---

## 🔗 منابع مفید

- [ntex GitHub](https://github.com/ntex-rs/ntex)
- [ntex Documentation](https://docs.rs/ntex)
- [ntex Examples](https://github.com/ntex-rs/examples)
- [Rust Module System](https://doc.rust-lang.org/book/ch07-00-managing-growing-projects-with-packages-crates-and-modules.html)

---

*این گزارش برای بهبود معماری فریم‌ورک ZiServ تهیه شده است.*
*تاریخ: دسامبر 2025*