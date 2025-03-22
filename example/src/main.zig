const std = @import("std");
const tracy = @import("tracy");

fn foo() void {
    const zone = tracy.zone(@src());
    defer zone.end();
    std.Thread.sleep(std.time.ns_per_ms);
}

fn bar() void {
    const zone = tracy.zone(@src());
    defer zone.end();
    foo();
    tracy.message("foo message!", .{});
    foo();
    foo();
}

fn baz() void {
    const zone = tracy.zone(@src());
    defer zone.end();
    foo();
    bar();
}

fn qux(alloc: std.mem.Allocator) !void {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    for (0..1e6) |_| {
        try list.appendSlice(alloc, "hello");
    }
    defer list.deinit(alloc);

    const allocation = try alloc.alloc(u32, 1e6);
    defer alloc.free(allocation);

    const zone = tracy.zone(@src());
    defer zone.end();
    baz();
    const frame_name = "foo frame";
    tracy.frameMarkStart(frame_name);
    defer tracy.frameMarkEnd(frame_name);
    foo();
}

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    var tracy_allocator = tracy.TracyAllocator.init(gpa.allocator(), "foo allocator");
    const alloc: std.mem.Allocator = tracy_allocator.allocator();

    tracy.appInfo("foo app info");

    const image = try alloc.alloc(tracy.Color, 100 * 100);

    var it: u64 = 0;
    while (true) : (it += 1) {
        tracy.plot("plot foo", std.math.sin(@as(f64, @floatFromInt(it)) / 2) + 1);
        try qux(alloc);

        tracy.setFrameImage(image.ptr, 100, 100, 0, false);
        for (0..100) |x| {
            for (0..100) |y| {
                image[y * 100 + x] = .{
                    .r = @as(u8, @intCast(x)) +% @as(u8, @intCast(@mod(it * 4, 256))),
                    .g = @as(u8, @intCast(y)) +% @as(u8, @intCast(@mod(it * 4, 256))),
                    .b = @as(u8, @intCast(0)) +% @as(u8, @intCast(@mod(it * 4, 256))),
                    .a = @intCast(255),
                };
            }
        }

        tracy.frameMark(null);
    }
}
