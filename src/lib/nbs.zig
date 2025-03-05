const std = @import("std");

pub const CURRENT_NBS_VERSION: u8 = 5;

pub const Instrument = struct {
    id: u8,
    name: []const u8,
    file: []const u8,
    pitch: u8 = 45, // default: 45
    press_key: bool = true, // default: true
};

pub const Note = struct {
    tick: u16,
    layer: u16,
    instrument: u8,
    key: u8,
    velocity: u8 = 100, // default: 100
    panning: i8 = 0, // default: 0 (actual value = stored byte - 100)
    pitch: i16 = 0, // default: 0
};

pub const Layer = struct {
    id: u16,
    name: []const u8 = "", // empty string by default
    lock: bool = false, // default: false
    volume: u8 = 100, // default: 100
    panning: i8 = 0, // default: 0
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
    tempo: f32 = 0, // default: 10.0
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

test "opens nbstest.nbs" {
    const fileContents = @embedFile("./test-files/nyan_cat.nbs");
    std.debug.print("Len: {d}", .{fileContents.len});
    // print the first 512 bytes
    std.debug.print("{s}", .{fileContents[0..512]});
}
