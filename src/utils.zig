const std = @import("std");

pub const Ctx = struct {
    opts: Options,

    pub const Options = struct {
        memory: struct {
            ptr_type: type = i64,
        },
    };
};

pub fn FlattenType(comptime T: type, opts: Ctx.Options) type {
    switch (T) {
        bool => return struct { i32 },
        u8, i8, u16, i16, u32, i32 => return struct { i32 },
        u64, i64 => return struct { i64 },
        f32 => return struct { f32 },
        f64 => return struct { f64 },
        u21 => return struct { i32 },
        // TODO: Distinguish between strings?
        []const u8 => return struct { opts.memory.ptr_type, opts.memory.ptr_type },
        // TODO: ErrorContextType()
        else => switch (@typeInfo(T)) {
            .int => @compileError("unable to flatten integer with invalid size: " ++ @typeName(T)),
            .pointer => |ptr| if (ptr.sentinel_ptr == null) switch (ptr.size) {
                .slice => return FlattenList(ptr.child, null, opts),
                .many => @compileError("unable to flatten many-item pointer type: " ++ @typeName(T)),
                .one => @compileError("unable to flatten single-item pointer type: " ++ @typeName(T)),
                .c => @compileError("unable to flatten C pointer type: " ++ @typeName(T)),
            } else @compileError("unable to flatten sentinel-terminated pointer: " ++ @typeName(T)),
            // TODO: FlagsType(labels)
            .@"struct" => |s| return FlattenRecord(s.fields),
            .@"union" => |u| if (u.tag_type) |_| {
                return FlattenVariant(u.fields);
            } else @compileError("unable to flatten untagged union: " ++ @typeName(T)),
            .array => |arr| if (arr.sentinel_ptr == null) {
                return FlattenList(arr.child, arr.len, opts);
            } else @compileError("unable to flatten sentinel-terminated array: " ++ @typeName(T)),
            // TODO: OwnType() | BorrowType()
            // TODO: StreamType() | FutureType()
        },
    }
}

pub fn FlattenList(comptime ElemType: type, comptime maybe_length: ?usize, opts: Ctx.Options) type {
    _ = ElemType;
    _ = maybe_length;
    _ = opts;
    @compileError("TODO: FlattenList");
}

pub fn FlattenRecord(comptime fields: []const std.builtin.Type.StructField, opts: Ctx.Options) type {
    _ = fields;
    _ = opts;
    @compileError("TODO: FlattenRecord");
}

pub fn FlattenVariant(comptime cases: []const std.builtin.Type.UnionField, opts: Ctx.Options) type {
    _ = cases;
    _ = opts;
    @compileError("TODO: FlattenVariant");
}

pub fn lowerFlat(comptime ctx: Ctx, comptime T: type, value: T) FlattenType(T, ctx.opts) {
    _ = value;
}
