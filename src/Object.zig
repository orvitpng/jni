const c = @import("c");
const jni = @import("mod.zig");

_c: c.jobject,
_owner: ?jni.Environment = null,
