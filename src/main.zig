const std = @import("std");
const fs = std.fs;
const nbs = @import("lib/nbs.zig");

// Example usage
pub fn main() !void {
    std.io.getStdOut().write("Reading file...\n", .{});
    defer std.io.getStdOut().write("Done.\n", .{});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
