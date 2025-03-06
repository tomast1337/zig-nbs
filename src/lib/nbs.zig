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
    notes: std.ArrayList(Note),
    layers: std.ArrayList(Layer),
    instruments: std.ArrayList(Instrument),

    pub fn deinit(self: *NbsFile) void {
        self.notes.deinit();
        self.layers.deinit();
        self.instruments.deinit();
    }

    /// Updates the header based on the notes and layers.
    pub fn updateHeader(self: *NbsFile, version: u8) void {
        self.header.version = version;
        if (self.notes.items.len > 0) {
            self.header.song_length = self.notes.items[self.notes.items.len - 1].tick;
        }
        self.header.song_layers = @as(u16, self.layers.items.len);
    }

    pub fn save(self: *NbsFile, filename: []const u8, version: u8) !void {
        self.updateHeader(version);
        var fs = std.fs.cwd();
        var file = try fs.createFile(filename, .{});
        defer file.close();
        // TODO: Implement file writing logic
    }
};

pub const NBSParser = struct {
    file_data: []const u8,
    current_data: []const u8,

    pub fn init(file_data: []const u8) NBSParser {
        return NBSParser{
            .file_data = file_data,
            .current_data = file_data,
        };
    }

    pub fn parse(self: *NBSParser, allocator: std.mem.Allocator) !NbsFile {
        const header = try self.parseHeader();
        const notes = try self.parseNotes(allocator);
        const layers = try self.parseLayers(allocator);
        const instruments = try self.parseInstruments(allocator);
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

    fn readI16(bytes: []const u8) i16 {
        return bytes[0] | (@as(i16, bytes[1]) << 8);
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

        self.current_data = header_bytes;

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

    fn parseNotes(self: *NBSParser, allocator: std.mem.Allocator) !std.ArrayList(Note) {
        var notes = std.ArrayList(Note).init(allocator);
        var current_tick: u16 = 0;

        while (true) {
            const jump_ticks = NBSParser.readU16(self.current_data);
            self.current_data = self.current_data[2..];
            if (jump_ticks == 0) break;

            current_tick += jump_ticks;

            while (true) {
                const jump_layers = NBSParser.readU16(self.current_data);
                self.current_data = self.current_data[2..];
                if (jump_layers == 0) break;

                const instrument = self.current_data[0];
                self.current_data = self.current_data[1..];
                const key = self.current_data[0];
                self.current_data = self.current_data[1..];

                const velocity = self.current_data[0];
                self.current_data = self.current_data[1..];
                const panning = @as(i8, @bitCast(self.current_data[0])) - 100;
                self.current_data = self.current_data[1..];
                const pitch = NBSParser.readI16(self.current_data);
                self.current_data = self.current_data[2..];

                try notes.append(Note{
                    .tick = current_tick,
                    .layer = jump_layers,
                    .instrument = instrument,
                    .key = key,
                    .velocity = velocity,
                    .panning = panning,
                    .pitch = pitch,
                });
            }
        }

        return notes;
    }

    fn parseLayers(self: *NBSParser, allocator: std.mem.Allocator) !std.ArrayList(Layer) {
        var layers = std.ArrayList(Layer).init(allocator);
        var layer_id: u16 = 0;

        while (true) {
            const name = try NBSParser.readString(&self.current_data);
            if (name.len == 0) break;

            const lock = self.current_data[0] != 0;
            self.current_data = self.current_data[1..];
            const volume = self.current_data[0];
            self.current_data = self.current_data[1..];
            const panning = @as(i8, @bitCast(self.current_data[0])) - 100;
            self.current_data = self.current_data[1..];

            try layers.append(Layer{
                .id = layer_id,
                .name = name,
                .lock = lock,
                .volume = volume,
                .panning = panning,
            });

            layer_id += 1;
        }

        return layers;
    }

    fn parseInstruments(self: *NBSParser, allocator: std.mem.Allocator) !std.ArrayList(Instrument) {
        self.current_data = self.current_data;
        const instrument_list = std.ArrayList(Instrument).init(allocator);
        return instrument_list;
    }
};

test "parses nyan_cat.nbs" {
    const allocator = std.testing.allocator;

    const fileContents = @embedFile("./test-files/nyan_cat.nbs");
    std.debug.print("testing with nyan_cat.nbs length: {d} bytes\n", .{fileContents.len});

    var parser = NBSParser.init(fileContents);
    var file = try parser.parse(allocator);
    defer file.deinit();

    try std.testing.expect(file.header.version == 5);
    try std.testing.expect(std.mem.eql(u8, file.header.song_name, "Nyan Cat"));
    try std.testing.expect(std.mem.eql(u8, file.header.song_author, "chenxi050402"));
    try std.testing.expect(std.mem.eql(u8, file.header.description, "\"Nyan Cat\" recreated in note blocks by chenxi050402."));
    try std.testing.expect(std.mem.eql(u8, file.header.original_author, ""));
    try std.testing.expect(std.mem.eql(u8, file.header.song_origin, ""));

    try std.testing.expect(file.header.auto_save == false);
    try std.testing.expect(file.header.loop == true);

    try std.testing.expect(file.header.default_instruments == 16);
    try std.testing.expect(file.header.auto_save_duration == 10);
    try std.testing.expect(file.header.time_signature == 8);
    try std.testing.expect(file.header.max_loop_count == 0);

    try std.testing.expect(file.header.song_length == 670);
    try std.testing.expect(file.header.song_layers == 36);
    try std.testing.expect(file.header.tempo == 1893);
    try std.testing.expect(file.header.loop_start == 160);

    try std.testing.expect(file.header.minutes_spent == 32);
    try std.testing.expect(file.header.left_clicks == 1207);
    try std.testing.expect(file.header.right_clicks == 32);
    try std.testing.expect(file.header.blocks_added == 212);
    try std.testing.expect(file.header.blocks_removed == 27);

    // iterate over notes and print them
    for (file.notes.items) |note| {
        std.debug.print("note: {d} {d} {d} {d} {d} {d} {d}\n", .{ note.tick, note.layer, note.instrument, note.key, note.velocity, note.panning, note.pitch });
    }
}
