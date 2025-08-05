const config = @import("config");
const jni = @import("jni");
const source = @import("source");
const std = @import("std");

pub fn main() !void {
    const items = get_items();

    // var buf: [4096]u8 = undefined;
    // var bw = std.fs.File.stdout().writer(&buf);
    // defer bw.end() catch {};
    // var writer = bw.interface;
    const writer = std.fs.File.stdout().deprecatedWriter();

    try writer.writeAll(
        \\const jni = @import("jni");
        \\const wrapped = @import("wrapped");
        \\
        \\
    );
    inline for (items) |item| {
        try writer.print(
            \\export fn @"{s}"(
            \\    {s}: *jni.c.JNIEnv,
            \\    {s}: {s},
            \\
        , .{
            jni.escape("Java." ++
                config.class ++
                "." ++
                item.name),
            if (item.context != null) "env" else "_",
            if (item.context != null) "obj" else "_",
            switch (item.context orelse .static) {
                .static => "jni.c.jclass",
                .instance => "jni.c.jobject",
            },
        });
        for (item.start..item.len) |i|
            try writer.print(
                \\        @"{d}": {s}.params[{[0]d}].type.?,
                \\
            , .{ i, info_str(item.name) });
        try writer.print(if (item.returns_error)
            \\) @typeInfo({s}.return_type.?).error_union.payload {{
            \\    return wrapped.@"{s}"(
            \\
        else
            \\) {s}.return_type.? {{
            \\    return wrapped.@"{s}"(
            \\
        , .{ info_str(item.name), item.name });
        if (item.context != null)
            try writer.print(
                \\        .{{
                \\            .env = .{{ ._c = env }},
                \\            .{s} = .{{ ._c = obj }},
                \\        }},
                \\
            , .{if (item.context == .instance) "object" else "class"});
        for (item.start..item.len) |i|
            try writer.print(
                \\        @"{d}",
                \\
            , .{i});
        if (item.returns_error)
            try writer.print(
                \\    ) catch @panic("{s} returned an error")
            , .{item.name})
        else
            try writer.writeAll(")");
        try writer.writeAll(
            \\;
            \\}
            \\
        );
    }
}

inline fn get_items() []const Declaration {
    comptime {
        const decls = @typeInfo(source).@"struct".decls;
        var items: [decls.len]Declaration = undefined;
        for (decls, 0..) |decl, i| {
            const _info = @typeInfo(@TypeOf(@field(source, decl.name)));
            if (_info != .@"fn")
                @compileError("expected " ++ decl.name ++ " to be a function");
            const info = _info.@"fn";

            const context: ?ContextType = if (info.params.len != 0)
                if (info.params[0].type.? == jni.StaticContext)
                    .static
                else if (info.params[0].type.? == jni.InstanceContext)
                    .instance
                else
                    null
            else
                null;

            items[i] = .{
                .name = decl.name,
                .len = info.params.len,
                .start = if (context == null) 0 else 1,
                .context = context,
                .returns_error = @typeInfo(info.return_type.?) == .error_union,
            };
        }

        const copy = items;
        return &copy;
    }
}

inline fn info_str(comptime name: []const u8) []const u8 {
    return std.fmt.comptimePrint(
        \\@typeInfo(@TypeOf(@field(wrapped, "{s}"))).@"fn"
    , .{name});
}

const Declaration = struct {
    name: []const u8,
    len: usize,
    start: usize,
    context: ?ContextType,
    returns_error: bool,
};

const ContextType = enum {
    static,
    instance,
};
