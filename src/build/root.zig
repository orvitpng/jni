const config = @import("config");
const jni = @import("jni");

comptime {
    jni.bind(config.class_name, @import("source"));
}
