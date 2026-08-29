const std = @import("std");

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
