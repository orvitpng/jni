const config = @import("config");
const source = @import("source");
const std = @import("std");

pub fn main() !void {
    var debug = std.heap.DebugAllocator(.{}).init;
    defer _ = debug.deinit();
    const alloc = debug.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    _ = args.skip();

    const out_path = args.next().?;
    const out = try std.fs.createFileAbsolute(out_path, .{});
    defer out.close();

    try out.writeAll(
        \\const jni = @import("jni");
        \\const source = @import("source");
        \\const std = @import("std");
        \\
        \\const decls = @typeInfo(source).@"struct".decls;
        \\
        \\// generated
        \\
    );
    inline for (0.., @typeInfo(source).@"struct".decls) |_i, decl| {
        const func = @field(source, decl.name);
        const _fn_info = @typeInfo(@TypeOf(func));
        if (_fn_info != .@"fn")
            @compileError("exported declaration " ++
                decl.name ++
                " is not a function");
        const fn_info = _fn_info.@"fn";
        const params = fn_info.params;

        comptime var _ctx_type: ?ContextType = null;
        if (params.len > 0 and params[0].type != null) {
            const ctx_info = @typeInfo(params[0].type.?);
            if (ctx_info == .@"struct") {
                if (ctx_info.@"struct".fields.len == 2) {
                    // there's probably a better way to do this that works on
                    // all types, but i frankly couldn't be fucked to make this
                    // codegen actually decent.
                    if (comptime std.mem.eql(
                        u8,
                        ctx_info.@"struct".fields[1].name,
                        "class",
                    )) _ctx_type = .static else if (comptime std.mem.eql(
                        u8,
                        ctx_info.@"struct".fields[1].name,
                        "object",
                    )) _ctx_type = .instance;
                }
            }
        }

        const i = std.fmt.comptimePrint("{d}", .{_i});
        const ctx_type = _ctx_type orelse .static;
        const has_ctx = _ctx_type != null;

        const ret_info = @typeInfo(fn_info.return_type.?);
        const err = ret_info == .error_union;

        try out.writeAll(comptime std.fmt.comptimePrint(
            \\export fn {s}(
            \\    {s}: *jni.c.JNIEnv,
            \\    {s}: {s},
            \\
        , .{
            escape("Java." ++ config.class_name ++ "." ++ decl.name),
            if (has_ctx) "env" else "_",
            if (has_ctx) "obj" else "_",
            switch (ctx_type) {
                .static => "jni.c.jclass",
                .instance => "jni.c.jobject",
            },
        }));
        try write_params(out.writer(), i, params, has_ctx);
        try out.writeAll(std.fmt.comptimePrint(if (err)
            \\) @typeInfo({s}.return_type.?).error_union.payload {{
            \\
        else
            \\) {s}.return_type.? {{
            \\
        , .{comptime info(i)}));
        try out.writeAll(
            \\    return source.
        ++ decl.name ++
            \\(
            \\
        );
        if (has_ctx) try out.writeAll(
            \\        .{
            \\            .env = .{ ._c = env },
            \\            .
        ++ (if (ctx_type == .static) "class" else "object") ++
            \\ = .{ ._c = obj },
            \\        },
            \\
        );
        try write_fn_params(out.writer(), params, has_ctx);
        try out.writeAll(if (err)
            \\    ) catch @panic("
        ++ decl.name ++
            \\ returned an error union");
            \\}
            \\
        else
            \\    );
            \\}
            \\
        );
    }
}

fn write_params(
    writer: anytype,
    comptime decl_i: []const u8,
    params: []const std.builtin.Type.Fn.Param,
    has_ctx: bool,
) !void {
    if (params.len == 0 or !has_ctx and params.len == 1)
        return;

    const start: usize = if (has_ctx) 1 else 0;
    for (start.., params[start..]) |i, _|
        try std.fmt.format(writer,
            \\    @"{[index]d}": {[info]s}.params[{[index]d}].type.?,
            \\
        , .{
            .index = i,
            .info = info(decl_i),
        });
}

fn write_fn_params(
    writer: anytype,
    params: []const std.builtin.Type.Fn.Param,
    has_ctx: bool,
) !void {
    const start: usize = if (has_ctx) 1 else 0;
    for (start.., params[start..]) |i, _|
        try std.fmt.format(writer,
            \\        @"{d}",
            \\
        , .{i});
}

fn info(comptime i: []const u8) []const u8 {
    return "@typeInfo(@TypeOf(@field(source, decls[" ++
        i ++
        "].name))).@\"fn\"";
}

const ContextType = enum {
    static,
    instance,
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
