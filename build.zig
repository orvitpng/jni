const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const jdk = b.dependency("openjdk8", .{}).path("jdk/src");
    const jdk_os = switch (target.result.os.tag) {
        .windows => "windows",
        .macos => "macosx",
        // basically all other Unix-like systems
        else => "solaris",
    };

    const module = b.addModule(
        "jni",
        .{ .root_source_file = b.path("src/module/mod.zig") },
    );
    module.addIncludePath(jdk.path(b, "share/javavm/export"));
    module.addIncludePath(jdk.path(b, jdk_os).path(b, "javavm/export"));

    _ = b.addExecutable(.{
        .name = "codegen",
        .root_source_file = b.path("src/codegen/main.zig"),
        .target = target,
        .optimize = b.standardOptimizeOption(.{}),
    });
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

pub fn link_wrapper(b: *std.Build, options: LinkWrapperOptions) void {
    const self = b.dependencyFromBuildZig(@This(), .{});

    for (options.exports) |item| {
        const write = b.addWriteFiles();
        const config = b.addOptions();
        config.addOption([]const u8, "class_name", item.class);

        const root = write.addCopyFile(
            self.path("src/build/root.zig"),
            "root.zig",
        );
        _ = write.add("codegen.zig", "");

        const obj = b.addObject(.{
            .name = "wrapper",
            .root_source_file = root,
        });
        obj.root_module.addImport("jni", self.module("jni"));
        obj.root_module.addImport("config", config.createModule());
        obj.root_module.addImport("source", item.module);

        options.link_to.addObject(obj);
    }
}

pub const LinkWrapperOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    link_to: *std.Build.Module,
    exports: []const Export,
};

pub const Export = struct {
    class: []const u8,
    module: *std.Build.Module,
};
