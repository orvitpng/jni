# jni

A library that makes JNI integration with Zig simple and straightforward. This
library is designed for Java 8 compatibility and provides a clean interface for
creating native methods.

Based on and with great inspiration from:
[SuperIceCN/zig-jni](https://github.com/SuperIceCN/zig-jni)

## Functions

### `bind`

The primary function for binding Zig functions to Java methods. It takes a Java
class name and a Zig struct containing functions with C calling conventions,
then exports them as a JNI method.

```zig
const MyNativeMethods = struct {
    pub fn processData(
        env: *jni.c.JNIEnv,
        class: jni.c.jclass
    ) callconv(.c) void {
        // implementation here
    }
    
    pub fn calculateValue(
        env: *jni.c.JNIEnv,
        class: jni.c.jclass,
        input: jni.c.jint,
    ) callconv(.c) jni.c.jint {
        return input * 2;
    }
};

comptime {
    jni.bind("com.example.MyClass", MyNativeMethods);
}
```

This creates native methods which can be called from Java:

```java
public class MyClass {
    public static native void processData();
    public static native int calculateValue(int input);
}
```

### `escape`

A utility function that converts Java method names/signatures to JNI-compatible
symbol names by escaping special characters according to JNI conventions.

The function handles the following character mappings:

* `_` becomes `_1`
* `;` becomes `_2`
* `[` becomes `_3`
* `.` becomes `_`

This function is used internally by `bind` but can also be called directly when
you need to manually construct JNI symbol names.
