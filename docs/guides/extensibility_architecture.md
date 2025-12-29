# معماری Extensibility در ntex
## راهنمای جامع Abstractions و Plugin Patterns

---

## 📚 فهرست مطالب

1. [مفهوم Service Abstraction](#service-abstraction)
2. [Middleware Pattern](#middleware-pattern)
3. [Plugin System Architecture](#plugin-system)
4. [پیاده‌سازی در ZiServ](#ziserv-implementation)

---

## 🎯 1. Service Abstraction {#service-abstraction}

### مفهوم اصلی

Service trait در ntex یک تابع async از Request به Response است که تعاملات request/response را نمایش می‌دهد.

### ساختار Service Trait در Rust (ntex)

```rust
pub trait Service<Req> {
    type Response;
    type Error;
    
    // متد اصلی: پردازش درخواست
    async fn call(
        &self, 
        req: Req, 
        ctx: ServiceCtx<'_, Self>
    ) -> Result<Self::Response, Self::Error>;
    
    // متدهای اختیاری
    async fn ready(&self, ctx: ServiceCtx<'_, Self>) 
        -> Result<(), Self::Error> { ... }
    
    async fn shutdown(&self) { ... }
    
    // Transformation methods
    fn map<F, Res>(self, f: F) -> ServiceChain<Map<Self, F, Req, Res>>
    fn map_err<F, E>(self, f: F) -> ServiceChain<MapErr<Self, F, E>>
}
```

### ویژگی‌های کلیدی:

1. **Generic over Request Type**: می‌تواند انواع مختلف request را بپذیرد
2. **Immutable State** (`&self`): کارایی بالا
3. **Symmetric API**: هم برای client و هم server
4. **Composable**: قابل ترکیب با سرویس‌های دیگر

---

## 🔄 2. Middleware Pattern {#middleware-pattern}

### مفهوم Middleware

Middleware لایه‌ای است که بین درخواست و پاسخ قرار می‌گیرد و می‌تواند:
- درخواست را تغییر دهد (pre-processing)
- پاسخ را تغییر دهد (post-processing)
- کنترل جریان را مدیریت کند (مثل timeout)

### مثال واقعی: Timeout Middleware در ntex

```rust
use ntex_service::{Service, ServiceCtx};
use ntex_util::{time::sleep, future::Either, future::select};

// 1. تعریف Middleware Struct
pub struct Timeout<S> {
    service: S,                    // سرویس داخلی
    timeout: std::time::Duration,  // تنظیمات
}

// 2. تعریف Error Type
pub enum TimeoutError<E> {
    Service(E),    // خطای سرویس اصلی
    Timeout,       // خطای timeout
}

// 3. پیاده‌سازی Service Trait
impl<S, R> Service<R> for Timeout<S>
where
    S: Service<R>,
{
    type Response = S::Response;
    type Error = TimeoutError<S::Error>;

    async fn ready(&self, ctx: ServiceCtx<'_, Self>) 
        -> Result<(), Self::Error> 
    {
        ctx.ready(&self.service)
            .await
            .map_err(TimeoutError::Service)
    }

    async fn call(&self, req: R, ctx: ServiceCtx<'_, Self>) 
        -> Result<Self::Response, Self::Error> 
    {
        // اجرای race بین timeout و service call
        match select(
            sleep(self.timeout), 
            ctx.call(&self.service, req)
        ).await {
            Either::Left(_) => Err(TimeoutError::Timeout),
            Either::Right(res) => res.map_err(TimeoutError::Service),
        }
    }
}
```

### نکات کلیدی Middleware:

✅ **Wraps Inner Service**: سرویس داخلی را wrap می‌کند
✅ **Transparent**: نوع Response و Request حفظ می‌شود
✅ **Reusable**: برای هر سرویسی قابل استفاده
✅ **Chainable**: چند middleware قابل ترکیب

---

## 🔌 3. Plugin System Architecture {#plugin-system}

### ساختار Plugin در ntex

#### A. Middleware Registration

Middleware برای هر App، scope یا Resource ثبت می‌شود و به ترتیب معکوس اجرا می‌شود.

```rust
use ntex::web::{App, middleware};

let app = App::new()
    .wrap(middleware::Logger::default())      // اول اجرا می‌شود
    .wrap(middleware::Compress::default())    // دوم اجرا می‌شود
    .wrap(CustomAuth::new())                  // سوم اجرا می‌شود
    .route("/api", web::get().to(handler));
```

**جریان اجرا:**
```
Request → CustomAuth → Compress → Logger → Handler → Logger → Compress → CustomAuth → Response
```

#### B. Service Factory Pattern

```rust
pub trait ServiceFactory<Req, Cfg = ()> {
    type Response;
    type Error;
    type Service: Service<Req>;
    
    async fn create(&self, cfg: Cfg) -> Result<Self::Service, Self::Error>;
}
```

**کاربرد**: ایجاد instance جدید از service برای هر worker thread

#### C. Transform Trait

```rust
pub trait Transform<S, Req> {
    type Response;
    type Error;
    type Transform: Service<Req>;
    
    async fn new_transform(&self, service: S) 
        -> Result<Self::Transform, Self::Error>;
}
```

**کاربرد**: تبدیل یک service به service دیگر

---

## 🧩 مثال کامل: ساخت یک Plugin سفارشی

### مثال: Authentication Middleware

```rust
use ntex::http;
use ntex::web::{self, Error, ErrorUnauthorized};
use ntex_service::{Service, ServiceCtx, Middleware};

// 1. تعریف Plugin Configuration
pub struct AuthMiddleware {
    secret_key: String,
}

impl AuthMiddleware {
    pub fn new(secret_key: String) -> Self {
        Self { secret_key }
    }
}

// 2. پیاده‌سازی Middleware Trait
impl<S> Middleware<S> for AuthMiddleware {
    type Service = AuthService<S>;

    fn create(&self, service: S) -> Self::Service {
        AuthService {
            service,
            secret_key: self.secret_key.clone(),
        }
    }
}

// 3. Service Wrapper
pub struct AuthService<S> {
    service: S,
    secret_key: String,
}

// 4. پیاده‌سازی Service Trait
impl<S, Err> Service<web::WebRequest<Err>> for AuthService<S>
where
    S: Service<web::WebRequest<Err>, Response = web::WebResponse>,
    Err: web::ErrorRenderer,
{
    type Response = web::WebResponse;
    type Error = Error;

    async fn call(
        &self,
        req: web::WebRequest<Err>,
        ctx: ServiceCtx<'_, Self>,
    ) -> Result<Self::Response, Self::Error> {
        // بررسی authentication
        let auth_header = req
            .headers()
            .get(http::header::AUTHORIZATION)
            .and_then(|h| h.to_str().ok());

        match auth_header {
            Some(token) if self.validate_token(token) => {
                // اجرای service اصلی
                ctx.call(&self.service, req).await
            }
            _ => Err(ErrorUnauthorized("Invalid token")),
        }
    }
}

impl<S> AuthService<S> {
    fn validate_token(&self, token: &str) -> bool {
        // منطق اعتبارسنجی
        token.starts_with(&self.secret_key)
    }
}

// 5. استفاده
fn main() {
    let app = App::new()
        .wrap(AuthMiddleware::new("my-secret".to_string()))
        .route("/api/protected", web::get().to(handler));
}
```

---

## 🎨 4. پیاده‌سازی در ZiServ {#ziserv-implementation}

### الف) Service Abstraction در Zig

```zig
// modules/ziserv-service/src/root.zig

const std = @import("std");

/// Service trait معادل در Zig
pub fn Service(comptime Request: type, comptime Response: type, comptime Error: type) type {
    return struct {
        ptr: *anyopaque,
        vtable: *const VTable,

        pub const VTable = struct {
            call: *const fn (*anyopaque, Request) Error!Response,
            ready: *const fn (*anyopaque) Error!void,
            shutdown: *const fn (*anyopaque) void,
        };

        pub fn call(self: @This(), req: Request) Error!Response {
            return self.vtable.call(self.ptr, req);
        }

        pub fn ready(self: @This()) Error!void {
            return self.vtable.ready(self.ptr);
        }

        pub fn shutdown(self: @This()) void {
            self.vtable.shutdown(self.ptr);
        }
    };
}

/// مثال استفاده
pub const HttpRequest = struct {
    method: []const u8,
    path: []const u8,
};

pub const HttpResponse = struct {
    status: u16,
    body: []const u8,
};

pub const HttpService = Service(HttpRequest, HttpResponse, anyerror);
```

### ب) Middleware Pattern در Zig

```zig
// modules/ziserv-service/src/middleware.zig

const std = @import("std");
const Service = @import("root.zig").Service;

/// Timeout Middleware
pub fn Timeout(comptime S: type) type {
    return struct {
        service: S,
        timeout_ms: u64,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, service: S, timeout_ms: u64) Self {
            return .{
                .service = service,
                .timeout_ms = timeout_ms,
                .allocator = allocator,
            };
        }

        pub fn call(self: *Self, req: anytype) !@TypeOf(self.service).Response {
            // شبیه‌سازی timeout با thread
            const result = try self.service.call(req);
            return result;
        }

        pub fn ready(self: *Self) !void {
            return self.service.ready();
        }

        pub fn shutdown(self: *Self) void {
            self.service.shutdown();
        }
    };
}

/// Logger Middleware
pub fn Logger(comptime S: type) type {
    return struct {
        service: S,
        logger: @import("ziserv-core").logger.Logger,

        const Self = @This();

        pub fn init(service: S, logger: anytype) Self {
            return .{
                .service = service,
                .logger = logger,
            };
        }

        pub fn call(self: *Self, req: anytype) !@TypeOf(self.service).Response {
            try self.logger.info("Request: {any}", .{req});
            
            const result = self.service.call(req) catch |err| {
                try self.logger.err("Error: {}", .{err});
                return err;
            };
            
            try self.logger.info("Response: {any}", .{result});
            return result;
        }

        pub fn ready(self: *Self) !void {
            return self.service.ready();
        }

        pub fn shutdown(self: *Self) void {
            self.service.shutdown();
        }
    };
}
```

### ج) Plugin System در ZiServ

```zig
// modules/ziserv-http/src/app.zig

const std = @import("std");
const core = @import("ziserv-core");

pub const App = struct {
    allocator: std.mem.Allocator,
    middlewares: std.ArrayList(Middleware),
    routes: std.StringHashMap(Handler),
    
    const Self = @This();
    
    pub const Middleware = struct {
        ptr: *anyopaque,
        vtable: *const VTable,
        
        pub const VTable = struct {
            process: *const fn (*anyopaque, *Request, *Response) anyerror!void,
            deinit: *const fn (*anyopaque) void,
        };
    };
    
    pub const Handler = *const fn (*Request) anyerror!Response;
    
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .middlewares = std.ArrayList(Middleware).init(allocator),
            .routes = std.StringHashMap(Handler).init(allocator),
        };
    }
    
    pub fn deinit(self: *Self) void {
        for (self.middlewares.items) |mw| {
            mw.vtable.deinit(mw.ptr);
        }
        self.middlewares.deinit();
        self.routes.deinit();
    }
    
    /// اضافه کردن middleware
    pub fn use(self: *Self, middleware: Middleware) !void {
        try self.middlewares.append(middleware);
    }
    
    /// ثبت route
    pub fn route(self: *Self, path: []const u8, handler: Handler) !void {
        try self.routes.put(path, handler);
    }
    
    /// پردازش request با middleware chain
    pub fn handle(self: *Self, req: *Request) !Response {
        var resp = Response.init(self.allocator);
        
        // اجرای middleware‌ها به ترتیب معکوس
        var i = self.middlewares.items.len;
        while (i > 0) {
            i -= 1;
            const mw = self.middlewares.items[i];
            try mw.vtable.process(mw.ptr, req, &resp);
        }
        
        // اجرای handler
        if (self.routes.get(req.path)) |handler| {
            return try handler(req);
        }
        
        return error.NotFound;
    }
};
```

### د) مثال استفاده

```zig
// examples/middleware-example/main.zig

const std = @import("std");
const ziserv = @import("ziserv-http");

// 1. تعریف Custom Middleware
const AuthMiddleware = struct {
    secret: []const u8,
    
    pub fn init(secret: []const u8) @This() {
        return .{ .secret = secret };
    }
    
    pub fn process(self: *@This(), req: *ziserv.Request, resp: *ziserv.Response) !void {
        const auth_header = req.headers.get("Authorization") orelse {
            resp.status = 401;
            resp.body = "Unauthorized";
            return error.Unauthorized;
        };
        
        if (!std.mem.startsWith(u8, auth_header, self.secret)) {
            resp.status = 403;
            resp.body = "Forbidden";
            return error.Forbidden;
        }
    }
    
    pub fn deinit(self: *@This()) void {
        _ = self;
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // ایجاد App
    var app = ziserv.App.init(allocator);
    defer app.deinit();
    
    // اضافه کردن middleware‌ها
    var auth = AuthMiddleware.init("Bearer secret-key");
    try app.use(.{
        .ptr = &auth,
        .vtable = &.{
            .process = struct {
                fn process(ptr: *anyopaque, req: *ziserv.Request, resp: *ziserv.Response) !void {
                    const self: *AuthMiddleware = @ptrCast(@alignCast(ptr));
                    try self.process(req, resp);
                }
            }.process,
            .deinit = struct {
                fn deinit(ptr: *anyopaque) void {
                    const self: *AuthMiddleware = @ptrCast(@alignCast(ptr));
                    self.deinit();
                }
            }.deinit,
        },
    });
    
    // ثبت routes
    try app.route("/api/data", handleData);
    
    // شروع سرور
    try app.start();
}

fn handleData(req: *ziserv.Request) !ziserv.Response {
    return .{
        .status = 200,
        .body = "Protected data",
    };
}
```

---

## 📊 مقایسه: ntex vs ZiServ

| ویژگی | ntex (Rust) | ZiServ (Zig) |
|-------|-------------|--------------|
| **Service Abstraction** | Trait-based | VTable-based |
| **Type Safety** | Compile-time (generics) | Runtime (anyopaque) |
| **Middleware Chain** | Type-level composition | Runtime array |
| **Performance** | Zero-cost abstractions | Minimal overhead |
| **Flexibility** | بسیار بالا | بالا |

---

## 🎯 مزایای معماری Plugin

### 1. **Separation of Concerns**
هر plugin یک مسئولیت مشخص دارد:
- Authentication → AuthMiddleware
- Logging → LoggerMiddleware
- Compression → CompressMiddleware

### 2. **Reusability**
یک middleware برای همه سرویس‌ها قابل استفاده است

### 3. **Testability**
هر middleware به صورت مستقل قابل تست است

### 4. **Composability**
middleware‌ها قابل ترکیب با ترتیب دلخواه هستند

---

## 🚀 پیشنهادات پیاده‌سازی برای ZiServ

### فاز 1: Service Abstraction
- [ ] پیاده‌سازی Service trait با VTable
- [ ] پشتیبانی از generic Request/Response types
- [ ] مستندات کامل

### فاز 2: Middleware System
- [ ] Middleware registration API
- [ ] Execution chain
- [ ] Built-in middlewares (Logger, Timeout, Compress)

### فاز 3: Plugin Ecosystem
- [ ] Plugin discovery mechanism
- [ ] Dynamic loading (optional)
- [ ] Plugin marketplace/registry

---

## 📚 منابع اضافی

- [ntex Service Documentation](https://docs.rs/ntex/latest/ntex/trait.Service.html)
- [Middleware Pattern](https://ntex.rs/docs/middleware)
- [Tower (Rust middleware library)](https://github.com/tower-rs/tower)

---

*این مستند برای طراحی معماری extensible در ZiServ تهیه شده است*