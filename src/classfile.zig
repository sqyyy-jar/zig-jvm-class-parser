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

    pub fn debug(self: *const Self, indent: usize) void {
        utils.debug_indent(indent);
        print("minor_version: {}\n", .{self.minor_version});
        utils.debug_indent(indent);
        print("major_version: {}\n", .{self.major_version});
        utils.debug_indent(indent);
        print("constant_pool:\n", .{});
        for (self.constant_pool.items, 0..) |constant_pool_info, i| {
            constant_pool_info.debug(indent + 1, i + 1);
        }
        utils.debug_indent(indent);
        print("access_flags: {}\n", .{self.access_flags});
        utils.debug_indent(indent);
        print("this_class: {}\n", .{self.this_class});
        utils.debug_indent(indent);
        print("super_class: {}\n", .{self.super_class});
        utils.debug_indent(indent);
        print("interfaces:\n", .{});
        for (self.interfaces.items) |interface| {
            utils.debug_indent(indent + 1);
            print("{}\n", .{interface});
        }
        print("fields:\n", .{});
        for (self.fields.items) |field| {
            field.debug(indent + 1);
        }
        print("methods:\n", .{});
        for (self.methods.items) |method| {
            method.debug(indent + 1);
        }
        print("attributes:\n", .{});
        for (self.attributes.items) |attribute| {
            attribute.debug(indent + 1);
        }
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
            .long => true,
            .double => true,
            else => false,
        };
    }

    pub fn debug(self: *const Self, indent: usize, index: usize) void {
        utils.debug_indent(indent);
        switch (self.*) {
            .utf_8 => |utf_8| {
                print("#{}: utf-8: \"{s}\"\n", .{ index, utf_8.bytes });
            },
            .class => |class| {
                print("#{}: class:\n", .{index});
                utils.debug_indent(indent + 1);
                print("name_index: {}\n", .{class.name_index});
            },
            .method_ref => |method_ref| {
                print("#{}: method_ref:\n", .{index});
                utils.debug_indent(indent + 1);
                print("class_index: {}\n", .{method_ref.class_index});
                utils.debug_indent(indent + 1);
                print("name_and_type_index: {}\n", .{method_ref.name_and_type_index});
            },
            .name_and_type => |name_and_type| {
                print("#{}: name_and_type:\n", .{index});
                utils.debug_indent(indent + 1);
                print("name_index: {}\n", .{name_and_type.name_index});
                utils.debug_indent(indent + 1);
                print("descriptor_index: {}\n", .{name_and_type.descriptor_index});
            },
            .invalid => {},
            else => {
                print("#{}: unimplemented: {any}\n", .{ index, self });
            },
        }
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

    pub fn debug(self: *const Self, indent: usize) void {
        utils.debug_indent(indent);
        print("field:\n", .{});
        utils.debug_indent(indent + 1);
        print("access_flags: {}\n", .{self.access_flags});
        utils.debug_indent(indent + 1);
        print("name_index: {}\n", .{self.name_index});
        utils.debug_indent(indent + 1);
        print("descriptor_index: {}\n", .{self.descriptor_index});
        utils.debug_indent(indent + 1);
        print("attributes:\n", .{});
        for (self.attributes.items) |attribute| {
            attribute.debug(indent + 2);
        }
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

    pub fn debug(self: *const Self, indent: usize) void {
        utils.debug_indent(indent);
        print("method:\n", .{});
        utils.debug_indent(indent + 1);
        print("access_flags: {}\n", .{self.access_flags});
        utils.debug_indent(indent + 1);
        print("name_index: {}\n", .{self.name_index});
        utils.debug_indent(indent + 1);
        print("descriptor_index: {}\n", .{self.descriptor_index});
        utils.debug_indent(indent + 1);
        print("attributes:\n", .{});
        for (self.attributes.items) |attribute| {
            attribute.debug(indent + 2);
        }
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

    pub fn debug(self: *const Self, indent: usize) void {
        switch (self.*) {
            .generic => |generic| {
                utils.debug_indent(indent);
                print("generic:\n", .{});
                utils.debug_indent(indent + 1);
                print("attribute_name_index: {}\n", .{generic.attribute_name_index});
            },
        }
    }
};
