# JsonPuller

Version 0.1.0.

JsonPuller is a JSON pull parser. It is an Object Pascal library.
The library uses the FCL JSON classes for the `Parse` result.

The library reads one JSON text. A pull parser returns one event at a time.
The caller controls the event sequence. The same library also reads a messy
JSON text. Messy JSON adds comments, unquoted keys, trailing commas,
single quotes, missing values, leading zeros, or a leading decimal point
to the JSON grammar. The factory settings select those forms.

## Overview

The library consists of two main classes: `TJsonPullerFactory` and
`TJsonPuller`.

`TJsonPullerFactory` holds the dialect flags and instantiates a
`TJsonPuller` from a data source. `TJsonPuller` reads the JSON event stream.
`TJsonPuller.Next` returns one `TJsonEvent` at a time.

The documents below describe the library:

| Document | Subject |
|---|---|
| `doc/architecture.md` | The layers, the events, and the memory model |
| `doc/dialect.md` | The JSON grammar and the dialect settings |
| `doc/usage.md` | The call sequence and the examples |

## Build

`make` is the build system. The `Makefile` compiles the library units in
`src/`, runs the unit tests in `test/`, and runs the example programs in
`examples/`. The `make examples` target compiles and runs each example.

The repository also holds a Taskfile.yaml. It mirrors the `Makefile` targets
and adds the release sequence. The Taskfile.yaml is an entry point, and the
`Makefile` is the primary build system.

| Task | Operation |
|---|---|
| `task build` | Compiles the library units into `bin/` |
| `task test` | Builds the units and runs the unit tests |
| `task examples` | Builds and runs each example |
| `task check` | Runs `task test` and `task examples` |
| `task version` | Prints the version from `src/JsonPuller.pas` |
| `task tag` | Creates and pushes the annotated tag |
| `task dist` | Writes the source zip of the tagged version |
| `task release` | Tags the version and publishes a GitHub release |
| `task clean` | Removes the build outputs |

The version has one source, the constant `JSON_PULLER_VERSION` in
`src/JsonPuller.pas`. The `task dist` and `task release` targets read that
constant. The package file `JsonPuller.lpk` holds the same version in its own
form.

The repository also holds a Lazarus package file, `JsonPuller.lpk`. The
package file lists the library units and the `FCL` requirement. A user opens
the package in the Lazarus IDE to browse the units or to install the package.

The `Makefile` is the primary build system. The `make` build, the `task`
build, and the Lazarus build use the same source units.

## TJsonPullerFactory

```yaml
TJsonPullerFactory:
    - AllowUnquotedKeys( value: Boolean = false )
    - AllowComments( value: Boolean = true )
    - AllowTrailingCommas( value: Boolean = false )
    - AllowSingleQuotes( value: Boolean = false )
    - AllowMissingValues( value: Boolean, asNull: Boolean = false )
    - AllowLeadingZeros( value: Boolean = false )
    - AllowLeadingDecimalPoint( value: Boolean = false )
    - TJsonPuller FromFile( file: handle )
    - TJsonPuller FromStream( astream: TStream )
    - TJsonPuller FromBytes( astream: TBytes )
    - TJsonPuller FromString( astream: utf8string )
```

The caller creates a factory. The factory holds the dialect settings.
Each `Allow*` method sets its setting from the arguments. When `value` has
a default, a call with no argument sets that default. `AllowMissingValues`
requires `value`. An omitted `asNull` is false. The initial value of each
setting is the default in the signature, and the initial value of
`AllowMissingValues` is false.

| Method | Initial value | The setting selects |
|---|---|---|
| `AllowUnquotedKeys` | false | An object name written without quotes |
| `AllowComments` | true | A `//` comment or a `/* */` comment |
| `AllowTrailingCommas` | false | A comma immediately before `}` or `]` |
| `AllowSingleQuotes` | false | A string written with single quotes |
| `AllowMissingValues` | false, `asNull` false | A missing element or member written as consecutive commas |
| `AllowLeadingZeros` | false | A number whose integer part has a redundant leading zero |
| `AllowLeadingDecimalPoint` | false | A number that starts with a decimal point |

The initial values accept every JSON text, and they also accept comments.
An unquoted key, a trailing comma, a single-quoted string, a missing
value, a leading zero, and a leading decimal point stay rejected until the
caller sets the matching setting to true.
`doc/dialect.md` explains the reason and the grammar of each form.

The factory instantiates a `TJsonPuller` from a given data source. The four
methods cover the four data sources:

- `FromFile` reads from a file handle.
- `FromStream` reads from a `TStream`.
- `FromBytes` reads from a `TBytes` value.
- `FromString` reads from a UTF-8 string.

Each `From*` method copies the dialect settings into the new puller. A later
change to the factory changes the next puller. The existing puller keeps
the copy. The factory holds no source data. The caller releases the factory.
The caller releases the puller.

## TJsonPuller

```yaml
TJsonPuller:
    Next: TJsonEvent # the next event
    HasNext: boolean # more events are available
    Parse: TJSONData # reads the whole event stream into an FCL JSON value
    Parse( event: TJsonEvent, data: TJSONData ) # reads one subsection
```

- `Next` returns the next event from the stream.
- `HasNext` states whether more events are available.
- `Parse` reads the whole event stream and returns an FCL JSON value.
  - The text holds one JSON value. The value is a `TJSONObject`, a
    `TJSONArray`, or a scalar.
  - A text with no value raises an error that names the line and the column.
  - A second value raises an error that names the line and the column.
    One text holds one value.
  - A string becomes a `TJSONString`. The text of the string is the decoded
    text. Escape sequences are already resolved.
  - `true` becomes a `TJSONBoolean` with the value true. `false` becomes a
    `TJSONBoolean` with the value false. `null` becomes a `TJSONNull`.
  - A number with an integer form inside the Int64 range becomes a
    `TJSONInt64Number`. Every other number that fits in a double becomes a
    `TJSONFloatNumber`. A number that does not fit in a double raises an
    error that names the line and the column.
  - An object member name becomes the member name. A duplicate member name
    raises an error that names the line and the column.
  - The caller releases the returned value.
- `Parse(event, data)` reads the subsection that starts at `event` and
  assigns the JSON value to `data`. The caller releases `data`.
  - An object start builds the object.
  - An array start builds the array.
  - A name builds the string of that name.
  - A string, a number, a boolean, and a null build that scalar.
  - A stream start and a stream end set `data` to nil, because such an
    event starts no value.
  - The event identifies the start by its value. The event comes from the
    same puller.
  - The operation reads only the events that the subsection needs. The read
    stops at the end event of the subsection.

## TJsonEvent

`TJsonEvent` is one event parsed from the stream.

```yaml
TJsonEvent:
    EventType: TJsonEventType # one value of the JSON event type enumeration
    EventText: utf8string # the event text
    NestLevel: integer # the nesting depth
    Line: integer # the 1-based line of the event
    Column: integer # the 1-based column of the event
```

- `EventType` is one value of the `TJsonEventType` enumeration.
- `EventText` holds the text of the event.
- `NestLevel` is the nesting depth. The stream start event is 0. An object
  start and the matching object end share one nest level. An array start
  and the matching array end share one nest level. The events inside the
  collection use the next greater nest level.
- `Line` and `Column` give the position of the event in the input. The
  column counts characters. A tab is one character.

`TJsonEventType` has these values:

| Value | The event reports |
|---|---|
| `jetStreamStart` | The start of the text |
| `jetStreamEnd` | The end of the text |
| `jetObjectStart` | The start of an object |
| `jetObjectEnd` | The end of an object |
| `jetArrayStart` | The start of an array |
| `jetArrayEnd` | The end of an array |
| `jetName` | One object member name |
| `jetString` | One string value |
| `jetNumber` | One number, in source spelling |
| `jetTrue` | The literal true |
| `jetFalse` | The literal false |
| `jetNull` | The literal null |

A comma and a colon are syntax. They have no event. A comment has no event.
The parser uses them to build the events above.

## License

This product is licensed under the Apache License, Version 2.0. The
`LICENSE` file holds the full text.

Copyright 2026 Liam Seamus Coughlin.
