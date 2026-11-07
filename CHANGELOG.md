# Changelog

The notable changes of the library. Each entry names the release that
holds it. Dates follow the release commits.

## [Unreleased]

## [0.2.0] - 2026-11-07

### Added

- Streaming item reader with bounded memory: `KeepLog` (alias for `KeepEventLog`)
  setting on `TJsonPullerFactory` and `TJsonPuller`. With `KeepLog(False)`,
  `Parse(event, data)` operates in O(1) time on the last returned event without
  a linear event-log scan.
- Factory setting `AllowDuplicateNames` (default `False`). With `True`, the parser
  accepts duplicate member names in an object and keeps the last member value.
- Support for 64-bit unsigned integers (`TJSONQWordNumber`) for values that exceed
  the maximum signed 64-bit integer range.
- Dialect parity test suite comparing `TJsonPuller` and FPC `fpjson`.

### Changed

- `EventLogLength` returns the active length of the event log (`FLogLen`).
- Bumped version to 0.2.0.

## [0.1.0] - 2026-10-14

### Added

- The initial release of JsonPuller: pull parser event stream with `Next` and
  `HasNext`, and FCL JSON tree construction with `Parse`.
- Factory options for comments, unquoted keys, trailing commas, single quotes,
  missing values, leading zeros, leading decimal point, and multiple top-level values.
