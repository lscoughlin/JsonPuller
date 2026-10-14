{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
JSON bridge: events to an FCL value (plan story S09).
@br
The bridge builds one TJSONData value from events. An in-range integer
spelling becomes TJSONInt64Number. Every other number that fits in a double
becomes TJSONFloatNumber. A duplicate member name raises an error.
}
unit JsonPuller.JSON;

{$mode delphi}{$H+}

interface

uses
  SysUtils, fpjson, JsonPuller.Events;

type
  /// read the event at an index. The reader fetches the event when the
  /// index is past the events already returned.
  TJsonGetEvent = function(AIndex: Integer): TJsonEvent of object;

/// build the value that starts at AIndex. AIndex advances past that value.
function BuildJsonValue(AGet: TJsonGetEvent; var AIndex: Integer): TJSONData;

implementation

uses
  Math, JsonPuller.Errors;

function IsIntegerSpelling(const AText: UTF8String): Boolean;
var
  I, Start: Integer;
begin
  if AText = '' then
    Exit(False);
  Start := 1;
  if AText[1] = '-' then
    Start := 2;
  if Start > Length(AText) then
    Exit(False);
  for I := Start to Length(AText) do
    if (AText[I] < '0') or (AText[I] > '9') then
      Exit(False);
  Result := True;
end;

function NumberValue(const AEvent: TJsonEvent): TJSONData;
var
  Settings: TFormatSettings;
  IntVal: Int64;
  FloatVal: Double;
begin
  Settings := DefaultFormatSettings;
  Settings.DecimalSeparator := '.';
  Settings.ThousandSeparator := #0;
  if IsIntegerSpelling(AEvent.EventText) and TryStrToInt64(AEvent.EventText, IntVal) then
    Exit(TJSONInt64Number.Create(IntVal));
  if (not TryStrToFloat(AEvent.EventText, FloatVal, Settings)) or
    IsNan(FloatVal) or IsInfinite(FloatVal) then
    raise EJsonParserError.Create(
      'The number does not fit in a double', AEvent.Line, AEvent.Column);
  Result := TJSONFloatNumber.Create(FloatVal);
end;

function BuildObject(AGet: TJsonGetEvent; var AIndex: Integer): TJSONObject;
var
  Event: TJsonEvent;
  Child: TJSONData;
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.CompressedJSON := True;
    while True do
    begin
      Event := AGet(AIndex);
      if Event.EventType = jetObjectEnd then
      begin
        Inc(AIndex);
        Break;
      end;
      if Event.EventType <> jetName then
        raise EJsonParserError.Create(
          'The parser expects a member name', Event.Line, Event.Column);
      Inc(AIndex);
      Child := BuildJsonValue(AGet, AIndex);
      if Obj.IndexOfName(Event.EventText) >= 0 then
      begin
        Child.Free;
        raise EJsonParserError.Create(
          'The object has a duplicate member name', Event.Line, Event.Column);
      end;
      Obj.Add(Event.EventText, Child);
    end;
    Result := Obj;
    Obj := nil;
  finally
    Obj.Free;
  end;
end;

function BuildArray(AGet: TJsonGetEvent; var AIndex: Integer): TJSONArray;
var
  Event: TJsonEvent;
  Arr: TJSONArray;
begin
  Arr := TJSONArray.Create;
  try
    Arr.CompressedJSON := True;
    while True do
    begin
      Event := AGet(AIndex);
      if Event.EventType = jetArrayEnd then
      begin
        Inc(AIndex);
        Break;
      end;
      Arr.Add(BuildJsonValue(AGet, AIndex));
    end;
    Result := Arr;
    Arr := nil;
  finally
    Arr.Free;
  end;
end;

function BuildJsonValue(AGet: TJsonGetEvent; var AIndex: Integer): TJSONData;
var
  Event: TJsonEvent;
begin
  Event := AGet(AIndex);
  Inc(AIndex);
  case Event.EventType of
    jetString, jetName:
      Result := TJSONString.Create(Event.EventText);
    jetNumber:
      Result := NumberValue(Event);
    jetTrue:
      Result := TJSONBoolean.Create(True);
    jetFalse:
      Result := TJSONBoolean.Create(False);
    jetNull:
      Result := TJSONNull.Create;
    jetObjectStart:
      Result := BuildObject(AGet, AIndex);
    jetArrayStart:
      Result := BuildArray(AGet, AIndex);
  else
    raise EJsonParserError.Create(
      'The event starts no value', Event.Line, Event.Column);
  end;
end;

end.
