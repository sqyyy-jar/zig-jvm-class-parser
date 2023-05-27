const std = @import("std");
const utils = @import("./utils.zig");
const print = std.debug.print;

pub const ClassFile = struct {
    const Self = @This();
    minor_version: u16,
    major_version: u16,
    constant_pool: std.ArrayList(ConstantPoolInfo),
    access_flags: u16,
    this_class: u16,
    super_class: u16,
    interfaces: std.ArrayList(u16),
    fields: std.ArrayList(FieldInfo),
    methods: std.ArrayList(MethodInfo),
    attributes: std.ArrayList(AttributeInfo),

    pub fn parse(bytes: []const u8, allocator: std.mem.Allocator) !Self {
        var reader = utils.ByteReader.init(bytes);
        const magic = try reader.readU32();
        if (magic != 0xcafebabe) {
            return error.InvalidMagic;
        }
        const minor_version = try reader.readU16();
        const major_version = try reader.readU16();
        const constant_pool_count = try reader.readU16() - 1;
        var constant_pool = std.ArrayList(ConstantPoolInfo).init(allocator);
        for (0..constant_pool_count) |_| {
            const constant_pool_info = try ConstantPoolInfo.parse(&reader, allocator);
            try constant_pool.append(constant_pool_info);
            if (constant_pool_info.isDoubleWidth()) {
                try constant_pool.append(.invalid);
            }
        }
        const access_flags = try reader.readU16();
        const this_class = try reader.readU16();
        const super_class = try reader.readU16();
        _ = minor_version;
        _ = major_version;
        _ = access_flags;
        _ = this_class;
        _ = super_class;
        std.os.exit(0);
        // return Self{
        //     .minor_version = minor_version,
        // };
    }
};

const ConstantPoolInfo = union(enum) {
    const Self = @This();
    utf_8: struct { bytes: []const u8 },
    integer: i32,
    float: f32,
    long: i64,
    double: f64,
    class: struct { name_index: u16 },
    string: struct { string_index: u16 },
    field_ref: struct { class_index: u16, name_and_type_index: u16 },
    method_ref: struct { class_index: u16, name_and_type_index: u16 },
    interface_method_ref: struct { class_index: u16, name_and_type_index: u16 },
    name_and_type: struct { name_index: u16, descriptor_index: u16 },
    method_handle: struct { ref_kind: u8, ref_index: u16 },
    method_type: struct { descriptor_index: u16 },
    dynamic: struct { bootstrap_method_attr_index: u16, name_and_type: u16 },
    invoke_dynamic: struct { bootstrap_method_attr_index: u16, name_and_type: u16 },
    module: struct { name_index: u16 },
    package: struct { name_index: u16 },
    invalid,

    pub fn parse(reader: *utils.ByteReader, allocator: std.mem.Allocator) !Self {
        const tag = try reader.readU8();
        switch (tag) {
            1 => {
                const length = try reader.readU16();
                var bytes = try allocator.alloc(u8, length);
                try reader.read(bytes);
                return .{ .utf_8 = .{ .bytes = bytes } };
            },
            3 => {
                const value = try reader.readU32();
                return .{ .integer = @bitCast(i32, value) };
            },
            4 => {
                const value = try reader.readU32();
                return .{ .float = @bitCast(f32, value) };
            },
            5 => {
                const value = try reader.readU64();
                return .{ .long = @bitCast(i64, value) };
            },
            6 => {
                const value = try reader.readU64();
                return .{ .double = @bitCast(f64, value) };
            },
            7 => {
                const name_index = try reader.readU16();
                return .{ .class = .{ .name_index = name_index } };
            },
            8 => {
                const string_index = try reader.readU16();
                return .{ .string = .{ .string_index = string_index } };
            },
            9 => {
                const class_index = try reader.readU16();
                const name_and_type_index = try reader.readU16();
                return .{ .field_ref = .{ .class_index = class_index, .name_and_type_index = name_and_type_index } };
            },
            10 => {
                const class_index = try reader.readU16();
                const name_and_type_index = try reader.readU16();
                return .{ .method_ref = .{ .class_index = class_index, .name_and_type_index = name_and_type_index } };
            },
            11 => {
                const class_index = try reader.readU16();
                const name_and_type_index = try reader.readU16();
                return .{ .interface_method_ref = .{ .class_index = class_index, .name_and_type_index = name_and_type_index } };
            },
            12 => {
                const name_index = try reader.readU16();
                const descriptor_index = try reader.readU16();
                return .{ .name_and_type = .{ .name_index = name_index, .descriptor_index = descriptor_index } };
            },
            15 => {
                const ref_kind = try reader.readU8();
                const ref_index = try reader.readU16();
                return .{ .method_handle = .{ .ref_kind = ref_kind, .ref_index = ref_index } };
            },
            16 => {
                const descriptor_index = try reader.readU16();
                return .{ .method_type = .{ .descriptor_index = descriptor_index } };
            },
            17 => {
                const bootstrap_method_attr_index = try reader.readU16();
                const name_and_type = try reader.readU16();
                return .{ .dynamic = .{ .bootstrap_method_attr_index = bootstrap_method_attr_index, .name_and_type = name_and_type } };
            },
            18 => {
                const bootstrap_method_attr_index = try reader.readU16();
                const name_and_type = try reader.readU16();
                return .{ .invoke_dynamic = .{ .bootstrap_method_attr_index = bootstrap_method_attr_index, .name_and_type = name_and_type } };
            },
            19 => {
                const name_index = try reader.readU16();
                return .{ .module = .{ .name_index = name_index } };
            },
            20 => {
                const name_index = try reader.readU16();
                return .{ .package = .{ .name_index = name_index } };
            },
            else => {
                print("illegal tag: {}\n", .{tag});
                @panic("Unimplemented tag");
            },
        }
    }

    pub fn isDoubleWidth(self: *const Self) bool {
        return switch (self.*) {
            ConstantPoolInfo.long => true,
            ConstantPoolInfo.double => true,
            else => false,
        };
    }
};

const FieldInfo = struct {};

const MethodInfo = struct {};

const AttributeInfo = struct {};

pub fn main() !void {
    _ = try ClassFile.parse(@embedFile("Test.class"), std.heap.page_allocator);
}
