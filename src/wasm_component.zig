const std = @import("std");
const Io = std.Io;

pub const Type = union(enum) {
    u8,
    u16,
    u32,
    u64,
    s8,
    s16,
    s32,
    s64,
    // TODO: More types

    pub fn format(
        t: Type,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        switch (t) {
            .u8, .u16, .u32, .u64 => try writer.writeAll(@tagName(t)),
            .s8, .s16, .s32, .s64 => {
                try writer.writeByte('i');
                try writer.writeAll(@tagName(t)[1..]);
            },
        }
    }
};

pub const Export = union(enum) {
    func: Func,

    pub const Func = struct {
        name: []const u8,
        nice_name: []const u8,
        param_list: []const Type,
        return_list: Type,

        pub fn fmtType(func: Func) Fmt(.type) {
            return .{ .func = func };
        }

        pub fn fmtSignature(func: Func) Fmt(.signature) {
            return .{ .func = func };
        }

        pub fn Fmt(comptime mode: enum { type, signature }) type {
            return struct {
                func: Func,
                const Self = @This();

                pub fn format(
                    self: Self,
                    writer: *std.Io.Writer,
                ) std.Io.Writer.Error!void {
                    try writer.writeAll("fn ");
                    if (mode == .signature) {
                        try writer.print("{f}", .{std.zig.fmtId(self.func.name)});
                    }
                    try writer.writeAll("(");
                    for (self.func.param_list, 0..) |param, i| {
                        if (i != 0) try writer.writeAll(", ");
                        switch (mode) {
                            .type => try writer.print("{f}", .{param}),
                            .signature => try writer.print("param_{d}: {f}", .{ i, param }),
                        }
                    }
                    try writer.print(") {f}", .{self.func.return_list});
                }
            };
        }
    };

    pub fn render(ex: Export, writer: *Io.Writer) Io.Writer.Error!void {
        switch (ex) {
            .func => |func| {
                try writer.print(
                    \\
                    \\const {[name]s}_impl = blk: {{
                    \\    if (!@hasDecl(impl, "{[name]s}")) @compileError("No function \"{[name]s}\" in implementation module");
                    \\    if (@TypeOf(impl.{[name_id]f}) != {[func_type]f}) @compileError("Function impl.{[name_id]f} is of incorrect type. Expected " ++ @typeName({[func_type]f}) ++ " but found " ++ @typeName(@TypeOf(impl.{[name_id]f})));
                    \\    break :blk impl.{[name_id]f};
                    \\}};
                , .{
                    .name = func.nice_name,
                    .name_id = std.zig.fmtId(func.nice_name),
                    .func_type = func.fmtType(),
                });

                // Function signature
                try writer.print(
                    \\
                    \\export {f} {{
                , .{func.fmtSignature()});

                // Function body
                try writer.writeAll(
                    \\
                    \\    const param_tuple = .{
                );
                for (0..func.param_list.len) |i| {
                    try writer.print(
                        \\
                        \\        param_{d},
                    , .{i});
                }
                try writer.writeAll(
                    \\
                    \\    };
                );
                // TODO: Lift param_tuple to component types
                // TODO: Lower return value to core type
                try writer.print(
                    \\
                    \\    return @call(.auto, {s}_impl, param_tuple);
                    // NOTE: could be: `return lowerFlat(Return, @call(.auto, impl.{f}, liftFlat(Params, param_tuple)))`
                , .{func.nice_name});
                try writer.writeAll(
                    \\
                    \\}
                );
            },
        }
    }
};
