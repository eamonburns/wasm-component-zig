const std = @import("std");

const build_zig_zon = @import("build.zig.zon");

pub const WasmComponentOptions = struct {
    name: []const u8,
    /// Root module of the implementation.
    /// Must conain implementations of all functions exported by the component.
    /// (defined by `wit_path` and `world_name`)
    root_module: *std.Build.Module,
    /// Path to WIT package. Can either be a file or directory.
    wit_path: std.Build.LazyPath,
    /// Name of world within the WIT package
    world_name: []const u8,
    /// Path to a CSV table of `<mangled name>,<pretty name>` pairs
    /// TODO: Delete this (currently just a hack to avoid parsing WIT)
    hacky_not_wit_path: std.Build.LazyPath,
};

pub fn addWasmComponent(project: *std.Build, options: WasmComponentOptions) std.Build.LazyPath {
    const wasm_component = project; // TODO: Don't do this (get original project)

    // Create glue module
    const glue_mod = blk: {
        // TODO: const generate_glue_cmd = project.addRunArtifact(wasm_component.artifact("generate_glue"));
        const generate_cmd = project.addRunArtifact(generateGlueArtifact(wasm_component));
        generate_cmd.addArg(build_zig_zon.version);
        // TODO: pass options.wit_path
        generate_cmd.addFileArg(options.hacky_not_wit_path);
        generate_cmd.addArg(options.world_name);
        const glue_root_source_file = generate_cmd.addOutputFileArg(project.fmt("{s}.glue.zig", .{options.name}));
        const mod = project.createModule(.{
            .root_source_file = glue_root_source_file,
            // wasm32-freestanding
            .target = project.resolveTargetQuery(.{
                .cpu_arch = .wasm32,
                .os_tag = .freestanding,
            }),
            .optimize = .ReleaseSmall,
            .imports = &.{
                .{ .name = "@impl", .module = options.root_module },
                .{ .name = "@utils", .module = project.createModule(.{
                    .root_source_file = wasm_component.path("src/utils.zig"),
                }) },
            },
        });
        break :blk mod;
    };

    // Create core module
    const core_module_exe = project.addExecutable(.{
        .name = project.fmt("{s}.core", .{options.name}),
        .root_module = glue_mod,
    });
    core_module_exe.entry = .disabled;
    // Export all symbols (instead of manually specifying `--export=<symbol>` for all symbols)
    core_module_exe.rdynamic = true;

    // Embed WIT into core module
    const embedded_core_module = blk: {
        const embed_cmd = project.addSystemCommand(&.{ "wasm-tools", "component", "embed" });
        embed_cmd.addFileArg(options.wit_path);
        embed_cmd.addArgs(&.{ "--world", options.world_name });
        embed_cmd.addArtifactArg(core_module_exe);
        embed_cmd.addArg("--output");
        const result = embed_cmd.addOutputFileArg(
            project.fmt("{s}.embedded.wasm", .{options.name}),
        );
        break :blk result;
    };

    // Create WASM component
    const component_new_cmd = project.addSystemCommand(&.{ "wasm-tools", "component", "new" });
    component_new_cmd.addFileArg(embedded_core_module);
    component_new_cmd.addArg("--output");
    return component_new_cmd.addOutputFileArg(project.fmt("{s}.wasm", .{options.name}));
}

pub fn build(b: *std.Build) void {
    const calculator_component = addWasmComponent(b, .{
        .name = "calculator",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/calculator.zig"),
        }),
        .wit_path = b.path("examples/calculator.wit"),
        .hacky_not_wit_path = b.path("examples/calculator.not-wit"),
        .world_name = "calculator",
    });
    b.getInstallStep().dependOn(&b.addInstallFile(calculator_component, "calculator.wasm").step);

    const generate_glue_exe = generateGlueArtifact(b);
    b.installArtifact(generate_glue_exe);
}

fn generateGlueArtifact(b: *std.Build) *std.Build.Step.Compile {
    return b.addExecutable(.{
        .name = "generate_glue",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/generate_glue.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });
}
