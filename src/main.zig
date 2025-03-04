const std = @import("std");
const fs = std.fs;
const nbs = @import("lib/nbs.zig");

// Example usage
pub fn main() !void {
    const file = try fs.cwd().openFile("example.nbs", .{});
    defer file.close();

    const parser = nbs.Parser.init(file);
    const nbs_file = try parser.readFile();

    try nbs_file.save("output.nbs", nbs.CURRENT_NBS_VERSION);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
