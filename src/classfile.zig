const std = @import("std");
const print = std.debug.print;
const utils = @import("./utils.zig");
const classfile = @import("./classfile.zig");

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
            const constant_pool_info = try ConstantPoolInfo.parse(&reader);
            try constant_pool.append(constant_pool_info);
            if (constant_pool_info.isDoubleWidth()) {
                try constant_pool.append(.invalid);
            }
        }
        const access_flags = try reader.readU16();
        const this_class = try reader.readU16();
        const super_class = try reader.readU16();
        const interfaces_count = try reader.readU16();
        var interfaces = std.ArrayList(u16).init(allocator);
        for (0..interfaces_count) |_| {
            const index = try reader.readU16();
            try interfaces.append(index);
        }
        const fields_count = try reader.readU16();
        var fields = std.ArrayList(FieldInfo).init(allocator);
        for (0..fields_count) |_| {
            const field = try FieldInfo.parse(&reader, allocator);
            try fields.append(field);
        }
        const methods_count = try reader.readU16();
        var methods = std.ArrayList(MethodInfo).init(allocator);
        for (0..methods_count) |_| {
            const method = try MethodInfo.parse(&reader, allocator);
            try methods.append(method);
        }
        const attributes_count = try reader.readU16();
        var attributes = std.ArrayList(AttributeInfo).init(allocator);
        for (0..attributes_count) |_| {
            const attribute = try AttributeInfo.parse(&reader, allocator);
            try attributes.append(attribute);
        }
        return Self{
            .minor_version = minor_version,
            .major_version = major_version,
            .constant_pool = constant_pool,
            .access_flags = access_flags,
            .this_class = this_class,
            .super_class = super_class,
            .interfaces = interfaces,
            .fields = fields,
            .methods = methods,
            .attributes = attributes,
        };
    }
};

pub const ConstantPoolInfo = union(enum) {
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

    pub fn parse(reader: *utils.ByteReader) !Self {
        const tag = try reader.readU8();
        switch (tag) {
            1 => {
                const length = try reader.readU16();
                const bytes = try reader.slice(length);
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
                print("Illegal tag: {}\n", .{tag});
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

pub const FieldInfo = struct {
    const Self = @This();
    access_flags: u16,
    name_index: u16,
    descriptor_index: u16,
    attributes: std.ArrayList(AttributeInfo),

    pub fn parse(reader: *utils.ByteReader, allocator: std.mem.Allocator) !Self {
        const access_flags = try reader.readU16();
        const name_index = try reader.readU16();
        const descriptor_index = try reader.readU16();
        const attributes_count = try reader.readU16();
        var attributes = std.ArrayList(AttributeInfo).init(allocator);
        for (0..attributes_count) |_| {
            const attribute = try AttributeInfo.parse(reader, allocator);
            try attributes.append(attribute);
        }
        return Self{
            .access_flags = access_flags,
            .name_index = name_index,
            .descriptor_index = descriptor_index,
            .attributes = attributes,
        };
    }
};

pub const MethodInfo = struct {
    const Self = @This();
    access_flags: u16,
    name_index: u16,
    descriptor_index: u16,
    attributes: std.ArrayList(AttributeInfo),

    pub fn parse(reader: *utils.ByteReader, allocator: std.mem.Allocator) !Self {
        const access_flags = try reader.readU16();
        const name_index = try reader.readU16();
        const descriptor_index = try reader.readU16();
        const attributes_count = try reader.readU16();
        var attributes = std.ArrayList(AttributeInfo).init(allocator);
        for (0..attributes_count) |_| {
            const attribute = try AttributeInfo.parse(reader, allocator);
            try attributes.append(attribute);
        }
        return Self{
            .access_flags = access_flags,
            .name_index = name_index,
            .descriptor_index = descriptor_index,
            .attributes = attributes,
        };
    }
};

pub const AttributeInfo = union(enum) {
    const Self = @This();
    generic: struct { attribute_name_index: u16, data: []const u8 },

    pub fn parse(reader: *utils.ByteReader, allocator: std.mem.Allocator) !Self {
        const attribute_name_index = try reader.readU16();
        const attribute_length = try reader.readU32();
        const data = try reader.slice(attribute_length);
        _ = allocator;
        return .{ .generic = .{ .attribute_name_index = attribute_name_index, .data = data } };
    }
};
