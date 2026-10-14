{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Shared helpers for the unit tests (plan story S00).
@br
The helpers build a puller from a string and collect the event stream or the
JSON text. Each test unit keeps its own assertions.
}
unit JsonPuller.Support;

{$mode delphi}{$H+}

interface

uses
  SysUtils, fpjson, JsonPuller, JsonPuller.Events, JsonPuller.Options;

type
  TEventList = array of TJsonEvent;

function OptionsOf(AComments, AUnquoted, ATrailing, ASingle, AMissing, AAsNull,
  AZeros, ADot: Boolean): TJsonOptions;

function Pull(const AText: UTF8String; const AOptions: TJsonOptions): TJsonPuller;

function CollectEvents(const AText: UTF8String;
  const AOptions: TJsonOptions): TEventList;

function ParseText(const AText: UTF8String;
  const AOptions: TJsonOptions): TJSONData;

function JsonText(const AText: UTF8String;
  const AOptions: TJsonOptions): string;

function ErrorMessage(const AText: UTF8String;
  const AOptions: TJsonOptions): string;

implementation

uses
  JsonPuller.Errors;

function OptionsOf(AComments, AUnquoted, ATrailing, ASingle, AMissing, AAsNull,
  AZeros, ADot: Boolean): TJsonOptions;
begin
  Result := DefaultJsonOptions;
  Result.AllowComments := AComments;
  Result.AllowUnquotedKeys := AUnquoted;
  Result.AllowTrailingCommas := ATrailing;
  Result.AllowSingleQuotes := ASingle;
  Result.AllowMissingValues := AMissing;
  Result.MissingAsNull := AAsNull;
  Result.AllowLeadingZeros := AZeros;
  Result.AllowLeadingDecimalPoint := ADot;
end;

function Pull(const AText: UTF8String; const AOptions: TJsonOptions): TJsonPuller;
var
  Factory: TJsonPullerFactory;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Factory.AllowComments(AOptions.AllowComments);
    Factory.AllowUnquotedKeys(AOptions.AllowUnquotedKeys);
    Factory.AllowTrailingCommas(AOptions.AllowTrailingCommas);
    Factory.AllowSingleQuotes(AOptions.AllowSingleQuotes);
    Factory.AllowMissingValues(AOptions.AllowMissingValues, AOptions.MissingAsNull);
    Factory.AllowLeadingZeros(AOptions.AllowLeadingZeros);
    Factory.AllowLeadingDecimalPoint(AOptions.AllowLeadingDecimalPoint);
    Result := Factory.FromString(AText);
  finally
    Factory.Free;
  end;
end;

function CollectEvents(const AText: UTF8String;
  const AOptions: TJsonOptions): TEventList;
var
  Puller: TJsonPuller;
  Event: TJsonEvent;
  N: Integer;
begin
  Result := nil;
  N := 0;
  Puller := Pull(AText, AOptions);
  try
    while Puller.HasNext do
    begin
      Event := Puller.Next;
      if N >= Length(Result) then
        SetLength(Result, N + 8);
      Result[N] := Event;
      Inc(N);
    end;
  finally
    Puller.Free;
  end;
  SetLength(Result, N);
end;

function ParseText(const AText: UTF8String;
  const AOptions: TJsonOptions): TJSONData;
var
  Puller: TJsonPuller;
begin
  Puller := Pull(AText, AOptions);
  try
    Result := Puller.Parse;
  finally
    Puller.Free;
  end;
end;

function JsonText(const AText: UTF8String;
  const AOptions: TJsonOptions): string;
var
  Data: TJSONData;
begin
  Data := ParseText(AText, AOptions);
  try
    Result := Data.AsJSON;
  finally
    Data.Free;
  end;
end;

function ErrorMessage(const AText: UTF8String;
  const AOptions: TJsonOptions): string;
var
  Puller: TJsonPuller;
  Data: TJSONData;
begin
  Result := '';
  Puller := nil;
  try
    Puller := Pull(AText, AOptions);
    try
      Data := Puller.Parse;
      Data.Free;
    except
      on E: EJsonError do
        Result := E.ClassName + ' ' + E.Message;
    end;
  except
    on E: EJsonError do
      Result := E.ClassName + ' ' + E.Message;
  end;
  Puller.Free;
end;

end.
