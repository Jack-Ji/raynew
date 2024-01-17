#!/bin/bash

set -e

if ! which zig > /dev/null ; then
    echo "Please install zig compiler (https://ziglang.org/download)"
    exit 1
fi

if ! which git > /dev/null ; then
    echo "Please install git (https://https://git-scm.com)"
    exit 1
fi

if [ $# -ne 1 ]; then
    echo "Usage: ray.sh <name-of-new-game>"
    exit 1
fi

GAME=$1
if [ -e $GAME ]; then
    echo "Directory or file '$GAME' already exists!"
    exit 1
fi

mkdir -p $GAME && cd $GAME
mkdir src
mkdir external
git init
git submodule add --depth 1 https://github.com/raysan5/raylib external/raylib
git submodule add --depth 1 https://github.com/raysan5/raygui external/raygui
cat > .gitignore <<EOF
*.o
*.tmp
*.temp
*.swp
zig-cache
zig-out
EOF
cat > build.zig <<EOF
const std = @import("std");
const ray = @import("external/raylib/src/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "$GAME",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    // Link raylib
    const raylib = ray.addRaylib(b, target, optimize, .{
        .raygui = true,
    }) catch unreachable;
    exe.linkLibrary(raylib);
    exe.addIncludePath(.{ .path = "external/raylib/src/" });
    exe.addIncludePath(.{ .path = "external/raygui/src/" });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the game");
    run_step.dependOn(&run_cmd.step);
}
EOF
cat > src/main.zig <<EOF
const std = @import("std");
const raylib = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rcamera.h");
    @cInclude("rlgl.h");
    @cInclude("raygui.h");
});

pub fn main() !void {
    const width = 400;
    const height = 300;
    const fontsize = 16;
    const fps = 60;

    raylib.InitWindow(width, height, "$GAME");
    raylib.SetTargetFPS(fps);
    defer raylib.CloseWindow();

    const text = "Your game is ready!";
    const textwidth = raylib.MeasureText(text, fontsize);
    while (!raylib.WindowShouldClose()) {
        raylib.BeginDrawing();
        defer raylib.EndDrawing();

        raylib.ClearBackground(raylib.WHITE);
        raylib.DrawFPS(0, 0);
        raylib.DrawText(
            text,
            @divTrunc(width - textwidth, 2),
            @divTrunc(height - fontsize, 2),
            fontsize,
            raylib.BLACK,
        );
    }
}
EOF
zig fmt build.zig src/main.zig
git add . && git commit -am "first commit"
cd - > /dev/null
echo
echo "Init game '$GAME' successfully, have fun!"
