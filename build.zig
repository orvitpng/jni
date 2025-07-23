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

    const lib = b.addSharedLibrary(.{
        .name = "jni",
        .target = target,
        .optimize = b.standardOptimizeOption(.{}),
        .root_source_file = b.path("src/mod.zig"),
        .link_libc = true,
    });
    lib.addIncludePath(jdk.path(b, "share/javavm/export"));
    lib.addIncludePath(jdk.path(b, jdk_os).path(b, "javavm/export"));

    b.installArtifact(lib);
}
