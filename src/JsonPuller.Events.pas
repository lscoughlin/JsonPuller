{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Event model for the JSON pull parser (plan story S02).
@br
The enumeration and the record match the README. Later stories consume this
model and do not change it. The model is frozen.
}
unit JsonPuller.Events;

{$mode delphi}{$H+}

interface

uses
  SysUtils;

type
  /// one value of the JSON event type enumeration
  TJsonEventType = (
    jetStreamStart,
    jetStreamEnd,
    jetObjectStart,
    jetObjectEnd,
    jetArrayStart,
    jetArrayEnd,
    jetName,
    jetString,
    jetNumber,
    jetTrue,
    jetFalse,
    jetNull);

  /// one event from the parser. The README fixes these five fields.
  TJsonEvent = record
    EventType: TJsonEventType;
    EventText: UTF8String;
    /// the nesting depth. A start event and its end event share a level.
    /// The events inside the collection use the next greater level.
    NestLevel: Integer;
    /// the 1-based line of the event
    Line: Integer;
    /// the 1-based column of the event. A tab counts as one character.
    Column: Integer;
  end;

/// build an event
function MakeJsonEvent(AType: TJsonEventType; const AText: UTF8String;
  ANest, ALine, AColumn: Integer): TJsonEvent;

implementation

function MakeJsonEvent(AType: TJsonEventType; const AText: UTF8String;
  ANest, ALine, AColumn: Integer): TJsonEvent;
begin
  Result.EventType := AType;
  Result.EventText := AText;
  Result.NestLevel := ANest;
  Result.Line := ALine;
  Result.Column := AColumn;
end;

end.
