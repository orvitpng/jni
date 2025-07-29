const Self = @This();
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const jdk = b.dependency("openjdk", .{}).path("src/java.base");
    const jdk_os = switch (target.result.os.tag) {
        .macos => "macosx",
        .windows => "windows",
        else => "unix", // not guranateed, but safe fallback
    };

    const c = b.addTranslateC(.{
        .target = target,
        .optimize = b.standardOptimizeOption(.{}),
        .root_source_file = jdk.path(b, "share/native/include/jni.h"),
        .link_libc = true,
    });
    c.addIncludePath(jdk.path(b, "share/native/include"));
    c.addIncludePath(jdk.path(b, jdk_os).path(b, "native/include"));

    _ = b.addModule("jni", .{
        .root_source_file = b.path("src/module/mod.zig"),
        .imports = &.{
            .{
                .name = "c",
                .module = c.createModule(),
            },
        },
    });
}

pub fn create_module(
    b: *std.Build,
    options: CreateModuleOptions,
) *std.Build.Module {
    const self = b.dependencyFromBuildZig(Self, .{ .target = options.target });

    const module = b.createModule(.{
        .imports = options.imports,
        .root_source_file = options.root_source_file,
    });
    module.addImport("jni", self.module("jni"));

    return module;
}

pub fn codegen(b: *std.Build, item: Export) std.Build.LazyPath {
    const self = b.dependencyFromBuildZig(Self, .{});

    const config = b.addOptions();
    config.addOption([]const u8, "class_name", item.class);

    const exe = b.addExecutable(.{
        .name = "codegen",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .root_source_file = self.path("src/codegen/main.zig"),
            .imports = &.{
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
    });
    const run = b.addRunArtifact(exe);

    return run.addOutputFileArg("codegen.zig");
}

pub fn link_wrapper(b: *std.Build, options: LinkWrapperOptions) void {
    for (options.exports) |item| {
        const obj = b.addObject(.{
            .name = "wrapper",
            .root_module = b.createModule(.{
                .target = options.target,
                .optimize = options.optimize,
                .pic = true,
                .root_source_file = codegen(b, item),
                .imports = &.{
                    .{
                        .name = "jni",
                        .module = item.module.import_table.get("jni") orelse
                            @panic("jni module not generated with " ++
                                "create_module"),
                    },
                    .{
                        .name = "source",
                        .module = item.module,
                    },
                },
            }),
        });
        options.link_to.addObject(obj);
    }
}

pub const CreateModuleOptions = struct {
    target: std.Build.ResolvedTarget,
    root_source_file: std.Build.LazyPath,
    imports: []const std.Build.Module.Import = &.{},
};

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
