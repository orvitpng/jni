const Self = @This();
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const jdk = b.dependency("openjdk", .{}).path("src/java.base");
    const jdk_os = switch (target.result.os.tag) {
        .windows => "windows",
        else => "unix", // not guranateed, but safe fallback
    };

    const c = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = jdk.path(b, "share/native/include/jni.h"),
        .link_libc = true,
    });
    c.addIncludePath(jdk.path(b, "share/native/include"));
    c.addIncludePath(jdk.path(b, jdk_os).path(b, "native/include"));

    _ = b.addModule("jni", .{
        .root_source_file = b.path("src/mod.zig"),
        .imports = &.{
            .{ .name = "c", .module = c.createModule() },
        },
    });
}

pub fn link(b: *std.Build, options: CreateObjectOptions) void {
    for (options.exports) |item| {
        const obj = b.addObject(.{
            .name = "wrapper",
            .root_module = codegen(
                b,
                options.target,
                options.optimize,
                item.class,
                item.module,
            ),
        });
        options.link_to.addObject(obj);
    }
}

fn codegen(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    class: []const u8,
    module: *std.Build.Module,
) *std.Build.Module {
    const self = b.dependencyFromBuildZig(Self, .{});

    const config = b.addOptions();
    config.addOption([]const u8, "class", class);

    const exe = b.addExecutable(.{
        .name = "codegen",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .root_source_file = self.path("build/codegen.zig"),
            .imports = &.{
                // currently, this causes issues with mod.zig being included
                // multiple times, so we must do this hack which won't work all
                // the time unfortunately
                // .{ .name = "jni", .module = self.module("jni") },
                .{ .name = "jni", .module = module.import_table.get("jni").? },
                .{ .name = "config", .module = config.createModule() },
                .{ .name = "source", .module = module },
            },
        }),
    });
    const run = b.addRunArtifact(exe);

    const stdout = run.captureStdOut();
    run.captured_stdout.?.basename = "stdout.zig";

    return b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = stdout,
        .imports = &.{
            // .{ .name = "jni", .module = self.module("jni") },
            .{ .name = "jni", .module = module.import_table.get("jni").? },
            .{ .name = "wrapped", .module = module },
        },
    });
}

const CreateObjectOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    link_to: *std.Build.Module,
    exports: []const Export,
};

const Export = struct {
    class: []const u8,
    module: *std.Build.Module,
};
