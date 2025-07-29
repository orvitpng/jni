const Self = @This();
const c = @import("c");
const jni = @import("mod.zig");

_c: c.jclass,
_owner: ?jni.Environment = null,

/// Deletes the local reference to the class. This is necessary to prevent
/// leaks in JNI.
pub fn delete_local_ref(self: Self) void {
    const env = self.check_owner();
    env._delete_local_ref(self._c);
}

fn check_owner(self: Self) jni.Environment {
    if (self._owner == null)
        @compileError("no attached owner");
    return self._owner.?;
}
