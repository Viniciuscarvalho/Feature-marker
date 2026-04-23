#!/usr/bin/env bash
# lib/json_io.sh — Safe JSON I/O helpers for shell scripts.
#
# All functions delegate to json-io.js, passing user-supplied data via argv
# rather than interpolating it into JavaScript source strings.
# This eliminates command injection through backlog-derived values such as
# feat_id, task_id, title, and file_paths.
#
# Requires: LIB_DIR to be set (done by orchestrate.sh before sourcing modules)

_JSON_IO_SCRIPT="${LIB_DIR:-.}/json-io.js"

# json_init_file <file>
# Creates <file> as {"created_at":"...","entries":{}} if it does not exist.
json_init_file() {
  node "$_JSON_IO_SCRIPT" init "$1"
}

# json_set_entry <file> <key> [field value ...]
# Upserts entries[key] in <file> with the given field/value pairs.
json_set_entry() {
  node "$_JSON_IO_SCRIPT" set-entry "$@"
}

# json_get_entry <file> <key> <field>
# Prints entries[key][field] from <file>, or empty string if absent.
json_get_entry() {
  node "$_JSON_IO_SCRIPT" get-entry "$@"
}

# json_count_array <file> <dot.path>
# Prints the length of the array at <dot.path> in <file>, or 0.
json_count_array() {
  node "$_JSON_IO_SCRIPT" count-array "$@"
}

# json_read_path <file> <dot.path>
# Prints the value at <dot.path> in <file>, or empty string.
json_read_path() {
  node "$_JSON_IO_SCRIPT" read-path "$@"
}

# json_stringify
# Reads stdin as text and writes a JSON-encoded string to stdout.
json_stringify() {
  node "$_JSON_IO_SCRIPT" stringify
}

# json_write_results <file> [field value ...]
# Writes a flat results.json with the given field/value pairs merged on top of any existing content.
# Use field "status_ok" with the exit code as value — it resolves to "completed"/"paused"/"failed".
json_write_results() {
  node "$_JSON_IO_SCRIPT" write-results "$@"
}
