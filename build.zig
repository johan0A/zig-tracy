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
        .callstack_support = b.option(bool, "callstack_support", "builds tracy with TRACY_USE_CALLSTACK") orelse false,
        .default_callstack_depth = b.option(u32, "default_callstack_depth", "sets TRACY_CALLSTACK to the depth provided") orelse 0,
        .tracy_no_exit = b.option(bool, "tracy_no_exit", "build tracy with TRACY_NO_EXIT") orelse false,
    };

    const options_step = b.addOptions();
    inline for (std.meta.fields(@TypeOf(options))) |option| {
        options_step.addOption(option.type, option.name, @field(options, option.name));
    }
    const options_module = options_step.createModule();
    root_module.addImport("options", options_module);

    {
        const translate_c = b.addTranslateC(.{
            .root_source_file = b.path("vendor/tracy/tracy/TracyC.h"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        translate_c.addIncludePath(b.path("vendor/tracy/tracy"));
        translate_c.defineCMacro("TRACY_ENABLE", "");
        translate_c.defineCMacro("TRACY_IMPORTS", "");
        translate_c.defineCMacro("TRACY_CALLSTACK", try std.fmt.allocPrint(b.allocator, "{}", .{options.default_callstack_depth}));
        if (options.callstack_support) translate_c.defineCMacro("TRACY_USE_CALLSTACK", "");
        if (options.tracy_no_exit) translate_c.defineCMacro("TRACY_NO_EXIT", "");

        root_module.addImport("c", translate_c.createModule());
    }

    {
        const tracy = b.addLibrary(.{
            .name = "tracy",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        tracy.root_module.addIncludePath(b.path("vendor/tracy/tracy"));
        tracy.root_module.addCSourceFile(.{
            .file = b.path("vendor/tracy/TracyClient.cpp"),
            .flags = &.{"-fno-sanitize=undefined"},
        });

        if (options.enable_tracy) tracy.root_module.addCMacro("TRACY_ENABLE", "");
        if (options.enable_fibers) tracy.root_module.addCMacro("TRACY_FIBERS", "");
        if (options.on_demand) tracy.root_module.addCMacro("TRACY_ON_DEMAND", "");

        if (target.result.abi != .msvc) {
            tracy.root_module.link_libcpp = true;
        } else {
            tracy.root_module.addCMacro("fileno", "_fileno");
        }

        if (target.result.os.tag == .windows) {
            tracy.root_module.linkSystemLibrary("ws2_32", .{});
            tracy.root_module.linkSystemLibrary("dbghelp", .{});
        }

        root_module.linkLibrary(tracy);
    }
}
