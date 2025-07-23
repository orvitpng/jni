const std = @import("std");

pub const c = @cImport({
    @cInclude("jni.h");
});

// pub const Context = extern struct {
//     env: *c.JNIEnv,
//     class: c.jclass,
// };

pub fn bind(class: []const u8, from: type) void {
    const from_info = @typeInfo(from);
    if (from_info != .@"struct")
        @compileError("Expected a struct type for JNI binding");

    inline for (from_info.@"struct".decls) |decl| {
        const super = @field(from, decl.name);
        const func_info = @typeInfo(@TypeOf(super));
        if (func_info != .@"fn" or !func_info.@"fn".calling_convention.eql(.c))
            continue;

        // if (func_info.@"fn".params.len == 0 or
        //     func_info.@"fn".params[0].type.? != Context)
        //     @compileError("JNI functions must take in their Context as the" ++
        //         " first parameter");

        @export(&super, .{
            .name = escape("Java." ++ class ++ "." ++ decl.name),
            .linkage = .strong,
        });
    }
}

pub fn escape(str: []const u8) []const u8 {
    var size = 0;
    for (str) |ch|
        size += switch (ch) {
            '_', ';', '[' => 2,
            else => 1,
        };

    var buf: [size]u8 = undefined;
    var i = 0;
    for (str) |ch|
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
