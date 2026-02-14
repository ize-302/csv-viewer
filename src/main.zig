const std = @import("std");
const pt = @import("prettytable");

const PaginationStruct = struct {
    items: u16 = 0,
};

const ArgStruct = struct {
    args: [][:0]u8,
    items: u16,

    pub fn init(args: [][:0]u8) ArgStruct {
        return ArgStruct{ .args = args, .items = 0 };
    }

    pub fn argumentHandler(self: *ArgStruct) PaginationStruct {
        if (std.mem.eql(u8, self.args[1][0..8], "--items=")) {
            self.items = std.fmt.parseInt(u16, self.args[1][8..], 10) catch unreachable;
        }
        return PaginationStruct{ .items = self.items };
    }
};

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var da = std.heap.DebugAllocator(.{}).init;
    defer _ = da.deinit();
    const allocator = da.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len == 1) {
        try std.Io.Writer.print(stdout, "Oops! specify a .csv file \n", .{});
        try stdout.flush();
        return;
    }

    if (args.len == 2) {
        try std.Io.Writer.print(stdout, "Specify number of items to show using flag --items=value \n", .{});
        try stdout.flush();
        return;
    }

    var args_init = ArgStruct.init(args[1..]);
    const pagination = args_init.argumentHandler();

    const file_path = args[1];
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    // read content
    var file_buffer: [4096]u8 = undefined;
    var reader = file.reader(&file_buffer);
    const reader_interface = &reader.interface;

    // Pretty table library
    var table = pt.Table.init(allocator);
    defer table.deinit();

    var all_rows = try std.ArrayList([][]const u8).initCapacity(allocator, 0);
    defer {
        for (all_rows.items) |row| {
            for (row) |cols| allocator.free(cols);
            allocator.free(row);
        }
        all_rows.deinit(allocator);
    }

    var counter: usize = 0;
    while (reader_interface.takeDelimiter('\n') catch |err| {
        if (err == error.ReadFailed) {
            try std.Io.Writer.print(stdout, "Fail to read file\n", .{});
        }
        if (err == error.StreamTooLong) {
            try std.Io.Writer.print(stdout, "File stream too long\n", .{});
        }
        try stdout.flush();
        return;
    }) |line| {
        if (counter <= pagination.items) {
            const row = try rowParser(allocator, line);
            try all_rows.append(allocator, row);
            counter += 1;
        }
    }

    for (all_rows.items, 0..) |row, i| {
        if (i == 0) try table.setTitle(row);
        if (i > 0) try table.addRow(row);
    }
    const go = [_][][]const u8{};
    try table.addRows(&go);
    try table.printstd();
}

fn rowParser(allocator: std.mem.Allocator, text: []const u8) ![][]const u8 {
    var row = try std.ArrayList([]const u8).initCapacity(allocator, 0);
    var in_quotes = false;
    var col = try std.ArrayList(u8).initCapacity(allocator, 0);
    defer col.deinit(allocator);

    // handle split of row into chunks of columns.
    for (text, 0..) |c, i| {
        if (c == '"' and !in_quotes) in_quotes = true;
        if (c == '"' and i + 1 < text.len and text[i + 1] == ',') in_quotes = false;
        if (c == '\r') continue; // skip carriage return
        if (c == ',' and !in_quotes) {
            const owned = try col.toOwnedSlice(allocator);
            try row.append(allocator, owned);
            col.clearRetainingCapacity();
        } else {
            try col.append(allocator, c);
        }
    }
    // last column
    if (col.items.len > 0) {
        // const owned = try col.toOwnedSlice(allocator);
        const owned = try allocator.dupe(u8, col.items);
        try row.append(allocator, owned);
    }
    return try row.toOwnedSlice(allocator);
}
