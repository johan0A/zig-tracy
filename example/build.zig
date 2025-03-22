const std = @import("std");

// Custom step for Tracy profiling
const TracyStep = struct {
    step: std.Build.Step,

    fn create(b: *std.Build) *TracyStep {
        const self = b.allocator.create(TracyStep) catch unreachable;
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = "open-tracy",
                .owner = b,
                .makeFn = make,
            }),
        };
        return self;
    }

    fn make(step: *std.Build.Step, _: std.Build.Step.MakeOptions) !void {
        var tracy_proc = std.process.Child.init(&.{ "tracy-profiler", "-a", "127.0.0.1" }, step.owner.allocator);
        tracy_proc.stdin_behavior = .Ignore;
        tracy_proc.stdout_behavior = .Inherit;
        tracy_proc.stderr_behavior = .Inherit;
        try tracy_proc.spawn();
    }
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const ztracy_dep = b.dependency("ztracy", .{
        .target = target,
        .optimize = optimize,
        .enable_tracing = !(b.option(bool, "disable-tracing", "") orelse false),
    });
    exe.root_module.addImport("tracy", ztracy_dep.module("tracy"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const tracy_step = TracyStep.create(b);
    tracy_step.step.dependOn(b.getInstallStep());

    const tracy_build_step = b.step("tracy", "Run the app then open the tracy gui from the PATH `tracy-profiler`");
    tracy_build_step.dependOn(&tracy_step.step);
    tracy_build_step.dependOn(&run_cmd.step);
}
