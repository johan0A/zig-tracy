# zig-tracy

Library for instrumenting zig code for [Tracy 0.13.1](https://github.com/wolfpld/tracy).

## how to use

1. Add `tracy` to the dependency list in `build.zig.zon`:

```sh
zig fetch --save git+https://github.com/johan0A/zig-tracy
```

2. Config `build.zig`:

```zig
const tracy = b.dependency("tracy", .{
    .enable_tracy = b.option(bool, "enable_tracy", "Enable Tracy profile markers") orelse false,
    .enable_fibers = b.option(bool, "enable_fibers", "Enable Tracy fiber support") orelse false,
    .on_demand = b.option(bool, "on_demand", "Build tracy with TRACY_ON_DEMAND") orelse false,
    .callstack_support = b.option(bool, "callstack_support", "Builds tracy with TRACY_USE_CALLSTACK") orelse false,
    .default_callstack_depth = b.option(u32, "default_callstack_depth", "sets TRACY_CALLSTACK to the depth provided") orelse 0,
});
root_module.addImport("tracy", tracy.module("tracy"));
```

3. Add markers to your code:

```zig
fn baz() void {
    const zone = tracy.zone(@src());
    defer zone.end();
    foo();
    bar();
}
```

see more in depth example in the example directory.
