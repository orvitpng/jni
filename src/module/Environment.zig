const Self = @This();
const root = @import("mod.zig");

c: *root.c.JNIEnv,

pub fn find_class(self: Self, class: [*:0]const u8) ?root.Class {
    const cls = self.c.*.*.FindClass.?(self.c, class);
    if (cls == null) return null;

    return root.Class{
        .owner = self.c,
        .c = cls,
    };
}

pub fn throw_new(self: Self, class: root.Class, msg: [*:0]const u8) void {
    _ = self.c.*.*.ThrowNew.?(self.c, class.c, msg);
}
