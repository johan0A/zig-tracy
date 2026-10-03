const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const root_module = b.addModule("tracy", .{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,
    });

    const options = .{
        .src_directory_path = b.option([]const u8, "src_directory_path", "path to the root source file's directory (default: \"src\")") orelse "src",
        .enable_tracy = b.option(bool, "enable_tracy", "enable tracy profile markers") orelse false,
        .enable_fibers = b.option(bool, "enable_fibers", "enable tracy fiber support") orelse false,
        .on_demand = b.option(bool, "on_demand", "builds tracy with TRACY_ON_DEMAND") orelse false,
        .callstack_support = b.option(bool, "callstack_support", "enable callstack support") orelse true,
        .default_callstack_depth = b.option(u32, "default_callstack_depth", "sets TRACY_CALLSTACK to the depth provided") orelse 0,
        .tracy_no_exit = b.option(bool, "tracy_no_exit", "build tracy with TRACY_NO_EXIT") orelse false,
    };

    const options_step = b.addOptions();
    const info = @typeInfo(@TypeOf(options)).@"struct";
    inline for (info.field_names, info.field_types) |name, @"type"| {
        options_step.addOption(@"type", name, @field(options, name));
    }
    root_module.addImport("options", options_step.createModule());

    var macros: std.ArrayList(struct { name: []const u8, value: []const u8 }) = .empty;
    if (options.enable_tracy) try macros.append(b.allocator, .{ .name = "TRACY_ENABLE", .value = "" });
    if (options.enable_fibers) try macros.append(b.allocator, .{ .name = "TRACY_FIBERS", .value = "" });
    if (options.on_demand) try macros.append(b.allocator, .{ .name = "TRACY_ON_DEMAND", .value = "" });
    if (options.default_callstack_depth > 0) try macros.append(b.allocator, .{ .name = "TRACY_CALLSTACK", .value = b.fmt("{}", .{options.default_callstack_depth}) });
    if (options.tracy_no_exit) try macros.append(b.allocator, .{ .name = "TRACY_NO_EXIT", .value = "" });

    if (options.enable_tracy) {
        const translate_c = b.addTranslateC(.{
            .root_source_file = b.path("vendor/tracy/tracy/TracyC.h"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        translate_c.addIncludePath(b.path("vendor/tracy/tracy"));
        for (macros.items) |macro| translate_c.defineCMacro(macro.name, macro.value);
        root_module.addImport("c", translate_c.createModule());
    }

    if (options.enable_tracy) {
        root_module.addIncludePath(b.path("vendor/tracy/tracy"));
        root_module.addCSourceFile(.{
            .file = b.path("vendor/tracy/TracyClient.cpp"),
            .flags = &.{"-fno-sanitize=undefined"},
        });

        for (macros.items) |macro| root_module.addCMacro(macro.name, macro.value);

        if (target.result.abi != .msvc) {
            root_module.link_libcpp = true;
        } else {
            root_module.addCMacro("fileno", "_fileno");
        }

        if (target.result.os.tag == .windows) {
            root_module.linkSystemLibrary("ws2_32", .{});
            root_module.linkSystemLibrary("dbghelp", .{});
        }
    }
}
