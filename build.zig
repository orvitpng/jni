const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const jdk = b.dependency("openjdk8", .{}).path("jdk/src");
    const jdk_os = switch (target.result.os.tag) {
        .windows => "windows",
        .macos => "macosx",
        else => "solaris", // Unix-like fallback
    };

    const module = b.addModule(
        "jni",
        .{ .root_source_file = b.path("src/module/mod.zig") },
    );
    module.addIncludePath(jdk.path(b, "share/javavm/export"));
    module.addIncludePath(jdk.path(b, jdk_os).path(b, "javavm/export"));
}

pub fn create_module(
    b: *std.Build,
    path: std.Build.LazyPath,
) *std.Build.Module {
    const self = b.dependencyFromBuildZig(@This(), .{});

    return b.createModule(.{
        .root_source_file = path,
        .imports = &.{
            .{
                .name = "jni",
                .module = self.module("jni"),
            },
        },
    });
}

pub fn link_wrapper(b: *std.Build, options: LinkWrapperOptions) void {
    const self = b.dependencyFromBuildZig(@This(), .{});

    for (options.exports) |item| {
        const config = b.addOptions();
        config.addOption([]const u8, "class_name", item.class);

        const run = b.addRunArtifact(b.addExecutable(.{
            .name = "codegen",
            .root_module = b.createModule(.{
                .target = b.graph.host,
                .root_source_file = self.path("src/codegen/main.zig"),
                .imports = &.{
                    .{
                        .name = "jni",
                        .module = self.module("jni"),
                    },
                    .{
                        .name = "config",
                        .module = config.createModule(),
                    },
                    .{
                        .name = "source",
                        .module = item.module,
                    },
                },
            }),
        }));
        const cg_path = run.addOutputFileArg("codegen.zig");

        options.link_to.addObject(b.addObject(.{
            .name = "wrapper",
            .pic = true,
            .root_module = b.createModule(.{
                .target = options.target,
                .optimize = options.optimize,
                .root_source_file = cg_path,
                .imports = &.{
                    .{
                        .name = "jni",
                        .module = self.module("jni"),
                    },
                    .{
                        .name = "source",
                        .module = item.module,
                    },
                },
            }),
        }));
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
