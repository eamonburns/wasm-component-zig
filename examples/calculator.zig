pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub fn multiply(a: i32, b: i32) i32 {
    return a * b;
}

// comptime {
//     @export(&add, .{
//         .name = "cm32p2|example:calculator/operations|add",
//     });
//
//     @export(&multiply, .{
//         .name = "cm32p2|example:calculator/operations|multiply",
//     });
// }
