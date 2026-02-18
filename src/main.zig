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

    var current_line_index: usize = 0;

    const item_start: usize = pagination.items * (pagination.page - 1);
    const item_end: usize = item_start + pagination.items;

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
        if (current_line_index == 0) {
            // header
            const row = try rowParser(allocator, line);
            try all_rows.append(allocator, row);
            current_line_index += 1;
        } else {
            if (current_line_index > item_start and current_line_index <= item_end) {
                const row = try rowParser(allocator, line);
                try all_rows.append(allocator, row);
            }
            current_line_index += 1;
        }
    }
    // final row containing the details
    const page_col = try std.fmt.allocPrint(allocator, "page: {d}/{d}", .{ pagination.page, current_line_index / pagination.items });
    defer allocator.free(page_col);
    const total_col = try std.fmt.allocPrint(allocator, "Total: {d}", .{current_line_index - 1});
    defer allocator.free(total_col);
    const per_page_col = try std.fmt.allocPrint(allocator, "Per page: {d}", .{pagination.items});
    defer allocator.free(per_page_col);
    const nrow = [_][]const u8{ " ", page_col, total_col, per_page_col };

    for (all_rows.items, 0..) |row, i| {
        if (i == 0) try table.setTitle(row) else try table.addRow(row);
    }
    try table.addRow(&nrow);
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
        const owned = try col.toOwnedSlice(allocator);
        try row.append(allocator, owned);
    }
    return try row.toOwnedSlice(allocator);
}

const FlagStruct = struct { flag: []const u8, value: u64 };
const PaginationStruct = struct {
    items: u64,
    page: u64,
};
const ArgStruct = struct {
    args: [][:0]u8,
    items: u64,
    page: u64,

    pub fn init(args: [][:0]u8) ArgStruct {
        return ArgStruct{ .args = args, .items = 10, .page = 1 };
    }

    pub fn argumentHandler(self: *ArgStruct) PaginationStruct {
        const valid_flags = [_][]const u8{ "--items=", "--page=" };
        for (self.args[1..]) |flag| {
            if (std.mem.eql(u8, valid_flags[0], flag[0..(valid_flags[0].len)])) {
                const caught_flag = flag[0..(valid_flags[0].len)];
                const caught_value = std.fmt.parseInt(u64, flag[caught_flag.len..], 10) catch |err| {
                    if (err == error.InvalidCharacter) std.debug.print("Value passed to {s} must be a valid number\n", .{flag});
                    std.process.exit(1);
                };
                self.items = caught_value;
            } else if (std.mem.eql(u8, valid_flags[1], flag[0..(valid_flags[1].len)])) {
                const caught_flag = flag[0..(valid_flags[1].len)];
                const caught_value = std.fmt.parseInt(u64, flag[caught_flag.len..], 10) catch |err| {
                    if (err == error.InvalidCharacter) std.debug.print("Value passed to {s} must be a valid number\n", .{flag});
                    std.process.exit(1);
                };
                self.page = caught_value;
            } else {
                std.debug.print("Incorrect flag passed at {s}\n", .{flag});
                std.process.exit(1);
            }
        }
        return PaginationStruct{ .items = self.items, .page = self.page };
    }
};
