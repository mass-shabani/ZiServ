// ============================================================
// فایل: modules/foundation/ziserv-util/src/collections.zig
// Collection utilities - HashMap, ArrayList wrappers
// ============================================================

const std = @import("std");

/// HashMap wrapper با API بهتر
pub fn HashMap(comptime K: type, comptime V: type) type {
    return struct {
        map: std.AutoHashMap(K, V),
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .map = std.AutoHashMap(K, V).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn put(self: *Self, key: K, value: V) !void {
            try self.map.put(key, value);
        }

        pub fn get(self: *const Self, key: K) ?V {
            return self.map.get(key);
        }

        pub fn getPtr(self: *Self, key: K) ?*V {
            return self.map.getPtr(key);
        }

        pub fn remove(self: *Self, key: K) bool {
            return self.map.remove(key);
        }

        pub fn contains(self: *const Self, key: K) bool {
            return self.map.contains(key);
        }

        pub fn count(self: *const Self) usize {
            return self.map.count();
        }

        pub fn clear(self: *Self) void {
            self.map.clearRetainingCapacity();
        }

        pub fn keys(self: *const Self) []const K {
            return self.map.keys();
        }

        pub fn values(self: *const Self) []const V {
            return self.map.values();
        }

        pub fn iterator(self: *Self) std.AutoHashMap(K, V).Iterator {
            return self.map.iterator();
        }

        pub fn keyIterator(self: *Self) std.AutoHashMap(K, V).KeyIterator {
            return self.map.keyIterator();
        }

        pub fn valueIterator(self: *Self) std.AutoHashMap(K, V).ValueIterator {
            return self.map.valueIterator();
        }
    };
}

/// ArrayList wrapper
pub fn ArrayList(comptime T: type) type {
    return struct {
        list: std.ArrayList(T),
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .list = std.ArrayList(T){},
                .allocator = allocator,
            };
        }

        pub fn initCapacity(allocator: std.mem.Allocator, capacity_size: usize) !Self {
            var lst = std.ArrayList(T){};
            try lst.ensureTotalCapacity(allocator, capacity_size);
            return .{
                .list = lst,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.list.deinit(self.allocator);
        }

        pub fn append(self: *Self, item: T) !void {
            try self.list.append(self.allocator, item);
        }

        pub fn appendSlice(self: *Self, items_for_append: []const T) !void {
            try self.list.appendSlice(self.allocator, items_for_append);
        }

        pub fn insert(self: *Self, index: usize, item: T) !void {
            try self.list.insert(self.allocator, index, item);
        }

        pub fn orderedRemove(self: *Self, index: usize) T {
            return self.list.orderedRemove(index);
        }

        pub fn swapRemove(self: *Self, index: usize) T {
            return self.list.swapRemove(index);
        }

        pub fn pop(self: *Self) ?T {
            return self.list.popOrNull();
        }

        pub fn get(self: *const Self, index: usize) ?T {
            if (index >= self.list.items.len) return null;
            return self.list.items[index];
        }

        pub fn set(self: *Self, index: usize, value: T) !void {
            if (index >= self.list.items.len) return error.IndexOutOfBounds;
            self.list.items[index] = value;
        }

        pub fn len(self: *const Self) usize {
            return self.list.items.len;
        }

        pub fn capacity(self: *const Self) usize {
            return self.list.capacity;
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.list.items.len == 0;
        }

        pub fn clear(self: *Self) void {
            self.list.clearRetainingCapacity();
        }

        pub fn items(self: *const Self) []const T {
            return self.list.items;
        }

        pub fn toOwnedSlice(self: *Self) ![]T {
            return self.list.toOwnedSlice(self.allocator);
        }
    };
}

/// HashSet (using HashMap with void values)
pub fn HashSet(comptime K: type) type {
    return struct {
        map: std.AutoHashMap(K, void),
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .map = std.AutoHashMap(K, void).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn add(self: *Self, key: K) !void {
            try self.map.put(key, {});
        }

        pub fn contains(self: *const Self, key: K) bool {
            return self.map.contains(key);
        }

        pub fn remove(self: *Self, key: K) bool {
            return self.map.remove(key);
        }

        pub fn count(self: *const Self) usize {
            return self.map.count();
        }

        pub fn clear(self: *Self) void {
            self.map.clearRetainingCapacity();
        }

        pub fn iterator(self: *Self) std.AutoHashMap(K, void).KeyIterator {
            return self.map.keyIterator();
        }
    };
}

/// Ring Buffer (Fixed-size circular buffer)
pub fn RingBuffer(comptime T: type, comptime size: usize) type {
    return struct {
        buffer: [size]T,
        read_index: usize,
        write_index: usize,
        full: bool,

        const Self = @This();

        pub fn init() Self {
            return .{
                .buffer = undefined,
                .read_index = 0,
                .write_index = 0,
                .full = false,
            };
        }

        pub fn push(self: *Self, item: T) !void {
            if (self.full) return error.BufferFull;

            self.buffer[self.write_index] = item;
            self.write_index = (self.write_index + 1) % size;

            if (self.write_index == self.read_index) {
                self.full = true;
            }
        }

        pub fn pop(self: *Self) ?T {
            if (self.isEmpty()) return null;

            const item = self.buffer[self.read_index];
            self.read_index = (self.read_index + 1) % size;
            self.full = false;

            return item;
        }

        pub fn isEmpty(self: *const Self) bool {
            return !self.full and self.read_index == self.write_index;
        }

        pub fn isFull(self: *const Self) bool {
            return self.full;
        }

        pub fn len(self: *const Self) usize {
            if (self.full) return size;
            if (self.write_index >= self.read_index) {
                return self.write_index - self.read_index;
            }
            return size - (self.read_index - self.write_index);
        }

        pub fn capacity(self: *const Self) usize {
            _ = self;
            return size;
        }

        pub fn clear(self: *Self) void {
            self.read_index = 0;
            self.write_index = 0;
            self.full = false;
        }
    };
}

/// Priority Queue (min-heap)
pub fn PriorityQueue(comptime T: type, comptime compareFn: fn (T, T) bool) type {
    return struct {
        items: std.ArrayList(T),
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .items = std.ArrayList(T){},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
        }

        pub fn push(self: *Self, item: T) !void {
            try self.items.append(self.allocator, item);
            try self.siftUp(self.items.items.len - 1);
        }

        pub fn pop(self: *Self) ?T {
            if (self.items.items.len == 0) return null;

            const result = self.items.items[0];
            const last = self.items.pop();

            if (self.items.items.len > 0) {
                self.items.items[0] = last;
                self.siftDown(0);
            }

            return result;
        }

        pub fn peek(self: *const Self) ?T {
            if (self.items.items.len == 0) return null;
            return self.items.items[0];
        }

        pub fn len(self: *const Self) usize {
            return self.items.items.len;
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.items.items.len == 0;
        }

        fn siftUp(self: *Self, start_index: usize) !void {
            var index = start_index;
            while (index > 0) {
                const parent = (index - 1) / 2;
                if (!compareFn(self.items.items[index], self.items.items[parent])) break;

                const tmp = self.items.items[index];
                self.items.items[index] = self.items.items[parent];
                self.items.items[parent] = tmp;

                index = parent;
            }
        }

        fn siftDown(self: *Self, start_index: usize) void {
            var index = start_index;
            const lenth = self.items.items.len;

            while (true) {
                const left = 2 * index + 1;
                const right = 2 * index + 2;
                var smallest = index;

                if (left < lenth and compareFn(self.items.items[left], self.items.items[smallest])) {
                    smallest = left;
                }

                if (right < lenth and compareFn(self.items.items[right], self.items.items[smallest])) {
                    smallest = right;
                }

                if (smallest == index) break;

                const tmp = self.items.items[index];
                self.items.items[index] = self.items.items[smallest];
                self.items.items[smallest] = tmp;

                index = smallest;
            }
        }
    };
}

test "hashmap" {
    var map = HashMap([]const u8, i32).init(std.testing.allocator);
    defer map.deinit();

    try map.put("foo", 42);
    try map.put("bar", 100);

    try std.testing.expectEqual(@as(i32, 42), map.get("foo").?);
    try std.testing.expectEqual(@as(usize, 2), map.count());
}

test "arraylist" {
    var list = ArrayList(i32).init(std.testing.allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    try std.testing.expectEqual(@as(usize, 3), list.len());
    try std.testing.expectEqual(@as(i32, 2), list.get(1).?);
}

test "hashset" {
    var set = HashSet(i32).init(std.testing.allocator);
    defer set.deinit();

    try set.add(1);
    try set.add(2);
    try set.add(1); // duplicate

    try std.testing.expectEqual(@as(usize, 2), set.count());
    try std.testing.expect(set.contains(1));
}

test "ring buffer" {
    var rb = RingBuffer(i32, 4).init();

    try rb.push(1);
    try rb.push(2);
    try rb.push(3);

    try std.testing.expectEqual(@as(i32, 1), rb.pop().?);
    try std.testing.expectEqual(@as(i32, 2), rb.pop().?);
}

test "priority queue" {
    const lessThan = struct {
        fn lt(a: i32, b: i32) bool {
            return a < b;
        }
    }.lt;

    var pq = PriorityQueue(i32, lessThan).init(std.testing.allocator);
    defer pq.deinit();

    try pq.push(5);
    try pq.push(2);
    try pq.push(8);
    try pq.push(1);

    try std.testing.expectEqual(@as(i32, 1), pq.pop().?);
    try std.testing.expectEqual(@as(i32, 2), pq.pop().?);
}
