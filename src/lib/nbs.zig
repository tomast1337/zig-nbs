const std = @import("std");

pub const CURRENT_NBS_VERSION: u8 = 5;

pub const Instrument = struct {
    id: u8,
    name: []const u8,
    file: []const u8,
    pitch: u8 = 45, // default: 45
    press_key: bool = true, // default: true

    pub fn init(id: u8, name: []const u8, file: []const u8) Instrument {
        return Instrument{
            .id = id,
            .name = name,
            .file = file,
        };
    }
};

pub const Note = struct {
    tick: u16,
    layer: u16,
    instrument: u8,
    key: u8,
    velocity: u8 = 100, // default: 100
    panning: i8 = 0, // default: 0 (actual value = stored byte - 100)
    pitch: i16 = 0, // default: 0

    pub fn init(tick: u16, layer: u16, instrument: u8, key: u8) Note {
        return Note{
            .tick = tick,
            .layer = layer,
            .instrument = instrument,
            .key = key,
        };
    }
};

pub const Layer = struct {
    id: u16,
    name: []const u8 = "", // empty string by default
    lock: bool = false, // default: false
    volume: u8 = 100, // default: 100
    panning: i8 = 0, // default: 0

    pub fn init(id: u16) Layer {
        return Layer{
            .id = id,
        };
    }
};

pub const Header = struct {
    version: u8 = CURRENT_NBS_VERSION, // defaults to CURRENT_NBS_VERSION if not overridden
    default_instruments: u8 = 16, // default: 16
    song_length: u16 = 0, // default: 0
    song_layers: u16 = 0, // default: 0
    song_name: []const u8 = "", // default: ""
    song_author: []const u8 = "", // default: ""
    original_author: []const u8 = "", // default: ""
    description: []const u8 = "", // default: ""
    tempo: u16 = 0, // default: 10.0
    auto_save: bool = false, // default: false
    auto_save_duration: u8 = 10, // default: 10
    time_signature: u8 = 4, // default: 4
    minutes_spent: u32 = 0, // default: 0
    left_clicks: u32 = 0, // default: 0
    right_clicks: u32 = 0, // default: 0
    blocks_added: u32 = 0, // default: 0
    blocks_removed: u32 = 0, // default: 0
    song_origin: []const u8 = "", // default: ""
    loop: bool = false, // default: false
    max_loop_count: u8 = 0, // default: 0
    loop_start: u16 = 0, // default: 0

    pub fn init() Header {
        return Header{};
    }
};

pub const NbsFile = struct {
    header: Header,
    notes: []Note,
    layers: []Layer,
    instruments: []Instrument,

    /// Updates the header based on the notes and layers.
    pub fn updateHeader(self: *NbsFile, version: u8) void {
        self.header.version = version;
        if (self.notes.len > 0) {
            self.header.song_length = self.notes[self.notes.len - 1].tick;
        }
        self.header.song_layers = @as(u16, self.layers.len);
    }

    pub fn save(self: *NbsFile, filename: []const u8, version: u8) !void {
        self.updateHeader(version);
        var fs = std.fs.cwd();
        var file = try fs.createFile(filename, .{});
        defer file.close();
    }
};

pub const NBSParser = struct {
    file_data: []const u8,

    pub fn parse(self: *NBSParser) !NbsFile {
        const header = try self.parseHeader();
        const notes = try self.parseNotes();
        const layers = try self.parseLayers();
        const instruments = try self.parseInstruments();
        const file = NbsFile{
            .header = header,
            .notes = notes,
            .layers = layers,
            .instruments = instruments,
        };
        return file;
    }

    fn readU16(bytes: []const u8) u16 {
        return bytes[0] | (@as(u16, bytes[1]) << 8);
    }

    fn readU32(bytes: []const u8) u32 {
        return bytes[0] | (@as(u32, bytes[1]) << 8) | (@as(u32, bytes[2]) << 16) | (@as(u32, bytes[3]) << 24);
    }

    fn readString(bytes: *[]const u8) ![]const u8 {
        const len = NBSParser.readU32(bytes.*);
        bytes.* = bytes.*[4..];
        const str = bytes.*[0..len];
        bytes.* = bytes.*[len..];
        return str;
    }

    fn parseHeader(self: *NBSParser) !Header {
        var header_bytes = self.file_data[2..];
        const version: u8 = CURRENT_NBS_VERSION;
        header_bytes = header_bytes[1..];

        const default_instruments: u8 = header_bytes[0];
        header_bytes = header_bytes[1..];
        const song_length: u16 = NBSParser.readU16(header_bytes);
        header_bytes = header_bytes[2..];
        const song_layers: u16 = NBSParser.readU16(header_bytes);
        header_bytes = header_bytes[2..];

        const song_name = try NBSParser.readString(&header_bytes);
        const song_author = try NBSParser.readString(&header_bytes);
        const original_author = try NBSParser.readString(&header_bytes);
        const description = try NBSParser.readString(&header_bytes);

        const tempo: u16 = NBSParser.readU16(header_bytes);
        header_bytes = header_bytes[2..];

        const auto_save: bool = header_bytes[0] != 0;
        header_bytes = header_bytes[1..];

        const auto_save_duration: u8 = header_bytes[0];
        header_bytes = header_bytes[1..];

        const time_signature: u8 = header_bytes[0];
        header_bytes = header_bytes[1..];

        const minutes_spent: u32 = NBSParser.readU32(header_bytes);
        header_bytes = header_bytes[4..];

        const left_clicks: u32 = NBSParser.readU32(header_bytes);
        header_bytes = header_bytes[4..];

        const right_clicks: u32 = NBSParser.readU32(header_bytes);
        header_bytes = header_bytes[4..];

        const blocks_added: u32 = NBSParser.readU32(header_bytes);
        header_bytes = header_bytes[4..];

        const blocks_removed: u32 = NBSParser.readU32(header_bytes);
        header_bytes = header_bytes[4..];

        const song_origin = try NBSParser.readString(&header_bytes);

        const loop: bool = header_bytes[0] != 0;
        header_bytes = header_bytes[1..];

        const max_loop_count: u8 = header_bytes[0];
        header_bytes = header_bytes[1..];

        const loop_start: u16 = NBSParser.readU16(header_bytes);
        header_bytes = header_bytes[2..];

        return Header{
            .version = version,
            .default_instruments = default_instruments,
            .song_length = song_length,
            .song_layers = song_layers,
            .song_name = song_name,
            .song_author = song_author,
            .original_author = original_author,
            .description = description,
            .tempo = tempo,
            .auto_save = auto_save,
            .auto_save_duration = auto_save_duration,
            .time_signature = time_signature,
            .minutes_spent = minutes_spent,
            .left_clicks = left_clicks,
            .right_clicks = right_clicks,
            .blocks_added = blocks_added,
            .blocks_removed = blocks_removed,
            .song_origin = song_origin,
            .loop = loop,
            .max_loop_count = max_loop_count,
            .loop_start = loop_start,
        };
    }

    fn parseNotes(self: *NBSParser) ![]Note {
        const notes: []Note = blk: {
            var initial_notes: [10]Note = undefined;
            for (&initial_notes, 0..) |*note, i| {
                note.* = Note{
                    .tick = @intCast(i),
                    .layer = @intCast(i),
                    .instrument = 1,
                    .key = 60,
                };
            }
            break :blk initial_notes[0..];
        };

        // get one byte of data
        const version = self.file_data[0];
        std.debug.print("version: {d}\n", .{version});

        return notes;
    }

    fn parseLayers(self: *NBSParser) ![]Layer {
        const layers: []Layer = blk: {
            var initial_layers: [10]Layer = undefined;
            for (&initial_layers, 0..) |*layer, i| {
                layer.* = Layer{
                    .id = @intCast(i),
                    .name = "Layer",
                    .lock = false,
                    .volume = 100,
                    .panning = 0,
                };
            }
            break :blk initial_layers[0..];
        };

        // get one byte of data
        const version = self.file_data[0];
        std.debug.print("version: {d}\n", .{version});

        return layers;
    }

    fn parseInstruments(self: *NBSParser) ![]Instrument {
        const instruments: []Instrument = blk: {
            var initial_instruments: [10]Instrument = undefined;
            for (&initial_instruments, 0..) |*instrument, i| {
                instrument.* = Instrument{
                    .id = @intCast(i),
                    .name = "Instrument",
                    .file = "file",
                };
            }
            break :blk initial_instruments[0..];
        };

        // get one byte of data
        const version = self.file_data[0];
        std.debug.print("version: {d}\n", .{version});

        return instruments;
    }
};

test "parses nyan_cat.nb" {
    const fileContents = @embedFile("./test-files/nyan_cat.nbs");
    std.debug.print("testing with nyan_cat.nbs length: {d} bytes\n", .{fileContents.len});

    var parser = NBSParser{ .file_data = fileContents };
    const file = try parser.parse();
    std.debug.print("Song Name: {s} Song Author: {s}\n", .{ file.header.song_name, file.header.song_author });
    std.debug.print("Notes: {d}\n", .{file.notes.len});
    std.debug.print("Notes: {d}\n", .{file.notes.len});
    std.debug.print("Layers: {d}\n", .{file.layers.len});
    std.debug.print("Instruments: {d}\n", .{file.instruments.len});
}
