# jni

This is built using Zig 0.14.1.

A library that makes JNI integration with Zig simple and straightforward. This
library is designed for Java 8 compatibility and provides a clean interface for
creating native methods.

Documentation is planned to be written some time in the future. For now, view
`build.zig` to see the functions used to allow for zero-cost abstraction from
the C JNI interface.

Based on and with great inspiration from:
[SuperIceCN/zig-jni](https://github.com/SuperIceCN/zig-jni)
