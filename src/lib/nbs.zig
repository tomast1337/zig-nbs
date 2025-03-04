const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const sort = std.sort;

const CURRENT_NBS_VERSION = 5;

// Define the structs
const Instrument = struct {
    id: u32,
    name: []const u8,
    file: []const u8,
    pitch: u8 = 45,
    press_key: bool = true,
};

const Note = struct {
    tick: u32,
    layer: u32,
    instrument: u32,
    key: u8,
    velocity: u8 = 100,
    panning: i8 = 0,
    pitch: i16 = 0,
};

const Layer = struct {
    id: u32,
    name: []const u8 = "",
    lock: bool = false,
    volume: u8 = 100,
    panning: i8 = 0,
};

const Header = struct {
    version: u32 = CURRENT_NBS_VERSION,
    default_instruments: u32 = 16,
    song_length: u32 = 0,
    song_layers: u32 = 0,
    song_name: []const u8 = "",
    song_author: []const u8 = "",
    original_author: []const u8 = "",
    description: []const u8 = "",
    tempo: f32 = 10.0,
    auto_save: bool = false,
    auto_save_duration: u32 = 10,
    time_signature: u8 = 4,
    minutes_spent: u32 = 0,
    left_clicks: u32 = 0,
    right_clicks: u32 = 0,
    blocks_added: u32 = 0,
    blocks_removed: u32 = 0,
    song_origin: []const u8 = "",
    loop: bool = false,
    max_loop_count: u32 = 0,
    loop_start: u32 = 0,
};

const File = struct {
    header: Header,
    notes: []Note,
    layers: []Layer,
    instruments: []Instrument,

    pub fn updateHeader(self: *File, version: u32) void {
        self.header.version = version;
        if (self.notes.len > 0) {
            self.header.song_length = self.notes[self.notes.len - 1].tick;
        }
        self.header.song_layers = @as(u32, @intCast(self.layers.len));
    }

    pub fn save(self: *File, filename: []const u8, version: u32) !void {
        self.updateHeader(version);
        const file = try fs.cwd().createFile(filename, .{});
        defer file.close();
        const writer = file.writer();
        try Writer.encodeFile(writer, self, version);
    }

    pub fn iterateNotes(self: *const File) NoteIterator {
        return NoteIterator.init(self.notes);
    }
};

const NoteIterator = struct {
    notes: []const Note,
    index: usize = 0,

    pub fn init(notes: []const Note) NoteIterator {
        return NoteIterator{ .notes = notes };
    }

    pub fn next(self: *NoteIterator) ?struct { tick: u32, chord: []const Note } {
        if (self.index >= self.notes.len) return null;

        const current_tick = self.notes[self.index].tick;
        var chord = std.ArrayList(Note).init(std.heap.page_allocator);
        defer chord.deinit();

        while (self.index < self.notes.len and self.notes[self.index].tick == current_tick) {
            try chord.append(self.notes[self.index]);
            self.index += 1;
        }

        sort.sort(Note, chord.items, {}, struct {
            pub fn lessThan(_: void, a: Note, b: Note) bool {
                return a.layer < b.layer;
            }
        }.lessThan);

        return .{ .tick = current_tick, .chord = chord.items };
    }
};

const Parser = struct {
    file: fs.File,

    pub fn init(file: fs.File) Parser {
        return Parser{ .file = file };
    }

    pub fn readFile(self: *Parser) !File {
        const header = try self.parseHeader();
        const version = header.version;
        const notes = try self.parseNotes(version);
        const layers = try self.parseLayers(header.song_layers, version);
        const instruments = try self.parseInstruments(version);

        return File{
            .header = header,
            .notes = notes,
            .layers = layers,
            .instruments = instruments,
        };
    }

    fn readNumeric(self: *Parser, comptime T: type) !T {
        const size = @sizeOf(T);
        const buffer = try self.file.reader().readBytesNoEof(size);
        return mem.readIntLittle(T, buffer[0..size]);
    }

    fn readString(self: *Parser) ![]const u8 {
        const length = try self.readNumeric(u32);
        const buffer = try self.file.reader().readBytesNoEof(length);
        return buffer;
    }

    fn jump(self: *Parser) !std.ArrayList(u32) {
        var jumps = std.ArrayList(u32).init(std.heap.page_allocator);
        var value: u32 = 0;
        while (true) {
            const jump_val = try self.readNumeric(u16);
            if (jump_val == 0) break;
            value += jump_val;
            try jumps.append(value);
        }
        return jumps;
    }

    fn parseHeader(self: *Parser) !Header {
        const song_length = try self.readNumeric(u16);
        const version = if (song_length == 0) try self.readNumeric(u8) else 0;

        return Header{
            .version = version,
            .default_instruments = if (version > 0) try self.readNumeric(u8) else 10,
            .song_length = if (version >= 3) try self.readNumeric(u16) else song_length,
            .song_layers = try self.readNumeric(u16),
            .song_name = try self.readString(),
            .song_author = try self.readString(),
            .original_author = try self.readString(),
            .description = try self.readString(),
            .tempo = @as(f32, @floatFromInt(try self.readNumeric(u16))) / 100.0,
            .auto_save = try self.readNumeric(u8) == 1,
            .auto_save_duration = try self.readNumeric(u8),
            .time_signature = try self.readNumeric(u8),
            .minutes_spent = try self.readNumeric(u32),
            .left_clicks = try self.readNumeric(u32),
            .right_clicks = try self.readNumeric(u32),
            .blocks_added = try self.readNumeric(u32),
            .blocks_removed = try self.readNumeric(u32),
            .song_origin = try self.readString(),
            .loop = if (version >= 4) try self.readNumeric(u8) == 1 else false,
            .max_loop_count = if (version >= 4) try self.readNumeric(u8) else 0,
            .loop_start = if (version >= 4) try self.readNumeric(u16) else 0,
        };
    }

    fn parseNotes(self: *Parser, version: u32) ![]Note {
        var notes = std.ArrayList(Note).init(std.heap.page_allocator);
        const ticks = try self.jump();
        defer ticks.deinit();

        for (ticks.items) |tick| {
            const layers = try self.jump();
            defer layers.deinit();

            for (layers.items) |layer| {
                const instrument = try self.readNumeric(u8);
                const key = try self.readNumeric(u8);
                const velocity = if (version >= 4) try self.readNumeric(u8) else 100;
                const panning = if (version >= 4) try self.readNumeric(u8) - 100 else 0;
                const pitch = if (version >= 4) try self.readNumeric(i16) else 0;

                try notes.append(Note{
                    .tick = tick,
                    .layer = layer,
                    .instrument = instrument,
                    .key = key,
                    .velocity = velocity,
                    .panning = panning,
                    .pitch = pitch,
                });
            }
        }

        return notes.toOwnedSlice();
    }

    fn parseLayers(self: *Parser, layers_count: u32, version: u32) ![]Layer {
        var layers = std.ArrayList(Layer).init(std.heap.page_allocator);
        var i: u32 = 0;
        while (i < layers_count) : (i += 1) {
            const name = try self.readString();
            const lock = if (version >= 4) try self.readNumeric(u8) == 1 else false;
            const volume = try self.readNumeric(u8);
            const panning = if (version >= 2) try self.readNumeric(u8) - 100 else 0;

            try layers.append(Layer{
                .id = i,
                .name = name,
                .lock = lock,
                .volume = volume,
                .panning = panning,
            });
        }
        return layers.toOwnedSlice();
    }

    fn parseInstruments(self: *Parser) ![]Instrument {
        const count = try self.readNumeric(u8);
        var instruments = std.ArrayList(Instrument).init(std.heap.page_allocator);
        var i: u32 = 0;
        while (i < count) : (i += 1) {
            const name = try self.readString();
            const file = try self.readString();
            const pitch = try self.readNumeric(u8);
            const press_key = try self.readNumeric(u8) == 1;

            try instruments.append(Instrument{
                .id = i,
                .name = name,
                .file = file,
                .pitch = pitch,
                .press_key = press_key,
            });
        }
        return instruments.toOwnedSlice();
    }
};

const Writer = struct {
    file: fs.File,

    pub fn init(file: fs.File) Writer {
        return Writer{ .file = file };
    }

    pub fn encodeFile(self: *Writer, nbs_file: *const File, version: u32) !void {
        try self.writeHeader(nbs_file, version);
        try self.writeNotes(nbs_file, version);
        try self.writeLayers(nbs_file, version);
        try self.writeInstruments(nbs_file, version);
    }

    fn encodeNumeric(self: *Writer, comptime T: type, value: T) !void {
        var buffer: [@sizeOf(T)]u8 = undefined;
        mem.writeIntLittle(T, &buffer, value);
        try self.file.writer().writeAll(&buffer);
    }

    fn encodeString(self: *Writer, value: []const u8) !void {
        try self.encodeNumeric(u32, @as(u32, @intCast(value.len)));
        try self.file.writer().writeAll(value);
    }

    fn writeHeader(self: *Writer, nbs_file: *const File, version: u32) !void {
        const header = nbs_file.header;

        if (version > 0) {
            try self.encodeNumeric(u16, 0);
            try self.encodeNumeric(u8, version);
            try self.encodeNumeric(u8, header.default_instruments);
        } else {
            try self.encodeNumeric(u16, header.song_length);
        }
        if (version >= 3) {
            try self.encodeNumeric(u16, header.song_length);
        }
        try self.encodeNumeric(u16, header.song_layers);
        try self.encodeString(header.song_name);
        try self.encodeString(header.song_author);
        try self.encodeString(header.original_author);
        try self.encodeString(header.description);

        try self.encodeNumeric(u16, @as(u16, @intFromFloat(header.tempo * 100)));
        try self.encodeNumeric(u8, @as(u8, @intFromBool(header.auto_save)));
        try self.encodeNumeric(u8, header.auto_save_duration);
        try self.encodeNumeric(u8, header.time_signature);

        try self.encodeNumeric(u32, header.minutes_spent);
        try self.encodeNumeric(u32, header.left_clicks);
        try self.encodeNumeric(u32, header.right_clicks);
        try self.encodeNumeric(u32, header.blocks_added);
        try self.encodeNumeric(u32, header.blocks_removed);
        try self.encodeString(header.song_origin);

        if (version >= 4) {
            try self.encodeNumeric(u8, @as(u8, @intFromBool(header.loop)));
            try self.encodeNumeric(u8, header.max_loop_count);
            try self.encodeNumeric(u16, header.loop_start);
        }
    }

    fn writeNotes(self: *Writer, nbs_file: *const File, version: u32) !void {
        var current_tick: u32 = 0;
        var iter = nbs_file.iterateNotes();

        while (iter.next()) |group| {
            try self.encodeNumeric(u16, group.tick - current_tick);
            current_tick = group.tick;
            var current_layer: u32 = 0;

            for (group.chord) |note| {
                try self.encodeNumeric(u16, note.layer - current_layer);
                current_layer = note.layer;
                try self.encodeNumeric(u8, note.instrument);
                try self.encodeNumeric(u8, note.key);
                if (version >= 4) {
                    try self.encodeNumeric(u8, note.velocity);
                    try self.encodeNumeric(u8, @as(u8, @intCast(note.panning + 100)));
                    try self.encodeNumeric(i16, note.pitch);
                }
            }

            try self.encodeNumeric(u16, 0);
        }
        try self.encodeNumeric(u16, 0);
    }

    fn writeLayers(self: *Writer, nbs_file: *const File, version: u32) !void {
        for (nbs_file.layers) |layer| {
            try self.encodeString(layer.name);
            if (version >= 4) {
                try self.encodeNumeric(u8, @as(u8, @intFromBool(layer.lock)));
            }
            try self.encodeNumeric(u8, layer.volume);
            if (version >= 2) {
                try self.encodeNumeric(u8, @as(u8, @intCast(layer.panning + 100)));
            }
        }
    }

    fn writeInstruments(self: *Writer, nbs_file: *const File) !void {
        try self.encodeNumeric(u8, @as(u8, @intCast(nbs_file.instruments.len)));
        for (nbs_file.instruments) |instrument| {
            try self.encodeString(instrument.name);
            try self.encodeString(instrument.file);
            try self.encodeNumeric(u8, instrument.pitch);
            try self.encodeNumeric(u8, @as(u8, @intFromBool(instrument.press_key)));
        }
    }
};
