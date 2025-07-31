const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    {
        const tracy_dep = b.dependency("tracy", .{
            .target = target,
            .optimize = optimize,
            .enable_tracy = !(b.option(bool, "disable-tracy", "") orelse false),
        });
        root_module.addImport("tracy", tracy_dep.module("tracy"));
    }

    {
        const exe = b.addExecutable(.{ .name = "example", .root_module = root_module });
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}
