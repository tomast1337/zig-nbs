const std = @import("std");
const mem = std.mem;
const expect = std.testing.expect;
const nbs = @import("nbs.zig");
const Parser = nbs.Parser;
const Writer = nbs.Writer;
const Header = nbs.Header;
const File = nbs.File;
const Note = nbs.Note;
const Layer = nbs.Layer;
const Instrument = nbs.Instrument;

test "Test numeric encoding and decoding" {
    const allocator = std.testing.allocator;
    var buffer: [4]u8 = undefined;
    const test_value: u32 = 42;
    mem.writeIntLittle(u32, &buffer, test_value);

    // Decode the value back
    const decoded_value = mem.readIntLittle(u32, &buffer);
    try expect(decoded_value == test_value);
}

test "Parse an NBS file" {
    const allocator = std.testing.allocator;

    var file = try std.fs.cwd().openFile("test.nbs", .{});
    defer file.close();

    var parser = Parser.init(file);
    const parsed_file = try parser.readFile();

    try expect(parsed_file.header.tempo == 10.0);
    try expect(parsed_file.header.version == 5);
    try expect(parsed_file.notes.len > 0);
}

test "Write an NBS file" {
    const allocator = std.testing.allocator;
    var file = try std.fs.cwd().createFile("output.nbs", .{});
    defer file.close();

    var writer = Writer.init(file);
    var test_file = File{
        .header = Header{ .tempo = 10.0 },
        .notes = &[_]Note{},
        .layers = &[_]Layer{},
        .instruments = &[_]Instrument{},
    };

    try writer.encodeFile(&test_file, 5);
    // You can re-read the file here and verify its correctness
}
