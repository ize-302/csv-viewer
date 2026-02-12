# csv-viewer

A terminal CSV file viewer built in Zig. Reads CSV files and displays them as formatted ASCII tables.

## Features

- Parses CSV files with proper handling of quoted fields (e.g., `"Company, Inc."` won't split on the inner comma)
- Renders data as a formatted ASCII table with borders, headers, and auto-sized columns
- Lightweight and fast

## Example Output

```
+-------+-----------------+------------+-----------+
| Index | Customer Id     | First Name | Last Name |
+=======+=================+============+===========+
| 1     | DD37Cf93aecA6Dc | Sheryl     | Baxter    |
+-------+-----------------+------------+-----------+
| 2     | 1Ef7b82A4CAAD10 | Preston    | Lozano    |
+-------+-----------------+------------+-----------+
```

## Requirements

- [Zig](https://ziglang.org/) >= 0.15.2

## Build

```bash
zig build
```

The compiled binary will be at `zig-out/bin/csv_viewer`.

## Usage

```bash
# Using zig build run
zig build run -- path/to/file.csv

# Or run the binary directly
./zig-out/bin/csv_viewer path/to/file.csv
```

A sample file `samples/customers-100.csv` is included to try it out:

> Samples were sourced from: [https://github.com/datablist/sample-csv-files](https://github.com/datablist/sample-csv-files)

```bash
zig build run -- samples/customers-100.csv
```

## How It Works

1. The program takes a CSV file path as a command-line argument
2. It reads the file line by line, parsing each row into columns while respecting quoted fields
3. The first row is treated as the table header
4. All rows are rendered as a formatted ASCII table using the [prettytable-zig](https://github.com/dying-will-bullet/prettytable-zig) library

## Tests

```bash
zig build test
```

### Todos

- [x] Render CSV file in table format
- [ ] pagination support
- [ ] detail of csv (name/path to csv, total number of rows / cols, current page)
- [ ] color bool value
