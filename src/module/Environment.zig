const Self = @This();
const c = @import("c");
const jni = @import("mod.zig");

_c: *c.JNIEnv,

/// Gets the JNI version of the environment.
pub fn get_version(self: Self) jni.Version {
    return @enumFromInt(self._c.*.*.GetVersion.?(self._c));
}

/// Finds a class by its name. The name should be in the format
/// "java/lang/String".
///
/// Returns `null` if the class is not found.
///
/// Needs to be freed with `delete_local_ref`.
pub fn find_class(self: Self, name: [*:0]const u8) ?jni.Class {
    const class = self._c.*.*.FindClass.?(self._c, name);
    if (class == null) return null;

    return jni.Class{
        ._c = class,
        ._owner = self,
    };
}

/// Throws a new exception of the given class with the provided message.
pub fn throw_new(
    self: Self,
    class: jni.class,
    message: [*:0]const u8,
) jni.Error!void {
    const result = self._c.*.*.ThrowNew.?(self._c, class, message);
    return jni.Result.check(@enumFromInt(result));
}

pub fn _delete_local_ref(self: Self, obj: jni.object) void {
    self._c.*.*.DeleteLocalRef.?(self._c, obj);
}
