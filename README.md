# zig-nbs

A fast and efficient Noteblock Studio (NBS) file parser written in Zig.

## Features

- Parses `.nbs` files used in OpenNoteBlockStudio and Minecraft Noteblock music.
- Provides an easy-to-use API for extracting song data.
- Lightweight and performant, leveraging Zig’s low-level control.

## Installation

To use `zig-nbs` in your Zig project, add it as a dependency in your `build.zig`:

```zig

```

## Usage

```zig
const std = @import("std");
const zig_nbs = @import("zig-nbs");

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
```

## Roadmap

- [ ] Implement support for different NBS versions.
- [ ] Add support for exporting parsed data.
- [ ] Optimize performance further.

## Contributing

Contributions are welcome! Feel free to open issues and pull requests.

## License

This project is licensed under the MIT License.
