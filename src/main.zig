const std = @import("std");
const fs = std.fs;
const nbs = @import("lib/nbs.zig");

// Example usage
pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const allocator = std.heap.page_allocator;

    // Open the file
    const path = "./nyan_cat.nbs";
    const file = try fs.cwd().openFile(path, .{});
    defer file.close();

    // Get file size
    const stat = try file.stat();
    const buffer = try allocator.alloc(u8, stat.size);
    defer allocator.free(buffer);

    // Read the file into the buffer
    const size = try file.readAll(buffer);
    if (size != stat.size) {
        try stdout.print("Failed to read the file\n", .{});
    }

    // Parse the content
    var nbsParser = nbs.NBSParser.init(buffer);

    // Print the parsed content
    var nbsFile = try nbsParser.parse(allocator);
    defer nbsFile.deinit();
    try stdout.print("{}\n", .{nbsFile.header});

    // Iterate over notes and print them
    for (nbsFile.notes.items) |note| {
        try stdout.print("note: {d} {d} {d} {d} {d} {d} {d}\n", .{ note.tick, note.layer, note.instrument, note.key, note.velocity, note.panning, note.pitch });
    }
}
