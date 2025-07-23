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

    const module = b.addModule("jni", .{
        .target = target,
        .optimize = b.standardOptimizeOption(.{}),
        .root_source_file = b.path("src/mod.zig"),
    });
    module.addIncludePath(jdk.path(b, "share/javavm/export"));
    module.addIncludePath(jdk.path(b, jdk_os).path(b, "javavm/export"));
}
