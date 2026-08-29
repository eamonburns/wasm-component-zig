//! usage: generate_glue <wit path> <world name> <output path>

const std = @import("std");
const Io = std.Io;

const wasm_component = @import("wasm_component.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const arena = init.arena.allocator();

    var args = try init.minimal.args.iterateAllocator(gpa);
    _ = args.skip(); // exe

    const wit_path = args.next() orelse return error.ExpectedArg;
    const world_name = args.next() orelse return error.ExpectedArg;
    const output_path = args.next() orelse return error.ExpectedArg;
    _ = world_name;

    const wit_source = try Io.Dir.cwd().readFileAlloc(io, wit_path, arena, .unlimited);
    const output_file = try Io.Dir.cwd().createFile(io, output_path, .{ .truncate = true });
    defer output_file.close(io);
    var output_buf: [1024]u8 = undefined;
    var output_writer = output_file.writer(io, &output_buf);
    const output = &output_writer.interface;

    var exports: std.ArrayList(Export) = .empty;
    defer exports.deinit(gpa);

    // TODO: Parse it!
    var line_it = std.mem.splitScalar(u8, wit_source, '\n');
    while (line_it.next()) |line| {
        if (line.len == 0) continue;
        const comma_idx = std.mem.findScalar(u8, line, ',') orelse {
            std.debug.print("error: didn't find comma in line: \"{s}\"\n", .{line});
            return error.MalformedWit;
        };
        try exports.append(gpa, .{ .func = .{
            .name = line[0..comma_idx],
            .nice_name = line[comma_idx + 1 ..],
            .param_list = &.{ .s32, .s32 },
            .return_list = .s32,
        } });
    }

    try output.writeAll(@embedFile("boilerplate.snippet.zig"));
    for (exports.items) |ex| {
        try ex.render(output);
    }
    try output.flush();
}

const Export = union(enum) {
    func: struct {
        name: []const u8,
        nice_name: []const u8,
        param_list: []const wasm_component.Type,
        return_list: wasm_component.Type,
    },

    pub fn render(ex: Export, writer: *Io.Writer) Io.Writer.Error!void {
        switch (ex) {
            .func => |func| {
                try writer.print(
                    \\
                    \\export fn {f}(
                , .{std.zig.fmtId(func.name)});
                for (func.param_list, 0..) |param, i| {
                    if (i != 0) try writer.writeAll(", ");
                    try writer.print("param_{d}: ", .{i});
                    try renderWasmComponentType(param, writer);
                }
                try writer.writeAll(") ");
                try renderWasmComponentType(func.return_list, writer);
                try writer.writeAll(" {");
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
                try writer.print(
                    \\
                    \\    return @call(.auto, impl.{f}, param_tuple);
                , .{std.zig.fmtId(func.nice_name)});
                try writer.writeAll(
                    \\
                    \\}
                );
            },
        }
    }
};

fn renderWasmComponentType(t: wasm_component.Type, writer: *Io.Writer) Io.Writer.Error!void {
    switch (t) {
        .u8, .u16, .u32, .u64 => try writer.writeAll(@tagName(t)),
        .s8, .s16, .s32, .s64 => {
            try writer.writeByte('i');
            try writer.writeAll(@tagName(t)[1..]);
        },
    }
}
