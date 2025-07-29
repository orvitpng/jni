const std = @import("std");

pub const c = @import("c");

pub const Environment = @import("Environment.zig");
pub const Class = @import("Class.zig");
pub const Object = @import("Object.zig");

pub const int = c.jint;
pub const long = c.jlong;
pub const byte = c.jbyte;
pub const boolean = c.jboolean;
pub const char = c.jchar;
pub const short = c.jshort;
pub const float = c.jfloat;
pub const double = c.jdouble;
pub const object = c.jobject;

pub const size = int;
pub const class = object;
pub const throwable = object;
pub const string = object;
pub const array = object;
pub const boolean_array = array;
pub const byte_array = array;
pub const char_array = array;
pub const short_array = array;
pub const int_array = array;
pub const long_array = array;
pub const float_array = array;
pub const double_array = array;
pub const object_array = array;
pub const weak = object;

pub const StaticContext = struct {
    env: Environment,
    class: Class,
};
pub const InstanceContext = struct {
    env: Environment,
    object: Object,
};

pub fn Handle(comptime T: type) type {
    return struct {
        pub fn from_ptr(ptr: *T) long {
            return @bitCast(@intFromPtr(ptr));
        }

        pub fn to_ptr(handle: long) ?*T {
            if (handle == 0) return 0;
            return @ptrFromInt(@as(usize, @bitCast(handle)));
        }

        pub fn to_ptr_throw(env: Environment, handle: long) Error!?*T {
            const ptr = to_ptr(handle);
            if (ptr != null) return ptr;

            const cls =
                env.find_class("java/lang/NullPointerException") orelse
                unreachable;
            defer cls.delete_local_ref();

            try env.throw_new(cls, "Handle is null");
            return null;
        }
    };
}

pub const Boolean = enum(c_int) {
    false = 0,
    true = 1,

    pub fn from_bool(value: bool) Boolean {
        return if (value) .true else .false;
    }

    pub fn to_bool(self: Boolean) bool {
        return self == .true;
    }
};

pub const Version = enum(c_int) {
    v1_1 = c.JNI_VERSION_1_1, // 1.1
    v1_2 = c.JNI_VERSION_1_2, // 1.2, 1.3
    v1_4 = c.JNI_VERSION_1_4, // 1.4, 5.0
    v6 = c.JNI_VERSION_1_6, // 6, 7
    v8 = c.JNI_VERSION_1_8, // 8
    v9 = c.JNI_VERSION_9, // 9
    v10 = c.JNI_VERSION_10, // 10, 11, 12, 13, 14, 15, 16, 17, 18
    v19 = c.JNI_VERSION_19, // 19
    v20 = c.JNI_VERSION_20, // 20
    v21 = c.JNI_VERSION_21, // 21+
};

pub const Result = enum(c_int) {
    ok = c.JNI_OK,
    unknown = c.JNI_ERR,
    detached = c.JNI_EDETACHED,
    version = c.JNI_EVERSION,
    nomem = c.JNI_ENOMEM,
    exist = c.JNI_EEXIST,
    invalid = c.JNI_EINVAL,

    pub fn is_ok(self: Result) bool {
        return self == .ok;
    }

    pub fn check(self: Result) Error!void {
        if (self.is_ok()) return;
        switch (@intFromEnum(self)) {
            .unknown => return error.unknown,
            .detached => return error.detached,
            .version => return error.version,
            .nomem => return error.out_of_memory,
            .exist => return error.already_exists,
            .invalid => return error.invalid_argument,
        }
    }
};

pub const Error = error{
    unknown,
    detached,
    version,
    out_of_memory,
    already_exists,
    invalid_argument,
};
