const std = @import("std");

pub const WasmComponentOptions = struct {
    name: []const u8,
    root_module: *std.Build.Module,
    wit_path: std.Build.LazyPath,
    world_name: []const u8,
};
pub fn addWasmComponent(project: *std.Build, options: WasmComponentOptions) std.Build.LazyPath {
    // Create core module
    const wasm_core_module = project.addExecutable(.{
        .name = project.fmt("{s}.core", .{options.name}),
        .root_module = options.root_module,
    });
    wasm_core_module.root_module.export_symbol_names = &.{
        // TODO: Generate export symbols from WIT
        "cm32p2|example:calculator/operations|add",
        "cm32p2|example:calculator/operations|multiply",
    };
    wasm_core_module.entry = .disabled;
    wasm_core_module.root_module.strip = true;

    // Embed WIT into core module
    const component_embed_cmd = project.addSystemCommand(&.{ "wasm-tools", "component", "embed" });
    component_embed_cmd.addFileArg(options.wit_path);
    component_embed_cmd.addArgs(&.{ "--world", options.world_name });
    component_embed_cmd.addArtifactArg(wasm_core_module);
    component_embed_cmd.addArg("--output");
    const embedded_core_module = component_embed_cmd.addOutputFileArg(project.fmt("{s}.embedded.wasm", .{options.name}));

    // Create WASM component
    const component_new_cmd = project.addSystemCommand(&.{ "wasm-tools", "component", "new" });
    component_new_cmd.addFileArg(embedded_core_module);
    component_new_cmd.addArg("--output");
    return component_new_cmd.addOutputFileArg(project.fmt("{s}.wasm", .{options.name}));
}

pub fn build(b: *std.Build) void {
    const calculator_mod = b.addModule("calculator", .{
        .root_source_file = b.path("examples/calculator.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        }),
        .optimize = .ReleaseSmall,
    });

    const calculator_component = addWasmComponent(b, .{
        .name = "calculator",
        .root_module = calculator_mod,
        .wit_path = b.path("examples/calculator.wit"),
        .world_name = "calculator",
    });
    const install_component = b.addInstallFile(calculator_component, "calculator.wasm");
    b.getInstallStep().dependOn(&install_component.step);

    const mod_tests = b.addTest(.{
        .root_module = calculator_mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
