pub const ByteReader = struct {
    const Self = @This();
    bytes: []const u8,
    index: usize,

    pub fn init(bytes: []const u8) Self {
        return Self{
            .bytes = bytes,
            .index = 0,
        };
    }

    pub fn readU8(self: *Self) !u8 {
        if (self.index >= self.bytes.len) {
            return error.UnexpectedEof;
        }
        const value = self.bytes[self.index];
        self.index += 1;
        return value;
    }

    pub fn readU16(self: *Self) !u16 {
        const upper: u16 = try self.readU8();
        const lower: u16 = try self.readU8();
        return (upper << 8) | lower;
    }

    pub fn readU32(self: *Self) !u32 {
        const a: u32 = try self.readU8();
        const b: u32 = try self.readU8();
        const c: u32 = try self.readU8();
        const d: u32 = try self.readU8();
        return (a << 24) | (b << 16) | (c << 8) | d;
    }

    pub fn readU64(self: *Self) !u64 {
        const a: u64 = try self.readU8();
        const b: u64 = try self.readU8();
        const c: u64 = try self.readU8();
        const d: u64 = try self.readU8();
        const e: u64 = try self.readU8();
        const f: u64 = try self.readU8();
        const g: u64 = try self.readU8();
        const h: u64 = try self.readU8();
        return (a << 56) |
            (b << 48) |
            (c << 40) |
            (d << 32) |
            (e << 24) |
            (f << 16) |
            (g << 8) |
            h;
    }

    pub fn read(self: *Self, dst: []u8) !void {
        for (0..dst.len) |i| {
            const byte = try self.readU8();
            dst[i] = byte;
        }
    }
};
