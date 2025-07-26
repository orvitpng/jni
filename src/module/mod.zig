const std = @import("std");

pub const c = @cImport({
    @cInclude("jni.h");
});

pub const Environment = @import("Environment.zig");
pub const Class = @import("Class.zig");
pub const Object = @import("Object.zig");

pub const StaticContext = struct {
    env: Environment,
    class: Class,
};
pub const InstanceContext = struct {
    env: Environment,
    object: Object,
};

pub fn escape(comptime str: []const u8) []const u8 {
    comptime var size = 0;
    inline for (str) |ch|
        size += switch (ch) {
            '_', ';', '[' => 2,
            else => 1,
        };

    var buf: [size]u8 = undefined;
    comptime var i = 0;
    inline for (str) |ch|
        switch (ch) {
            '_' => {
                buf[i] = '_';
                buf[i + 1] = '1';
                i += 2;
            },
            ';' => {
                buf[i] = '_';
                buf[i + 1] = '2';
                i += 2;
            },
            '[' => {
                buf[i] = '_';
                buf[i + 1] = '3';
                i += 2;
            },
            '.' => {
                buf[i] = '_';
                i += 1;
            },
            else => {
                buf[i] = ch;
                i += 1;
            },
        };

    return &buf;
}
