# JsonPuller Usage

## Purpose

This document describes the use of the JsonPuller library. The README file
holds the public API summary. `doc/dialect.md` holds the grammar and the
dialect settings. This document gives the usage sequence and examples.

## Requirements

The library has these requirements:

- Free Pascal 3.2.2 or later.
- The compiler mode `{$mode delphi}`.
- The FCL unit `fpjson` for the `Parse` operation.
- The program `make` for the build.

The `make` command is the build system. The `make` command compiles the
library units. A second target runs the unit tests. The `JsonPuller.lpk`
package file gives the same units to the Lazarus IDE. The README describes
the four data sources and the dialect settings.

## The Factory

The caller creates a `TJsonPullerFactory`. The factory starts with the
initial settings from `doc/dialect.md`. Comments are accepted. Unquoted
keys are rejected. Trailing commas are rejected. Single quotes are
rejected. Missing values are rejected. Leading zeros are rejected. A
leading decimal point is rejected.

Each `Allow*` method sets its setting from the arguments. When `value` has
a default, a call with no argument restores that default.
`AllowMissingValues` requires `value`. An omitted `asNull` is false.

The factory holds no source data. A second `From*` call creates a second
puller. Each puller copies the flags at the moment of the call. A later
change on the factory changes the next puller. The first puller keeps the
flags it copied.

The caller releases the factory. The caller releases each puller. The
puller releases neither the stream nor the file handle.

| Method | Data source | What the puller keeps |
|---|---|---|
| `FromFile(file: handle)` | An open file handle | A block read from the handle. The caller keeps the handle. |
| `FromStream(astream: TStream)` | A `TStream` instance | A block read from the stream. The caller keeps the stream. |
| `FromBytes(astream: TBytes)` | A `TBytes` value | A copy of the bytes |
| `FromString(astream: utf8string)` | A UTF-8 string | A copy of the string |

A string and a byte array are complete values, so the puller copies them
and the caller can reuse the original. A stream and a file can be larger
than the part the caller reads, so the puller reads them in blocks.

## The Pull Loop

`HasNext` states whether the stream holds more events. `Next` returns the
next event. The caller repeats the `Next` call while `HasNext` is true.

The event sequence starts with a stream-start event. The event sequence
ends with a stream-end event. The events of the one JSON value stand
between those two events.

Each object start has a matching object end. Each array start has a
matching array end. The matching events share a nest level. The events
inside the collection use the next greater nest level. The reason is
recorded in `doc/architecture.md`: the parser emits the start event and
then adds one to the level.

A comma and a colon have no event. They tell the parser where a name ends
and where the next member starts. A comment has no event for the same
reason a space has no event.

## Event Types

The event type table below lists the events that `Next` returns.

| Event type | The event reports |
|---|---|
| Stream start | The start of the text |
| Stream end | The end of the text |
| Object start | The start of an object |
| Object end | The end of an object |
| Array start | The start of an array |
| Array end | The end of an array |
| Name | One object member name, in the event text |
| String | One string value, in the event text |
| Number | One number, in the source spelling |
| True | The literal true |
| False | The literal false |
| Null | The literal null |

The text `{"a":[1]}` produces this event sequence. The nest level column
shows the shared level of each start and end pair.

| Event type | Event text | Nest level |
|---|---|---|
| Stream start | | 0 |
| Object start | | 0 |
| Name | `a` | 1 |
| Array start | | 1 |
| Number | `1` | 2 |
| Array end | | 1 |
| Object end | | 0 |
| Stream end | | 0 |

## The Parse Operation

`Parse` reads the whole event stream and returns an FCL JSON value. The
return type is `TJSONData`. The caller releases the returned value.

The text holds one value. The result is that value.

| JSON value | FCL JSON value |
|---|---|
| Object | `TJSONObject` |
| Array | `TJSONArray` |
| String | `TJSONString` |
| Number, integer in the Int64 range | `TJSONInt64Number` |
| Number, every other number that fits in a double | `TJSONFloatNumber` |
| True | `TJSONBoolean` true |
| False | `TJSONBoolean` false |
| Null | `TJSONNull` |

A member name becomes the name of a JSON member. A member value becomes
the JSON member value. A duplicate member name raises an error that names
the line and the column of the second name. The event stream still reports
both names. The event stream is a record of the text. The JSON object is a
tree, and a tree holds one member for each name.

A text with no value raises an error. A second value raises an error. The
position is line 1, column 1 when the text is empty.

## The Parse Operation for a Subsection

`Parse(event, data)` reads the subsection that starts at `event` and
assigns the JSON value to `data`. The caller releases `data`.

The value follows the start event:

| Start event | Result in `data` |
|---|---|
| Object start | The `TJSONObject` of the object |
| Array start | The `TJSONArray` of the array |
| Name | The `TJSONString` of the name |
| String | The string value |
| Number | The number value |
| True or false | The boolean value |
| Null | The null value |
| Stream start | nil, because the event starts no value |
| Stream end | nil, because the event starts no value |

A name event builds the name. The member value starts at the next value
event. A caller who needs the member value keeps that event and parses it.
The split follows the event model: each event has one value, and the name
and the member value are different events.

The event identifies the start by its value. The event comes from the same
puller. The operation reads only the events that the subsection needs. The
read stops at the end event of the subsection. A caller reads an object
near the start of a large text without reading the later siblings.

## Example: a String to a JSON Value

The example below creates a puller from a string. The initial flags are in
force. The example parses the text into a `TJSONData` value.

```pascal
uses
  fpjson, JsonPuller;

var
  factory: TJsonPullerFactory;
  puller: TJsonPuller;
  data: TJSONData;
begin
  factory := TJsonPullerFactory.Create;
  try
    puller := factory.FromString(
      '{"name":"example","count":3,"enabled":true}');
    try
      data := puller.Parse;
      try
        WriteLn(data.AsJSON);
      finally
        data.Free;
      end;
    finally
      puller.Free;
    end;
  finally
    factory.Free;
  end;
end.
```

The example writes this text:

```json
{"name":"example","count":3,"enabled":true}
```

The member `count` is an integer. The spelling `3` is an integer inside
the Int64 range, so the value is a `TJSONInt64Number`.

## Example: Comments

Comments are accepted by the initial flags. The example below parses a
text that holds a line comment and a block comment.

```pascal
uses
  fpjson, JsonPuller;

var
  factory: TJsonPullerFactory;
  puller: TJsonPuller;
  data: TJSONData;
begin
  factory := TJsonPullerFactory.Create;
  try
    puller := factory.FromString(
      '{ /* service */ "port": 8080 }' + LineEnding);
    try
      data := puller.Parse;
      try
        WriteLn(data.AsJSON);
      finally
        data.Free;
      end;
    finally
      puller.Free;
    end;
  finally
    factory.Free;
  end;
end.
```

The example writes this text:

```json
{"port":8080}
```

The comment is layout. The object has one member. A caller who needs a
strict reader calls `AllowComments(False)` before `FromString`. A comment
then raises an error at the solidus.

## Example: Unquoted Keys and Trailing Commas

The example below sets the two flags that start false. The text uses an
identifier name, a numeric name, and a trailing comma.

```pascal
uses
  fpjson, JsonPuller;

var
  factory: TJsonPullerFactory;
  puller: TJsonPuller;
  data: TJSONData;
begin
  factory := TJsonPullerFactory.Create;
  try
    factory.AllowUnquotedKeys(True);
    factory.AllowTrailingCommas(True);
    puller := factory.FromString('{host: "localhost", 1: "one",}');
    try
      data := puller.Parse;
      try
        WriteLn(data.AsJSON);
      finally
        data.Free;
      end;
    finally
      puller.Free;
    end;
  finally
    factory.Free;
  end;
end.
```

The example writes this text:

```json
{"host":"localhost","1":"one"}
```

The identifier `host` becomes the member name `host`. The number `1`
becomes the member name `1`. The trailing comma adds no member. Under the
initial flags the same text raises an error at `host`.

## Example: Single and Double Quotes

The example below sets `AllowSingleQuotes`. The text mixes both quote
styles. A single-quoted string holds a double quote. A double-quoted
string holds a single quote. The opening quote of each string selects the
closer.

```pascal
uses
  fpjson, JsonPuller;

var
  factory: TJsonPullerFactory;
  puller: TJsonPuller;
  data: TJSONData;
begin
  factory := TJsonPullerFactory.Create;
  try
    factory.AllowSingleQuotes(True);
    puller := factory.FromString(
      '{''a'': "b", "c": ''say "hi"'', "d": "it''s"}');
    try
      data := puller.Parse;
      try
        WriteLn(data.AsJSON);
      finally
        data.Free;
      end;
    finally
      puller.Free;
    end;
  finally
    factory.Free;
  end;
end.
```

The Pascal string writes a single quote as `''`. The JSON text is this:

```json
{'a': "b", "c": 'say "hi"', "d": "it's"}
```

The example writes this text:

```json
{"a":"b","c":"say \"hi\"","d":"it's"}
```

The member `a` is the string `b`. The member `c` is the string `say "hi"`.
The member `d` is the string `it's`. Under the initial flags the same text
raises an error at the first single quote.

## Example: Missing Values

The example below accepts consecutive commas and maps an array hole to
null. The object in the same call has a hole between two members. That
hole has no name, so the object gains no member.

```pascal
uses
  fpjson, JsonPuller;

var
  factory: TJsonPullerFactory;
  puller: TJsonPuller;
  data: TJSONData;
begin
  factory := TJsonPullerFactory.Create;
  try
    factory.AllowMissingValues(True, True);
    puller := factory.FromString('[1,,2]');
    try
      data := puller.Parse;
      try
        WriteLn(data.AsJSON);
      finally
        data.Free;
      end;
    finally
      puller.Free;
    end;
  finally
    factory.Free;
  end;
end.
```

The example writes this text:

```json
[1,null,2]
```

The same array with `AllowMissingValues(True)` writes `[1,2]`. The omitted
`asNull` is false, so the hole is left out. The text `{"a": 1,, "b": 2}`
writes `{"a":1,"b":2}` for both values of `asNull`. Under the initial
settings, `[1,,2]` raises an error at the second comma. The text `[1,]`
is a trailing comma, so it uses `AllowTrailingCommas`.

## Example: Leading Zeros and a Leading Decimal Point

The example below accepts both number spellings. The event text of each
number is the source spelling. `Parse` stores the numeric value.

```pascal
uses
  fpjson, JsonPuller;

var
  factory: TJsonPullerFactory;
  puller: TJsonPuller;
  data: TJSONData;
begin
  factory := TJsonPullerFactory.Create;
  try
    factory.AllowLeadingZeros(True);
    factory.AllowLeadingDecimalPoint(True);
    puller := factory.FromString('[007,03.14,.507]');
    try
      data := puller.Parse;
      try
        WriteLn(data.AsJSON);
      finally
        data.Free;
      end;
    finally
      puller.Free;
    end;
  finally
    factory.Free;
  end;
end.
```

`007` is the integer 7. `03.14` is the float 3.14. `.507` is the float
0.507. FCL writes a float in the FCL float form. The example writes this text:

```json
[7,3.1400000000000001E+000,5.0700000000000001E-001]
```

The two settings are independent. `007` and `03.14` need
`AllowLeadingZeros`. `.507` needs `AllowLeadingDecimalPoint`. Under the
initial settings, `007` raises an error at `0` and `.507` raises an error
at the decimal point.

## Example: an Event Loop

The example below reads the events one at a time. The example writes the
event type and the event text.

```pascal
uses
  JsonPuller, JsonPuller.Events;

var
  factory: TJsonPullerFactory;
  puller: TJsonPuller;
  event: TJsonEvent;
begin
  factory := TJsonPullerFactory.Create;
  try
    puller := factory.FromString('["one","two"]');
    try
      while puller.HasNext do
      begin
        event := puller.Next;
        WriteLn(Ord(event.EventType), ': ', event.EventText,
          ' (', event.Line, ',', event.Column, ') level=', event.NestLevel);
      end;
    finally
      puller.Free;
    end;
  finally
    factory.Free;
  end;
end.
```

The event loop is useful when the caller needs only part of the text. The
caller can stop the loop at any event. The unread tail stays unscanned.

## Example: a Subsection

The example below reads the events until the array that is the value of
the member `ports`. The example parses that array alone.

```pascal
uses
  fpjson, JsonPuller, JsonPuller.Events;

var
  factory: TJsonPullerFactory;
  puller: TJsonPuller;
  event: TJsonEvent;
  data: TJSONData;
  found: TJsonEvent;
begin
  factory := TJsonPullerFactory.Create;
  try
    puller := factory.FromString(
      '{"ports":[80,443],"note":"later"}');
    try
      found := Default(TJsonEvent);
      while puller.HasNext do
      begin
        event := puller.Next;
        if event.EventType = jetArrayStart then
        begin
          found := event;
          Break;
        end;
      end;
      if found.EventType = jetArrayStart then
      begin
        puller.Parse(found, data);
        try
          WriteLn(data.AsJSON);
        finally
          data.Free;
        end;
      end;
    finally
      puller.Free;
    end;
  finally
    factory.Free;
  end;
end.
```

The example writes this text:

```json
[80,443]
```

The member `note` stays unread. The subsection stops at the array end.

## Example: a Stream Source

The example below creates a puller from a file stream. The example parses
the stream into a `TJSONData` value.

```pascal
uses
  Classes, SysUtils, fpjson, JsonPuller;

var
  factory: TJsonPullerFactory;
  source: TFileStream;
  puller: TJsonPuller;
  data: TJSONData;
begin
  factory := TJsonPullerFactory.Create;
  source := TFileStream.Create('config.json', fmOpenRead);
  try
    puller := factory.FromStream(source);
    data := puller.Parse;
    try
      WriteLn(data.AsJSON);
    finally
      data.Free;
    end;
    puller.Free;
  finally
    source.Free;
    factory.Free;
  end;
end.
```

The caller releases the stream. The puller reads the stream. Ownership of
the stream stays with the caller.

## Streaming and Memory

The puller reads a stream source and a file source in blocks of 8192
characters. The scanner asks for characters, and the input layer reads the
next block at that request. A caller that stops the event loop does not
cause a read of the later blocks.

A string source and a byte source are copied at construction. Those values
are already complete, so a block read would not change their size.

The scanner holds the current token. A long string can cross a block
boundary. The token keeps its characters until the token is complete.
Earlier tokens are already consumed.

The puller appends each returned event to an event log. The subsection
operation finds its start event in that log. The log grows with the events
the caller has received. A caller that stops early holds the log of those
events.

The memory that the puller holds follows this table:

| Buffer | Size |
|---|---|
| A string or byte source | One character value per input character |
| A stream or file source | One read block, plus the characters of a token that crosses a block |
| The current token | One token |
| The event log | One event per event that `Next` has returned |
| The JSON tree | One value per node, for the `Parse` call only |

The `Parse` operation reads the whole remaining text, because it builds the
whole JSON value. The `Parse(event, data)` operation reads only the events
of the subsection, because it stops at the end event of the subsection.

The nest level has a bound of 1000. A deeper object or array raises an
error that names the line and the column. The bound is the constant
`MaxDepth` described in `doc/architecture.md`.

## Release of Resources

The caller releases each `TJsonPullerFactory` instance. The caller releases
each `TJsonPuller` instance. The caller releases the data source. Ownership
of the source stays with the caller.

The caller releases each value that `Parse` returns. The caller also
releases `data` after the `Parse(event, data)` operation.
