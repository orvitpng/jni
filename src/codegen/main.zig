const config = @import("config");
const jni = @import("jni");
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
        if (params.len > 0) {
            if (params[0].type.? == jni.StaticContext)
                _ctx_type = .static
            else if (params[0].type.? == jni.InstanceContext)
                _ctx_type = .instance;
        }

        const i = std.fmt.comptimePrint("{d}", .{_i});
        const ctx_type = _ctx_type orelse .static;
        const has_ctx = _ctx_type != null;

        try out.writeAll(comptime std.fmt.comptimePrint(
            \\export fn {s}(
            \\    {s}: *jni.c.JNIEnv,
            \\    {s}: {s},
            \\
        , .{
            jni.escape("Java." ++ config.class_name ++ "." ++ decl.name),
            if (has_ctx) "env" else "_",
            if (has_ctx) "obj" else "_",
            switch (ctx_type) {
                .static => "jni.c.jclass",
                .instance => "jni.c.jobject",
            },
        }));
        try write_params(alloc, out.writer(), i, params, has_ctx);
        try out.writeAll(std.fmt.comptimePrint(
            \\) {s}.return_type.? {{
            \\
        , .{comptime info(i)}));
        if (has_ctx) try out.writeAll(std.fmt.comptimePrint(
            \\    const ctx = jni.{s}{{
            \\        .env = .{{ .c = env }},
            \\        .{s} = .{{ .c = obj }},
            \\    }};
            \\
        , .{
            if (ctx_type == .static) "StaticContext" else "InstanceContext",
            if (ctx_type == .static) "class" else "object",
        }));
        try out.writeAll(
            \\    return source.
        ++ decl.name ++
            \\(
            \\
        );
        try write_fn_params(alloc, out.writer(), params, has_ctx);
        try out.writeAll(
            \\    );
            \\}
            \\
        );
    }
}

fn write_params(
    alloc: std.mem.Allocator,
    writer: anytype,
    comptime decl_i: []const u8,
    params: []const std.builtin.Type.Fn.Param,
    has_ctx: bool,
) !void {
    if (params.len == 0 or !has_ctx and params.len == 1)
        return;

    const start: usize = if (has_ctx) 1 else 0;
    for (start.., params[start..]) |i, _| {
        const str = try std.fmt.allocPrint(alloc,
            \\    @"{[index]d}": {[info]s}.params[{[index]d}].type.?,
            \\
        , .{
            .index = i,
            .info = info(decl_i),
        });
        defer alloc.free(str);
        try writer.writeAll(str);
    }
}

fn write_fn_params(
    alloc: std.mem.Allocator,
    writer: anytype,
    params: []const std.builtin.Type.Fn.Param,
    has_ctx: bool,
) !void {
    if (has_ctx) try writer.writeAll(
        \\        ctx,
        \\
    );
    const start: usize = if (has_ctx) 1 else 0;
    for (start.., params[start..]) |i, _| {
        const str = try std.fmt.allocPrint(alloc,
            \\        @"{d}",
            \\
        , .{i});
        defer alloc.free(str);
        try writer.writeAll(str);
    }
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
