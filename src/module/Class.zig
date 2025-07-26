const Self = @This();
const root = @import("mod.zig");

owner: ?*root.c.JNIEnv = null,
c: root.c.jclass,

pub fn deinit(self: Self) void {
    if (self.owner == null)
        @panic("destroying class without attached owner");
    self.owner.?.*.*.DeleteLocalRef.?(self.owner, self.c);
}
