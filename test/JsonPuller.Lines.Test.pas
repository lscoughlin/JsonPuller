{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Several top-level values (JSON Lines) tests.
@br
The tests check the events of a JSON Lines text, blank lines, the CRLF line
end, the array that Parse returns, the empty text, and the error that stays
when the factory does not allow several values.
}
unit JsonPuller.Lines.Test;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, fpjson, fpcunit, testregistry, JsonPuller,
  JsonPuller.Events, JsonPuller.Errors;

type
  TLinesTest = class(TTestCase)
  private
    function Make(const AText: UTF8String; AMultiple: Boolean): TJsonPuller;
    function Kinds(APuller: TJsonPuller): string;
  published
    procedure TestEventsOfTwoLines;
    procedure TestScalarLines;
    procedure TestBlankLinesAndCrLf;
    procedure TestNoFinalNewline;
    procedure TestParseReturnsArray;
    procedure TestParseOneValueIsArray;
    procedure TestParseWithLogOff;
    procedure TestEmptyText;
    procedure TestSecondValueStillAnError;
    procedure TestNestLevelRestarts;
    procedure TestSyntaxErrorOnLaterLine;
    procedure TestSectionOfLaterLine;
    procedure TestFromStream;
  end;

implementation

function TLinesTest.Make(const AText: UTF8String; AMultiple: Boolean): TJsonPuller;
var
  F: TJsonPullerFactory;
begin
  F := TJsonPullerFactory.Create;
  try
    F.AllowMultipleValues(AMultiple);
    Result := F.FromString(AText);
  finally
    F.Free;
  end;
end;

function TLinesTest.Kinds(APuller: TJsonPuller): string;
var
  E: TJsonEvent;
begin
  Result := '';
  while APuller.HasNext do
  begin
    E := APuller.Next;
    case E.EventType of
      jetStreamStart: Result := Result + 'S';
      jetStreamEnd: Result := Result + 'E';
      jetObjectStart: Result := Result + '{';
      jetObjectEnd: Result := Result + '}';
      jetArrayStart: Result := Result + '[';
      jetArrayEnd: Result := Result + ']';
      jetName: Result := Result + 'n';
    else
      Result := Result + 'v';
    end;
  end;
end;

procedure TLinesTest.TestEventsOfTwoLines;
var
  P: TJsonPuller;
begin
  P := Make('{"a":1}' + #10 + '[2,3]' + #10, True);
  try
    AssertEquals('S{nv}[vv]E', Kinds(P));
  finally
    P.Free;
  end;
end;

procedure TLinesTest.TestScalarLines;
var
  P: TJsonPuller;
begin
  P := Make('1' + #10 + '"x"' + #10 + 'true' + #10 + 'null' + #10, True);
  try
    AssertEquals('SvvvvE', Kinds(P));
  finally
    P.Free;
  end;
end;

procedure TLinesTest.TestBlankLinesAndCrLf;
var
  P: TJsonPuller;
begin
  P := Make(#10 + '{"a":1}' + #13#10 + #13#10 + '{"b":2}' + #13#10 + #10, True);
  try
    AssertEquals('S{nv}{nv}E', Kinds(P));
  finally
    P.Free;
  end;
end;

procedure TLinesTest.TestNoFinalNewline;
var
  P: TJsonPuller;
begin
  P := Make('[1]' + #10 + '[2]', True);
  try
    AssertEquals('S[v][v]E', Kinds(P));
  finally
    P.Free;
  end;
end;

procedure TLinesTest.TestParseReturnsArray;
var
  P: TJsonPuller;
  D: TJSONData;
begin
  P := Make('{"a":1}' + #10 + '{"a":2}' + #10 + '3' + #10, True);
  try
    D := P.Parse;
    try
      AssertEquals(Ord(jtArray), Ord(D.JSONType));
      AssertEquals(3, D.Count);
      AssertEquals('{"a":2}', TJSONArray(D)[1].FormatJSON([foSingleLineArray,
        foSingleLineObject, foSkipWhiteSpace]));
      AssertEquals(3, TJSONArray(D)[2].AsInteger);
    finally
      D.Free;
    end;
  finally
    P.Free;
  end;
end;

procedure TLinesTest.TestParseOneValueIsArray;
var
  P: TJsonPuller;
  D: TJSONData;
begin
  P := Make('{"a":1}' + #10, True);
  try
    D := P.Parse;
    try
      AssertEquals(Ord(jtArray), Ord(D.JSONType));
      AssertEquals(1, D.Count);
    finally
      D.Free;
    end;
  finally
    P.Free;
  end;
end;

procedure TLinesTest.TestParseWithLogOff;
var
  P: TJsonPuller;
  D: TJSONData;
begin
  P := Make('[1]' + #10 + '[2]' + #10, True);
  try
    P.KeepEventLog := False;
    D := P.Parse;
    try
      AssertEquals(2, D.Count);
    finally
      D.Free;
    end;
  finally
    P.Free;
  end;
end;

procedure TLinesTest.TestEmptyText;
var
  P: TJsonPuller;
  D: TJSONData;
  Raised: Boolean;
begin
  P := Make(#10#10, True);
  try
    D := P.Parse;
    try
      AssertEquals(0, D.Count);
    finally
      D.Free;
    end;
  finally
    P.Free;
  end;
  P := Make('', False);
  try
    Raised := False;
    try
      P.Parse.Free;
    except
      on EJsonParserError do
        Raised := True;
    end;
    AssertTrue(Raised);
  finally
    P.Free;
  end;
end;

procedure TLinesTest.TestSecondValueStillAnError;
var
  P: TJsonPuller;
  Raised: Boolean;
begin
  P := Make('1' + #10 + '2' + #10, False);
  try
    Raised := False;
    try
      P.Parse.Free;
    except
      on EJsonParserError do
        Raised := True;
    end;
    AssertTrue(Raised);
  finally
    P.Free;
  end;
end;

procedure TLinesTest.TestNestLevelRestarts;
var
  P: TJsonPuller;
  E: TJsonEvent;
  Levels: string;
begin
  P := Make('[1]' + #10 + '[2]' + #10, True);
  try
    Levels := '';
    while P.HasNext do
    begin
      E := P.Next;
      Levels := Levels + IntToStr(E.NestLevel);
    end;
    // stream start, [ 1 ], [ 2 ], stream end
    AssertEquals('0010010' + '0', Levels);
  finally
    P.Free;
  end;
end;

procedure TLinesTest.TestSyntaxErrorOnLaterLine;
var
  P: TJsonPuller;
  E: TJsonEvent;
  Raised: Boolean;
begin
  P := Make('{"a":1}' + #10 + '{"a":}' + #10, True);
  try
    Raised := False;
    try
      repeat
        E := P.Next;
      until not P.HasNext;
    except
      on EJsonParserError do
        Raised := True;
    end;
    AssertTrue(Raised);
  finally
    P.Free;
  end;
end;

procedure TLinesTest.TestSectionOfLaterLine;
var
  P: TJsonPuller;
  E: TJsonEvent;
  D: TJSONData;
  Seen: Integer;
begin
  P := Make('{"a":[1]}' + #10 + '{"a":[2,3]}' + #10, True);
  Seen := 0;
  try
    while P.HasNext do
    begin
      E := P.Next;
      if E.EventType = jetArrayStart then
      begin
        P.Parse(E, D);
        try
          Inc(Seen, D.Count);
        finally
          D.Free;
        end;
      end;
    end;
    AssertEquals(3, Seen);
  finally
    P.Free;
  end;
end;

procedure TLinesTest.TestFromStream;
var
  F: TJsonPullerFactory;
  S: TStringStream;
  P: TJsonPuller;
begin
  F := TJsonPullerFactory.Create;
  S := TStringStream.Create('{"a":1}' + #10 + '{"a":2}' + #10);
  try
    F.AllowMultipleValues(True);
    P := F.FromStream(S);
    try
      AssertEquals('S{nv}{nv}E', Kinds(P));
    finally
      P.Free;
    end;
  finally
    S.Free;
    F.Free;
  end;
end;

initialization
  RegisterTest(TLinesTest);

end.
