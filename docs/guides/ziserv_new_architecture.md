# معماری جدید ZiServ - ساختار آینده‌نگر

## 🎯 فلسفه طراحی

بر اساس ntex و بهترین practice‌های صنعت:
- **ماژولار**: هر ماژول یک مسئولیت مشخص
- **قابل ترکیب**: ماژول‌ها قابل ترکیب با یکدیگر
- **مستقل**: هر ماژول قابل استفاده مستقل
- **لایه‌بندی**: از پایین به بالا (Foundation → Protocol → Application)

---

## 📦 ساختار کلی پروژه

```
ziserv/
├── README.md
├── LICENSE
├── docs/                           # مستندات
│   ├── architecture/
│   ├── guides/
│   └── api/
├── modules/                        # تمام ماژول‌ها
│   ├── foundation/                 # لایه پایه
│   │   ├── ziserv-core/
│   │   ├── ziserv-bytes/
│   │   ├── ziserv-codec/
│   │   └── ziserv-util/
│   ├── async/                      # لایه async
│   │   ├── ziserv-service/
│   │   ├── ziserv-runtime/
│   │   └── ziserv-channel/
│   ├── io/                         # لایه I/O
│   │   ├── ziserv-io/
│   │   ├── ziserv-net/
│   │   └── ziserv-tls/
│   ├── protocols/                  # لایه پروتکل
│   │   ├── ziserv-http/
│   │   ├── ziserv-ws/
│   │   └── ziserv-mqtt/
│   ├── platform/                   # لایه سیستم‌عامل
│   │   ├── ziserv-os/
│   │   ├── ziserv-windows/
│   │   └── ziserv-linux/
│   └── application/                # لایه اپلیکیشن
│       ├── ziserv-server/
│       ├── ziserv-client/
│       └── ziserv/                 # Main aggregator
├── examples/                       # مثال‌های کاربردی
│   ├── hello-world/
│   ├── http-server/
│   ├── websocket/
│   ├── database/
│   └── production/
├── benchmarks/                     # Benchmarks
│   ├── http/
│   ├── io/
│   └── service/
└── tools/                          # ابزارهای توسعه
    ├── codegen/
    └── testing/
```

---

## 🏗️ لایه‌بندی معماری

### 1️⃣ Foundation Layer (پایه)

#### `ziserv-core`
```
نقش: اصول اولیه سیستم
وابستگی: هیچ
```

**محتوا:**
- Platform detection (Windows/Linux)
- Basic types و traits
- Error handling foundation
- Memory management patterns
- Configuration system

**مثال ساختار:**
```
ziserv-core/
├── build.zig
├── build.zig.zon
└── src/
    ├── root.zig           # Entry point
    ├── platform.zig       # Platform detection
    ├── error.zig          # Error types
    ├── config.zig         # Configuration
    ├── traits.zig         # Common traits/interfaces
    └── memory.zig         # Memory utilities
```

#### `ziserv-bytes`
```
نقش: مدیریت bytes و buffers
وابستگی: ziserv-core
```

**محتوا:**
- ByteBuffer
- BytesMut (mutable)
- BytesRef (reference)
- Zero-copy operations
- Buffer pooling

#### `ziserv-codec`
```
نقش: Encoding/Decoding
وابستگی: ziserv-bytes, ziserv-core
```

**محتوا:**
- Encoder/Decoder traits
- Common codecs (UTF-8, Base64, Hex)
- Framing support
- Compression support

#### `ziserv-util`
```
نقش: ابزارهای عمومی
وابستگی: ziserv-core
```

**محتوا:**
- Collections (HashMap, etc.)
- Time utilities
- String utilities
- Math helpers
- Common algorithms

---

### 2️⃣ Async Layer (غیرهمزمان)

#### `ziserv-service`
```
نقش: Service abstraction (همان که ساختیم)
وابستگی: ziserv-core, ziserv-util
```

**محتوا:**
- Service trait/interface
- Context management
- Middleware system
- Pipeline support

#### `ziserv-runtime`
```
نقش: Runtime برای async operations
وابستگی: ziserv-core, ziserv-service
```

**محتوا:**
- Task executor
- Scheduler
- Thread pool
- Timer support

#### `ziserv-channel`
```
نقش: Communication بین tasks
وابستگی: ziserv-core, ziserv-runtime
```

**محتوا:**
- MPSC (Multi-Producer Single-Consumer)
- SPSC (Single-Producer Single-Consumer)
- Broadcast channel
- Watch channel

---

### 3️⃣ I/O Layer (ورودی/خروجی)

#### `ziserv-io`
```
نقش: I/O abstractions
وابستگی: ziserv-core, ziserv-bytes, ziserv-service
```

**محتوا:**
- AsyncRead trait
- AsyncWrite trait
- BufReader/BufWriter
- Split (read/write halves)
- Copy utilities

#### `ziserv-net`
```
نقش: Network primitives
وابستگی: ziserv-core, ziserv-io
```

**محتوا:**
- TcpListener
- TcpStream
- UdpSocket
- UnixSocket
- Address resolution

#### `ziserv-tls`
```
نقش: TLS/SSL support
وابستگی: ziserv-core, ziserv-io, ziserv-net
```

**محتوا:**
- TLS client
- TLS server
- Certificate management
- Cipher suites

---

### 4️⃣ Protocol Layer (پروتکل‌ها)

#### `ziserv-http`
```
نقش: HTTP protocol implementation
وابستگی: ziserv-core, ziserv-io, ziserv-bytes, ziserv-codec
```

**محتوا:**
```
ziserv-http/
├── build.zig
├── build.zig.zon
└── src/
    ├── root.zig
    ├── request.zig        # HTTP Request
    ├── response.zig       # HTTP Response
    ├── headers.zig        # Header handling
    ├── method.zig         # HTTP methods
    ├── status.zig         # Status codes
    ├── body.zig           # Body handling
    ├── uri.zig            # URI parsing
    ├── version.zig        # HTTP versions (1.0, 1.1, 2.0)
    └── codec.zig          # HTTP codec
```

#### `ziserv-ws`
```
نقش: WebSocket protocol
وابستگی: ziserv-core, ziserv-io, ziserv-http
```

**محتوا:**
- WebSocket handshake
- Frame parsing
- Message handling
- Ping/Pong

#### `ziserv-mqtt` (آینده)
```
نقش: MQTT protocol
وابستگی: ziserv-core, ziserv-io
```

---

### 5️⃣ Platform Layer (سیستم‌عامل)

#### `ziserv-os`
```
نقش: OS abstractions (common)
وابستگی: ziserv-core
```

**محتوا:**
- Process management
- Signal handling
- Environment variables
- File system operations

#### `ziserv-windows`
```
نقش: Windows-specific features
وابستگی: ziserv-core, ziserv-os
```

**محتوا:**
- Windows service management
- Registry access
- Windows-specific APIs
- IOCP integration

#### `ziserv-linux`
```
نقش: Linux-specific features
وابستگی: ziserv-core, ziserv-os
```

**محتوا:**
- Systemd service management
- Epoll integration
- Linux-specific APIs
- D-Bus integration (optional)

---

### 6️⃣ Application Layer (اپلیکیشن)

#### `ziserv-server`
```
نقش: HTTP Server implementation
وابستگی: ziserv-http, ziserv-net, ziserv-service, ziserv-runtime
```

**محتوا:**
```
ziserv-server/
├── build.zig
├── build.zig.zon
└── src/
    ├── root.zig
    ├── server.zig         # Server core
    ├── listener.zig       # Listener management
    ├── connection.zig     # Connection handling
    ├── router.zig         # Request routing
    ├── middleware.zig     # Middleware system
    ├── handler.zig        # Handler types
    ├── app.zig           # Application builder
    └── config.zig        # Server configuration
```

#### `ziserv-client`
```
نقش: HTTP Client
وابستگی: ziserv-http, ziserv-net, ziserv-service
```

**محتوا:**
- HTTP client
- Connection pooling
- Retry logic
- Timeout handling

#### `ziserv` (Main)
```
نقش: Main aggregator - re-exports همه چیز
وابستگی: همه ماژول‌های بالا
```

**محتوا:**
```zig
// Re-export commonly used items
pub const core = @import("ziserv-core");
pub const service = @import("ziserv-service");
pub const http = @import("ziserv-http");
pub const server = @import("ziserv-server");
pub const net = @import("ziserv-net");

// High-level API
pub const Server = server.Server;
pub const Router = server.Router;
pub const Request = http.Request;
pub const Response = http.Response;
```

---

## 🔗 نمودار وابستگی‌ها

```
                    ┌─────────────────┐
                    │   ziserv        │  (Main aggregator)
                    │   (re-exports)  │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        v                    v                    v
  ┌──────────┐         ┌──────────┐        ┌──────────┐
  │  server  │         │  client  │        │    ws    │
  └────┬─────┘         └────┬─────┘        └────┬─────┘
       │                    │                    │
       └──────────┬─────────┴──────────┬─────────┘
                  │                    │
                  v                    v
            ┌──────────┐         ┌──────────┐
            │   http   │         │   net    │
            └────┬─────┘         └────┬─────┘
                 │                    │
                 └──────────┬─────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
            v               v               v
      ┌─────────┐     ┌─────────┐    ┌─────────┐
      │   io    │     │ service │    │  bytes  │
      └────┬────┘     └────┬────┘    └────┬────┘
           │               │              │
           └───────────────┼──────────────┘
                           │
                           v
                    ┌──────────┐
                    │   core   │  (Foundation)
                    └──────────┘
```

---

## 📋 جدول مقایسه با ntex

| جنبه | ntex (Rust) | ZiServ (Zig) |
|------|-------------|--------------|
| **Foundation** | ntex-bytes, ntex-util | ziserv-core, ziserv-bytes, ziserv-util |
| **Service** | ntex-service | ziserv-service |
| **I/O** | ntex-io | ziserv-io |
| **Network** | ntex-net | ziserv-net |
| **HTTP** | ntex-http | ziserv-http |
| **Server** | ntex-server | ziserv-server |
| **Runtime** | ntex-rt (tokio/compio) | ziserv-runtime (native) |
| **TLS** | ntex-tls | ziserv-tls |
| **Router** | ntex-router | در ziserv-server |

---

## 🎯 مزایای این ساختار

### 1. **Modularity**
- هر ماژول مستقل قابل استفاده
- آزمایش و توسعه آسان‌تر

### 2. **Composability**
- ماژول‌ها قابل ترکیب
- کاربر فقط آنچه نیاز دارد import می‌کند

### 3. **Maintainability**
- هر ماژول قابل نگهداری جداگانه
- تیم‌های مختلف روی ماژول‌های مختلف کار می‌کنند

### 4. **Extensibility**
- اضافه کردن ماژول جدید آسان
- بدون تغییر در ماژول‌های موجود

### 5. **Performance**
- Compile-time optimization
- Zero-cost abstractions
- Fine-grained control

---

## 🚀 مراحل پیاده‌سازی (Roadmap)

### Phase 1: Foundation (2-3 ماه)
- [x] ziserv-core
- [x] ziserv-service (انجام شد!)
- [ ] ziserv-bytes
- [ ] ziserv-codec
- [ ] ziserv-util

### Phase 2: I/O (2-3 ماه)
- [ ] ziserv-io
- [ ] ziserv-net
- [ ] ziserv-runtime

### Phase 3: HTTP (2-3 ماه)
- [ ] ziserv-http (protocol)
- [ ] ziserv-server
- [ ] ziserv-client

### Phase 4: Platform (1-2 ماه)
- [ ] ziserv-os
- [ ] ziserv-windows
- [ ] ziserv-linux

### Phase 5: Advanced (3-4 ماه)
- [ ] ziserv-ws
- [ ] ziserv-tls
- [ ] ziserv-mqtt

### Phase 6: Ecosystem (مداوم)
- [ ] Examples
- [ ] Documentation
- [ ] Benchmarks
- [ ] Community

---

## 💡 نکات طراحی

### 1. **API Stability**
- Semantic versioning
- Deprecation warnings
- Migration guides

### 2. **Documentation**
- API docs
- Guides و tutorials
- Architecture decisions (ADR)

### 3. **Testing**
- Unit tests در هر ماژول
- Integration tests
- Performance benchmarks

### 4. **CI/CD**
- Automated testing
- Cross-platform builds
- Release automation

---

## 📚 مثال استفاده نهایی

```zig
const ziserv = @import("ziserv");

pub fn main() !void {
    var app = try ziserv.Server.init(.{
        .host = "0.0.0.0",
        .port = 8080,
    });

    var router = ziserv.Router.init();
    try router.get("/", indexHandler);
    try router.post("/api/users", createUser);

    try app.use(ziserv.middleware.Logger.init());
    try app.use(ziserv.middleware.Cors.init());
    try app.router(router);

    try app.start();
}
```

---

## 🎨 نتیجه‌گیری

این ساختار:
- ✅ الهام‌گرفته از ntex
- ✅ مناسب برای Zig
- ✅ قابل توسعه
- ✅ حرفه‌ای و آینده‌نگر
- ✅ آماده برای production

**بعدی**: شروع از کدام ماژول؟ پیشنهاد من:
1. تکمیل `ziserv-core`
2. شروع `ziserv-bytes`
3. سپس `ziserv-io`
