const std = @import("std");

pub fn build(b: *std.Build) void {
    const jdk = b.dependency("openjdk8", .{}).path("jdk/src");
    const jdk_os = switch (b.standardTargetOptions(.{}).result.os.tag) {
        .windows => "windows",
        .macos => "macosx",
        // basically all other Unix-like systems
        else => "solaris",
    };

    const module = b.addModule(
        "jni",
        .{ .root_source_file = b.path("src/mod.zig") },
    );
    module.addIncludePath(jdk.path(b, "share/javavm/export"));
    module.addIncludePath(jdk.path(b, jdk_os).path(b, "javavm/export"));
}

pub fn create_module(
    b: *std.Build,
    path: std.Build.LazyPath,
) *std.Build.Module {
    const self = b.dependencyFromBuildZig(@This(), .{});

    const module = b.createModule(.{ .root_source_file = path });
    module.addImport("jni", self.module("jni"));

    return module;
}

pub fn link_wrapper(
    b: *std.Build,
    class: []const u8,
    module: *std.Build.Module,
    to: *std.Build.Module,
    options: LinkOptions,
) void {
    const self = b.dependencyFromBuildZig(@This(), .{});
    const write = b.addWriteFiles();

    _ = write.add("codegen.zig", "pub const class = \"Hello, world!!\";");
    const root = write.add("root.zig", std.fmt.allocPrint(
        b.allocator,
        @embedFile("build/root.zig.tmpl"),
        .{class},
    ) catch @panic("OOM"));

    const obj = b.addObject(.{
        .name = "jni_wrapper",
        .root_source_file = root,
        .target = options.target,
        .optimize = options.optimize,
    });
    obj.root_module.addImport("jni", self.module("jni"));
    obj.root_module.addImport("source", module);

    to.addObject(obj);
}

const LinkOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};
