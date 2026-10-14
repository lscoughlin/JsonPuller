# JsonPuller Architecture

## Purpose

This document describes the structure and the behavior of the JsonPuller
library. The library is a JSON pull parser for Object Pascal.

A pull parser returns one event at a time. The caller controls the event
sequence. The caller can stop the event loop at any event. The scanner
produces the next token when the parser asks for a token. The parser
produces the next event when the caller asks for an event. A caller that
stops early leaves the unread tail of the text unscanned. The `Parse`
operation reads the whole text because it builds the whole JSON value.
The streaming behavior and its limits are recorded in `doc/usage.md`.

The public API is the contract. The README file holds the public API. This
document describes the internals below that API. The JSON grammar and the
dialect settings are recorded in `doc/dialect.md`.

The library follows the pull theory of a layered reader. Each layer removes
one kind of information. The caller sees events. Bytes, characters, and
syntax tokens stay inside their layers.

## Assumptions

This section records the environment of the library.

| Item | Value |
|---|---|
| Language | Object Pascal |
| Compiler mode | `{$mode delphi}` |
| Compiler | Free Pascal 3.2.2 or later. A build of this library is confirmed with Free Pascal 3.2.4. |
| JSON classes | FCL `fpjson` (`TJSONObject`, `TJSONArray`, and the scalar classes) |
| Test framework | `fpcunit` with a console runner |
| JSON grammar | RFC 8259, plus the dialect in `doc/dialect.md` |
| Build tool | `make`, with `Taskfile.yaml` as an entry point |

The `Makefile` is the build system. The `Makefile` compiles the library units
in `src/` and runs the unit tests in `test/`. The repository also holds a
`Taskfile.yaml`. The `Taskfile.yaml` mirrors the `Makefile` targets and adds
the release sequence. The repository also holds a Lazarus package file,
`JsonPuller.lpk`. The package file lists the same source units and the `FCL`
requirement. The Makefile build, the Taskfile build, and the Lazarus build
use the same units.

The tasks are these:

| Task | Operation |
|---|---|
| `task build` | The task compiles the library units into `bin/`. |
| `task test` | The task builds the units and runs the unit tests. |
| `task examples` | The task builds and runs each example. |
| `task check` | The task runs the unit tests and every example. |
| `task version` | The task prints the version from `src/JsonPuller.pas`. |
| `task tag` | The task creates and pushes the annotated tag. |
| `task dist` | The task writes the source zip of the tagged version. |
| `task release` | The task tags the version and publishes a GitHub release. |
| `task clean` | The task removes the build outputs. |

## Why the Shape Matches a YAML Pull Parser

A JSON text and a YAML stream differ in grammar. The reading theory is the
same.

| Shared idea | Meaning in this library |
|---|---|
| Factory | One object selects the source and returns a puller |
| Four sources | A file handle, a `TStream`, a `TBytes` value, or a UTF-8 string |
| Pull loop | `HasNext` and `Next` return one event on request |
| Event record | A type, a text, a nest level, a line, and a column |
| Layers | Input, scanner, parser, and a JSON bridge |
| Whole-text result | `Parse` builds one FCL JSON value |
| Subsection result | `Parse(event, data)` builds the value that starts at one event |
| Errors | The message names the line and the column |
| Early stop | Unread input stays unread |

JSON grammar uses braces, brackets, and literal tokens. The type of a
JSON literal is part of the grammar. The parser therefore emits a typed
event. The library has no schema layer. YAML delays that choice because a
plain scalar is untyped until a schema resolves it.

The factory is an instance. The dialect settings are state. A class
method has nowhere to keep that state between the flag call and the source
call. The caller creates the factory, sets the flags, and then selects the
source.

## Layer Model

The library has four layers. Data moves from the input layer to the JSON
bridge. Each layer has one responsibility.

```
+----------------+     +----------------+     +----------------+     +----------------+
|  Input layer   | --> |  Scanner       | --> |  Parser        | --> |  JSON bridge   |
|  bytes -> chars|     |  chars -> toks |     |  toks -> events|     |  events -> FCL |
+----------------+     +----------------+     +----------------+     +----------------+
```

The input layer removes the byte encoding. The scanner removes the character
syntax that carries no value. The parser removes the token syntax and builds
events. The JSON bridge converts the event structure into an FCL JSON value.

A colon, a comma, a comment, and whitespace are absent from the event stream.
They exist so the parser can find names and values. The event stream keeps
the information a caller needs: the boundaries of objects and arrays, the
member names, and the scalar values.

### Input Layer

The input layer receives one of four data sources:

- A file handle.
- A `TStream` instance.
- A `TBytes` value.
- A UTF-8 string.

A string source and a byte source are already complete values. The input
layer copies them at construction. A stream source and a file source can be
larger than the part the caller reads. The input layer reads those sources
in blocks when the scanner asks for more characters. The read block is 8192
characters after decoding. A token that crosses a block boundary keeps its
characters until the token is complete.

The input layer performs two operations on the bytes:

1. Encoding selection. The JSON encoding is UTF-8. A leading byte order
   mark selects UTF-8, UTF-16 LE, UTF-16 BE, UTF-32 LE, or UTF-32 BE. A
   text with no byte order mark is UTF-8. The mark is not a character of
   the text. The first text character is column 1. A UTF-16 or UTF-32 text
   without a mark fails, because those encodings are identified by the mark.
2. Line-break normalization. The input layer accepts LF, CRLF, and CR as
   line breaks. The scanner sees one line-break form, LF.

Invalid UTF-8 fails at the line and the column of the bad sequence. The
input layer supplies characters to the scanner.

The line and the column start at 1. A line break adds one to the line and
sets the column to 1. The column counts characters. A tab is one character.
The column is a character index on the line. A display column can differ
when the line holds a tab. The character index stays stable for tests and
for error text.

### Scanner

The scanner reads characters and produces tokens. Each token has a type, a
text value, a line, and a column. The scanner is context-free. The name
role and the value role belong to the parser. That split keeps a number
token legal everywhere a number is legal.

The scanner produces one token when the parser requests the next token.
The scanner holds that token. The token list of the whole text stays out
of the scanner.

The scanner has these token families:

| Family | Token kinds |
|---|---|
| Punctuation | `{`, `}`, `[`, `]`, `:`, `,` |
| Scalars | string, number, `true`, `false`, `null` |
| Names | an identifier, when unquoted keys are accepted |
| Layout | whitespace and comments, which produce no token |

A string token holds the decoded text. Escape sequences are resolved in the
scanner because they are character syntax. The baseline string uses double
quotes. When `AllowSingleQuotes` is true, a single-quoted string is the
same token. One text can contain both quote styles. The opening quote
selects the closer, and `doc/dialect.md` records that rule. A number token
holds the source spelling. The JSON bridge chooses the numeric class later,
so the event stream can still show the digits the author wrote.

An identifier token exists when `AllowUnquotedKeys` is true. When the flag
is false, an identifier character is a scanner error. An identifier is never
a JSON value, so the scanner can reject it without the parser's context.
A number stays a number token in both flag states. A number is a legal value.
The parser rejects a number in the name position when the flag is false.

The comment flag and the comment forms are specified in `doc/dialect.md`.
The scanner removes a comment and reports no token for it. Whitespace
follows the same rule. A comment is layout, in the same way that a space is
layout.

### Parser

The parser reads tokens and produces events. The parser holds a state
machine and a nest level. The state machine has these states:

| State | The parser expects |
|---|---|
| Stream | One value, then the end of the text |
| Value | An object, an array, a string, a number, or a literal |
| Object first | A member name, or the end of the object |
| Object colon | A colon after a name |
| Object value | A value after the colon |
| Object next | A comma, or the end of the object |
| Object comma | A member name after a comma, a further comma when missing values are accepted, or the end when trailing commas are accepted |
| Array first | A value, or the end of the array |
| Array next | A comma, or the end of the array |
| Array comma | A value after a comma, a further comma when missing values are accepted, or the end when trailing commas are accepted |
| Done | The end of the text |

A further comma in the object-comma state or the array-comma state is one
missing value. That comma stands where a member or an element would stand.
The difference between that comma and a trailing comma, and the effect of
`asNull`, are recorded in `doc/dialect.md`.

The done state is the reason a second value fails. RFC 8259 defines one
value in one text. After that value, the parser accepts only layout. Another
value is an error at that value's line and column.

A member name becomes a `jetName` event. The parser has three sources for
that event, and `doc/dialect.md` specifies when each source is legal:

- A JSON string.
- An identifier.
- A number, or the spelling of `true`, `false`, or `null`, used as a name.

The event type records the role. A caller reads `jetName` and then the
events of the member value. The caller does not track the parser state to
learn which strings are names.

The nest level starts at 0. The parser emits a start event at the current
level and then adds one. The events inside the collection use the greater
level. The parser subtracts one and then emits the matching end event. The
start event and the end event therefore share a nest level. A name event
and a scalar event keep the level of the collection that contains them.

The constant `MaxDepth` is 1000. The parser checks the nest level before it
adds one. A deeper collection raises an error that names the line and the
column. The bound closes the resource risk of a deeply nested array or
object. The event stream and `Parse` use the same bound.

### JSON Bridge

The JSON bridge reads the event stream and builds an FCL JSON value. The
README documents these operations as `Parse: TJSONData` and
`Parse(event, data)`.

The bridge applies these rules to the one value in the text:

| JSON event | FCL JSON value |
|---|---|
| Object | `TJSONObject` |
| Array | `TJSONArray` |
| String, and a name | `TJSONString` |
| Number, integer in the Int64 range | `TJSONInt64Number` |
| Number, every other number that fits in a double | `TJSONFloatNumber` |
| True | `TJSONBoolean` true |
| False | `TJSONBoolean` false |
| Null | `TJSONNull` |

A `jetName` event supplies the member name of the next value. The member
value becomes the JSON member value. A nested object becomes a nested
`TJSONObject`. A nested array becomes a nested `TJSONArray`. Member order
follows the event order. FCL JSON keeps that insertion order.

The number rule prefers an integer class when the spelling is an integer
inside the Int64 range. The value `1` stays an integer. A fraction or an
exponent becomes a float. An integer outside the Int64 range becomes a float
when the magnitude fits in a double. A double has 53 bits of integer
precision, so that float can differ from the decimal spelling. The event
text keeps the spelling for a caller who needs the exact digits. A number
that does not fit in a double raises an error.

A redundant leading zero does not change that rule. The spelling `007` is
the integer 7, and the event text remains `007`. A leading decimal point
is a fraction whose integer part is zero. The spelling `.507` is the float
0.507, and the event text remains `.507`. The accepted spellings are
recorded in `doc/dialect.md`.

`Parse(event, data)` builds the value that starts at one event. The puller
finds the event in the event log and reads forward until that value is
complete. A name event is complete on that event. Its value is the name
string. The member value is a later event, and a caller who wants the member
value parses that later event. A stream start and a stream end start no
value, so `data` is nil.

## Event Model

`TJsonEvent` is the unit of output from the parser. The README defines five
fields:

| Field | Type | Meaning |
|---|---|---|
| `EventType` | `TJsonEventType` | The kind of the event |
| `EventText` | `utf8string` | The text of the event |
| `NestLevel` | `integer` | The nesting depth of the event |
| `Line` | `integer` | The 1-based line of the event |
| `Column` | `integer` | The 1-based column of the event |

`TJsonEventType` is an enumeration. The enumeration has these values:

| Value | Meaning |
|---|---|
| `jetStreamStart` | The start of the text |
| `jetStreamEnd` | The end of the text |
| `jetObjectStart` | The start of an object |
| `jetObjectEnd` | The end of an object |
| `jetArrayStart` | The start of an array |
| `jetArrayEnd` | The end of an array |
| `jetName` | An object member name |
| `jetString` | A string value |
| `jetNumber` | A number, in source spelling |
| `jetTrue` | The literal true |
| `jetFalse` | The literal false |
| `jetNull` | The literal null |

Each start event has a matching end event. The matching events share a nest
level and stand in nested order. An object start and its object end enclose
the name events and the value events of the members.

The event text depends on the event type:

| Event | Event text |
|---|---|
| Stream start, stream end, object start, object end, array start, array end | Empty |
| Name | The member name after decoding |
| String | The string value after decoding |
| Number | The source spelling |
| True, false, null | `true`, `false`, or `null` |

## Position Tracking

The scanner records the line and the column of the first character of each
token. The parser copies that position onto the event. The position appears
in an error message. An error message names the line and the column of the
token that caused the error.

A structural event uses the position of its token. An object start uses the
position of `{`. A name uses the position of the first character of the name.

## Event Log

JSON has no alias. The subsection operation still needs a record of events
the caller has already received, because the caller identifies the start by
the event value. The puller appends each event to a log when `Next` returns
it. The log holds the events read so far. The function `EventLogLength`
returns the number of events in the log.

`Parse(event, data)` searches that log. A match is an event with the same
type, text, nest level, line, and column. The search continues forward from
the match until the value is complete. When the end of the value is not in
the log yet, the puller reads more events, and it stops at that end. The
tail after the subsection stays unread.

## Constraints

The repository guidelines constrain the source files:

- A Pascal file is less than 1000 lines long. A Pascal file expresses one
  concept, or one related set of concepts.
- A Pascal method is less than 500 lines long. This limit is a soft limit.
  A Pascal method expresses one responsibility.

The layer model is compatible with these constraints. The scanner token
families occupy separate units. The parser state machine occupies one unit.
The JSON bridge occupies one unit.

## Decisions

The behavior in this document and in `doc/dialect.md` is decided.

| Topic | Decision |
|---|---|
| Values per text | One value. A missing value and a second value raise an error. |
| Dialect | The settings in `doc/dialect.md`. No other relaxation. |
| Factory | An instance. It holds the flags and copies them into each puller. |
| Types | The event type carries the JSON type. There is no schema layer. |
| Names in the event stream | A name is a `jetName` event. |
| Duplicate names | The event stream reports each name. `Parse` raises an error. |
| Numbers | Integer in the Int64 range, otherwise a double, otherwise an error. |
| Depth | `MaxDepth` is 1000. |
| Encoding | UTF-8, or a byte order mark that selects a Unicode encoding. |
| Sources | The puller copies a string or a byte source. It reads a stream or a file in blocks. The caller keeps ownership of the stream and the handle. |
| Subsection | The operation builds the value of the start event and stops at its end. |
