const std = @import("std");
const print = std.debug.print;
const classfile = @import("./classfile.zig");

pub fn main() !void {
    const class_file = try classfile.ClassFile.parse(@embedFile("Test.class"), std.heap.page_allocator);
    class_file.debug(0);
}
