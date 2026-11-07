{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Event log option tests.
@br
The tests check that the puller works without the event log, that Parse
accepts only the last event then, and that Parse leaves the cursor after the
value in both modes.
}
unit JsonPuller.NoLog.Test;

{$mode delphi}{$H+}

interface

uses
  SysUtils, fpjson, fpcunit, testregistry, JsonPuller, JsonPuller.Events,
  JsonPuller.Errors;

type
  TNoLogTest = class(TTestCase)
  private
    function Make(const AText: UTF8String; AKeepLog: Boolean): TJsonPuller;
    procedure CheckCursorAfterValue(AKeepLog: Boolean);
  published
    procedure TestCursorAfterValueWithLog;
    procedure TestCursorAfterValueWithoutLog;
    procedure TestCountWithoutLog;
    procedure TestNameEvent;
    procedure TestScalarEvent;
    procedure TestOldEventRaises;
    procedure TestParseWholeWithoutLog;
    procedure TestParseWholeAfterNextRaises;
    procedure TestNilForEndEvents;
    procedure TestPropertySetsMode;
    procedure TestKeepLogAlias;
  end;

implementation

function TNoLogTest.Make(const AText: UTF8String; AKeepLog: Boolean): TJsonPuller;
var
  F: TJsonPullerFactory;
begin
  F := TJsonPullerFactory.Create;
  try
    F.KeepEventLog(AKeepLog);
    Result := F.FromString(AText);
  finally
    F.Free;
  end;
end;

procedure TNoLogTest.CheckCursorAfterValue(AKeepLog: Boolean);
var
  P: TJsonPuller;
  E: TJsonEvent;
  D: TJSONData;
begin
  P := Make('{"a":{"x":[1,2]},"b":3}', AKeepLog);
  try
    P.Next; // stream start
    P.Next; // object start
    E := P.Next; // name a
    AssertEquals(Ord(jetName), Ord(E.EventType));
    E := P.Next; // object start of the value
    AssertEquals(Ord(jetObjectStart), Ord(E.EventType));
    P.Parse(E, D);
    try
      AssertEquals('{"x":[1,2]}', D.FormatJSON([foSingleLineArray,
        foSingleLineObject, foSkipWhiteSpace]));
    finally
      D.Free;
    end;
    E := P.Next;
    AssertEquals(Ord(jetName), Ord(E.EventType));
    AssertEquals('b', string(E.EventText));
  finally
    P.Free;
  end;
end;

procedure TNoLogTest.TestCursorAfterValueWithLog;
begin
  CheckCursorAfterValue(True);
end;

procedure TNoLogTest.TestCursorAfterValueWithoutLog;
begin
  CheckCursorAfterValue(False);
end;

procedure TNoLogTest.TestCountWithoutLog;
var
  P: TJsonPuller;
begin
  P := Make('[1,2,3]', False);
  try
    while P.HasNext do
      P.Next;
    AssertEquals(0, P.EventLogLength);
  finally
    P.Free;
  end;
end;

procedure TNoLogTest.TestNameEvent;
var
  P: TJsonPuller;
  E: TJsonEvent;
  D: TJSONData;
begin
  P := Make('{"k":1}', False);
  try
    P.Next;
    P.Next;
    E := P.Next;
    P.Parse(E, D);
    try
      AssertEquals('k', D.AsString);
    finally
      D.Free;
    end;
    E := P.Next;
    AssertEquals(Ord(jetNumber), Ord(E.EventType));
  finally
    P.Free;
  end;
end;

procedure TNoLogTest.TestScalarEvent;
var
  P: TJsonPuller;
  E: TJsonEvent;
  D: TJSONData;
begin
  P := Make('[5,6]', False);
  try
    P.Next;
    P.Next;
    E := P.Next;
    P.Parse(E, D);
    try
      AssertEquals(5, D.AsInteger);
    finally
      D.Free;
    end;
    E := P.Next;
    AssertEquals('6', string(E.EventText));
  finally
    P.Free;
  end;
end;

procedure TNoLogTest.TestOldEventRaises;
var
  P: TJsonPuller;
  First, Second: TJsonEvent;
  D: TJSONData;
  Raised: Boolean;
begin
  P := Make('[1,2]', False);
  try
    P.Next;
    First := P.Next;
    Second := P.Next;
    AssertEquals(Ord(jetNumber), Ord(Second.EventType));
    Raised := False;
    try
      P.Parse(First, D);
    except
      on EJsonParserError do
        Raised := True;
    end;
    AssertTrue(Raised);
  finally
    P.Free;
  end;
end;

procedure TNoLogTest.TestParseWholeWithoutLog;
var
  P: TJsonPuller;
  D: TJSONData;
begin
  P := Make('{"a":[1,2]}', False);
  try
    D := P.Parse;
    try
      AssertEquals('{"a":[1,2]}', D.FormatJSON([foSingleLineArray,
        foSingleLineObject, foSkipWhiteSpace]));
    finally
      D.Free;
    end;
  finally
    P.Free;
  end;
end;

procedure TNoLogTest.TestParseWholeAfterNextRaises;
var
  P: TJsonPuller;
  Raised: Boolean;
begin
  P := Make('[1]', False);
  try
    P.Next;
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

procedure TNoLogTest.TestNilForEndEvents;
var
  P: TJsonPuller;
  E: TJsonEvent;
  D: TJSONData;
begin
  P := Make('[]', False);
  try
    E := P.Next;
    P.Parse(E, D);
    AssertTrue(D = nil);
  finally
    P.Free;
  end;
end;

procedure TNoLogTest.TestPropertySetsMode;
var
  P: TJsonPuller;
  E: TJsonEvent;
  D: TJSONData;
  Raised: Boolean;
begin
  P := Make('[1,2]', True);
  try
    P.KeepEventLog := False;
    P.Next;
    P.Next;
    E := P.Next;
    P.Next;
    Raised := False;
    try
      P.Parse(E, D);
    except
      on EJsonParserError do
        Raised := True;
    end;
    AssertTrue(Raised);
  finally
    P.Free;
  end;
end;

procedure TNoLogTest.TestKeepLogAlias;
var
  F: TJsonPullerFactory;
  P: TJsonPuller;
begin
  F := TJsonPullerFactory.Create;
  try
    F.KeepLog(False);
    P := F.FromString('[1,2]');
    try
      AssertFalse(P.KeepLog);
      P.KeepLog := True;
      AssertTrue(P.KeepLog);
      AssertTrue(P.KeepEventLog);
    finally
      P.Free;
    end;
  finally
    F.Free;
  end;
end;

initialization
  RegisterTest(TNoLogTest);

end.
