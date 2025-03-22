pub const Zone = struct {
    zone_context: if (options.enable_tracing) c.___tracy_c_zone_context else void,

    pub inline fn text(self: Zone, zone_text: []const u8) void {
        if (!options.enable_tracing) return;
        c.___tracy_emit_zone_text(self.zone_context, zone_text.ptr, zone_text.len);
    }

    pub inline fn name(self: Zone, zone_name: []const u8) void {
        if (!options.enable_tracing) return;
        c.___tracy_emit_zone_name(self.zone_context, zone_name.ptr, zone_name.len);
    }

    pub inline fn value(self: Zone, zone_val: u64) void {
        if (!options.enable_tracing) return;
        c.___tracy_emit_zone_value(self.zone_context, zone_val);
    }

    pub inline fn end(self: Zone) void {
        if (!options.enable_tracing) return;
        c.___tracy_emit_zone_end(self.zone_context);
    }
};

const ZoneConfig = struct {
    name: ?[*:0]const u8 = null,
    color: Color = .fromU32(0),
    callstack_depth: ?c_int = 0,
};

pub inline fn zoneEx(comptime src: SourceLocation, config: ZoneConfig) Zone {
    if (!options.enable_tracing) return .{ .zone_context = {} };
    const depth = config.callstack_depth orelse options.default_callstack_depth;

    const global = struct {
        const loc: c.___tracy_source_location_data = .{
            .name = config.name,
            .function = src.fn_name.ptr,
            .file = src.file.ptr,
            .line = src.line,
            .color = @bitCast(config.color),
        };
    };

    const zone_context = if (options.callstack_support)
        c.___tracy_emit_zone_begin_callstack(&global.loc, depth, 1)
    else
        c.___tracy_emit_zone_begin(&global.loc, 1);

    return Zone{ .zone_context = zone_context };
}

pub inline fn zone(comptime src: SourceLocation) Zone {
    return zoneEx(src, .{});
}

pub inline fn SetThreadName(name: [*:0]const u8) void {
    if (!options.enable_tracing) return;
    c.___tracy_set_thread_name(name);
}

const AllocConfig = struct {
    name: ?[*:0]const u8 = null,
    callstack_depth: ?c_int = null,
    secure: bool = false,
};

// pointer argument should be of type slice or single item pointer
pub inline fn markAlloc(pointer: anytype, config: AllocConfig) void {
    if (!options.enable_tracing) return;
    const depth = config.callstack_depth orelse options.default_callstack_depth;

    const info = @typeInfo(@TypeOf(pointer));
    if (info != .pointer) @compileError("pointer argument should be of type slice or single item pointer");

    const ptr: [*]u8 = switch (info.pointer.size) {
        .one => @ptrCast(pointer),
        .slice => @ptrCast(pointer.ptr),
        else => @compileError("pointer argument should be of type slice or single item pointer"),
    };

    const size: usize = switch (info.pointer.size) {
        .one => @sizeOf(std.meta.Child(@TypeOf(pointer))),
        .slice => pointer.len * @sizeOf(std.meta.Child(@TypeOf(pointer))),
        else => unreachable,
    };

    if (config.name) |name| {
        if (options.callstack_support) {
            c.___tracy_emit_memory_alloc_callstack_named(ptr, size, depth, @intFromBool(config.secure), name);
        } else {
            c.___tracy_emit_memory_alloc_named(ptr, size, @intFromBool(config.secure), name);
        }
    } else {
        if (options.callstack_support) {
            c.___tracy_emit_memory_alloc_callstack(ptr, size, depth, @intFromBool(config.secure));
        } else {
            c.___tracy_emit_memory_alloc(ptr, size, @intFromBool(config.secure));
        }
    }
}

// pointer argument should be of type pointer
pub inline fn markFree(pointer: anytype, config: AllocConfig) void {
    if (!options.enable_tracing) return;
    const depth = config.callstack_depth orelse options.default_callstack_depth;

    const info = @typeInfo(@TypeOf(pointer));
    if (info != .pointer) @compileError("pointer argument should be of type pointer");

    const ptr: [*]u8 = switch (info.pointer.size) {
        .one, .many, .c => @ptrCast(pointer),
        .slice => @ptrCast(pointer.ptr),
    };

    if (config.name) |name| {
        if (options.callstack_support) {
            c.___tracy_emit_memory_free_callstack_named(ptr, depth, @intFromBool(config.secure), name);
        } else {
            c.___tracy_emit_memory_free_named(ptr, @intFromBool(config.secure), name);
        }
    } else {
        if (options.callstack_support) {
            c.___tracy_emit_memory_free_callstack(ptr, depth, @intFromBool(config.secure));
        } else {
            c.___tracy_emit_memory_free(ptr, @intFromBool(config.secure));
        }
    }
}

const MessageConfig = struct {
    color: ?Color = null,
    callstack_depth: ?c_int = null,
};

pub inline fn message(text: []const u8, message_config: MessageConfig) void {
    if (!options.enable_tracing) return;
    const depth = if (options.callstack_support)
        message_config.callstack_depth orelse options.default_callstack_depth
    else
        0;

    if (message_config.color) |color| {
        c.___tracy_emit_messageC(text.ptr, text.len, color, depth);
    } else {
        c.___tracy_emit_message(text.ptr, text.len, depth);
    }
}

pub inline fn frameMark(name: ?[*:0]const u8) void {
    if (!options.enable_tracing) return;
    c.___tracy_emit_frame_mark(name);
}
pub inline fn frameMarkStart(name: ?[*:0]const u8) void {
    if (!options.enable_tracing) return;
    c.___tracy_emit_frame_mark_start(name);
}
pub inline fn frameMarkEnd(name: ?[*:0]const u8) void {
    if (!options.enable_tracing) return;
    c.___tracy_emit_frame_mark_end(name);
}

/// image is a pointer to RGBA pixel data, width and height are the image dimensions, which must be divisible by 4,
/// offset specifies how much frame lag was there for the current image (see chapter 3.3.3.1), and flip should
/// be set, if the graphics API stores images upside-down. The profiler copies the image data, so you don’t
/// need to retain it.
///
/// Handling image data requires a lot of memory and bandwidth. To achieve sane memory usage, you
/// should scale down taken screenshots to a suitable size, e.g., 320 × 180.
/// To further reduce image data size, frame images are internally compressed using the DXT1 Texture Com-
/// pression technique, which significantly reduces data size, at a slight quality decrease. The compression
/// algorithm is high-speed and can be made even faster by enabling SIMD processing
pub inline fn setFrameImage(image: [*]Color, width: u16, height: u16, offset: u8, flip: bool) void {
    if (!options.enable_tracing) return;
    c.___tracy_emit_frame_image(image, width, height, offset, @intFromBool(flip));
}

pub inline fn fiberEnter(name: [*:0]const u8) void {
    if (!options.enable_tracing) return;
    if (!options.enable_fibers) return;
    c.___tracy_fiber_enter(name);
}
pub inline fn fiberLeave() void {
    if (!options.enable_tracing) return;
    if (!options.enable_fibers) return;
    c.___tracy_fiber_leave();
}

pub inline fn plot(name: [*:0]const u8, val: f64) void {
    if (!options.enable_tracing) return;
    c.___tracy_emit_plot(name, val);
}

pub inline fn appInfo(text: []const u8) void {
    if (!options.enable_tracing) return;
    c.___tracy_emit_message_appinfo(text.ptr, text.len);
}

pub const TracyAllocator = struct {
    child_allocator: std.mem.Allocator,
    name: ?[*:0]const u8,

    pub fn init(child_allocator: std.mem.Allocator, name: ?[*:0]const u8) TracyAllocator {
        return .{
            .child_allocator = child_allocator,
            .name = name,
        };
    }

    pub fn allocator(self: *TracyAllocator) std.mem.Allocator {
        if (!options.enable_tracing) return self.child_allocator;
        return .{
            .ptr = self,
            .vtable = &std.mem.Allocator.VTable{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *TracyAllocator = @ptrCast(@alignCast(ctx));
        const result = self.child_allocator.rawAlloc(len, alignment, ret_addr);
        if (result) |addr| {
            markAlloc(addr[0..len], .{ .name = self.name });
        } else {
            var buffer: [128]u8 = undefined;
            const msg = std.fmt.bufPrint(
                &buffer,
                "allocation of {d} bytes failed from allocator: {s}",
                .{ len, self.name orelse "unnamed" },
            ) catch return result;
            message(msg, .{});
        }
        return result;
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *TracyAllocator = @ptrCast(@alignCast(ctx));
        const result = self.child_allocator.rawResize(memory, alignment, new_len, ret_addr);
        if (result) {
            markFree(memory.ptr, .{ .name = self.name });
            markAlloc(memory.ptr[0..new_len], .{ .name = self.name });
        }
        return result;
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *TracyAllocator = @ptrCast(@alignCast(ctx));
        const result = self.child_allocator.rawRemap(memory, alignment, new_len, ret_addr);
        if (result) |addr| {
            markFree(memory.ptr, .{ .name = self.name });
            markAlloc(addr[0..new_len], .{ .name = self.name });
        }
        return result;
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *TracyAllocator = @ptrCast(@alignCast(ctx));
        self.child_allocator.rawFree(memory, alignment, ret_addr);
        markFree(memory.ptr, .{ .name = self.name });
    }
};

pub const Color = packed struct(u32) {
    b: u8,
    g: u8,
    r: u8,
    a: u8,

    fn fromU32(value: u32) Color {
        return @bitCast(value);
    }
};

const options = @import("options");
const c = @import("c");

const std = @import("std");
const SourceLocation = std.builtin.SourceLocation;
