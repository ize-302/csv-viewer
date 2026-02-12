const std = @import("std");
const pt = @import("prettytable");

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
        const row = try handleRow(allocator, line);
        try all_rows.append(allocator, row);
    }

    for (all_rows.items, 0..) |row, i| {
        if (i == 0) try table.setTitle(row);
        if (i > 0) try table.addRow(row);
    }
    try table.printstd();
}

fn handleCols(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    var col = try std.ArrayList(u8).initCapacity(allocator, 0);
    for (text) |c| {
        try col.append(allocator, c);
    }
    return try col.toOwnedSlice(allocator);
}

fn handleRow(allocator: std.mem.Allocator, text: []const u8) ![][]const u8 {
    var row = try std.ArrayList([]const u8).initCapacity(allocator, 0);
    var in_quotes = false;
    var buffer: [500]u8 = undefined;
    var len: usize = 0;

    // handle split of row into chunks of columns.
    for (text, 0..) |c, i| {
        if (c == '"' and !in_quotes) in_quotes = true;
        if (c == '"' and i + 1 < text.len and text[i + 1] == ',') in_quotes = false;
        if (c == ',' and !in_quotes) {
            const col = try handleCols(allocator, buffer[0..len]);
            try row.append(allocator, col);
            len = 0;
        } else {
            buffer[len] = c;
            len += 1;
        }
    }
    return try row.toOwnedSlice(allocator);
}
