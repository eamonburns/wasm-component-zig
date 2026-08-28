fn add(a: i32, b: i32) callconv(.c) i32 {
    return a + b;
}

fn multiply(a: i32, b: i32) callconv(.c) i32 {
    return a * b;
}

comptime {
    @export(&add, .{
        .name = "cm32p2|example:calculator/operations|add",
    });

    @export(&multiply, .{
        .name = "cm32p2|example:calculator/operations|multiply",
    });
}
