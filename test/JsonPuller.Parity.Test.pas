{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Parity tests with fpjson GetJSON parser.
@br
The tests compare TJsonPuller.Parse and fpjson.GetJSON across dialects,
duplicate names, numbers, escapes, and syntax errors.
}
unit JsonPuller.Parity.Test;

{$mode delphi}{$H+}

interface

uses
  SysUtils, fpjson, jsonparser, fpcunit, testregistry,
  JsonPuller, JsonPuller.Events, JsonPuller.Errors;

type
  TParityTest = class(TTestCase)
  private
    function ParseWithPuller(const AText: UTF8String;
      AAllowComments: Boolean = True;
      AAllowDuplicateNames: Boolean = False): TJSONData;
    function ParseWithGetJSON(const AText: UTF8String): TJSONData;
  published
    procedure TestComments;
    procedure TestDuplicateMemberNames;
    procedure TestMessyDialectRejections;
    procedure TestNumbersAndScalars;
    procedure TestSyntaxErrors;
  end;

implementation

function TParityTest.ParseWithPuller(const AText: UTF8String;
  AAllowComments: Boolean;
  AAllowDuplicateNames: Boolean): TJSONData;
var
  F: TJsonPullerFactory;
  P: TJsonPuller;
begin
  F := TJsonPullerFactory.Create;
  try
    F.AllowComments(AAllowComments);
    F.AllowDuplicateNames(AAllowDuplicateNames);
    P := F.FromString(AText);
    try
      Result := P.Parse;
    finally
      P.Free;
    end;
  finally
    F.Free;
  end;
end;

function TParityTest.ParseWithGetJSON(const AText: UTF8String): TJSONData;
var
  Parser: TJSONParser;
begin
  Parser := TJSONParser.Create(AText, True);
  try
    Result := Parser.Parse;
  finally
    Parser.Free;
  end;
end;

procedure TParityTest.TestComments;
var
  PullerData, FpData: TJSONData;
  PullerRaised, FpRaised: Boolean;
begin
  // By default, JsonPuller accepts comments, fpjson rejects them
  PullerData := ParseWithPuller('{"a": 1 // comment'#10'}', True, False);
  try
    AssertNotNull(PullerData);
    AssertEquals(1, TJSONObject(PullerData).Get('a'));
  finally
    PullerData.Free;
  end;

  FpRaised := False;
  try
    FpData := ParseWithGetJSON('{"a": 1 // comment'#10'}');
    FpData.Free;
  except
    on E: Exception do
      FpRaised := True;
  end;
  AssertTrue('fpjson must reject comments', FpRaised);

  // With AllowComments(False), JsonPuller also rejects comments
  PullerRaised := False;
  try
    PullerData := ParseWithPuller('{"a": 1 // comment'#10'}', False, False);
    PullerData.Free;
  except
    on EJsonError do
      PullerRaised := True;
  end;
  AssertTrue('JsonPuller with AllowComments(False) must reject comments', PullerRaised);
end;

procedure TParityTest.TestDuplicateMemberNames;
var
  PullerData: TJSONData;
  PullerRaised, FpRaised: Boolean;
begin
  // fpjson rejects duplicate member names by default
  FpRaised := False;
  try
    ParseWithGetJSON('{"a": 1, "a": 2}').Free;
  except
    on E: Exception do
      FpRaised := True;
  end;
  AssertTrue('fpjson must reject duplicate member names', FpRaised);

  // JsonPuller by default also rejects duplicate member names
  PullerRaised := False;
  try
    PullerData := ParseWithPuller('{"a": 1, "a": 2}', True, False);
    PullerData.Free;
  except
    on EJsonParserError do
      PullerRaised := True;
  end;
  AssertTrue('JsonPuller default must reject duplicate member names', PullerRaised);

  // With AllowDuplicateNames(True), JsonPuller accepts them and keeps the last value
  PullerData := ParseWithPuller('{"a": 1, "a": 2}', True, True);
  try
    AssertNotNull(PullerData);
    AssertEquals(1, TJSONObject(PullerData).Count);
    AssertEquals('a', TJSONObject(PullerData).Names[0]);
    AssertEquals(2, TJSONObject(PullerData).Items[0].AsInteger);
  finally
    PullerData.Free;
  end;
end;

procedure TParityTest.TestMessyDialectRejections;
var
  FpRaised, PullerRaised: Boolean;
  FpData: TJSONData;
begin
  // Trailing comma: fpjson and JsonPuller both reject
  FpRaised := False;
  try
    ParseWithGetJSON('{"a": 1,}').Free;
  except
    FpRaised := True;
  end;
  AssertTrue('fpjson must reject trailing comma', FpRaised);

  PullerRaised := False;
  try
    ParseWithPuller('{"a": 1,}').Free;
  except
    on EJsonError do
      PullerRaised := True;
  end;
  AssertTrue('JsonPuller default must reject trailing comma', PullerRaised);

  // Leading zeros: fpjson accepts leading zeros by default; JsonPuller rejects by default
  FpData := ParseWithGetJSON('[01]');
  try
    AssertNotNull(FpData);
    AssertEquals(1, TJSONArray(FpData).Items[0].AsInteger);
  finally
    FpData.Free;
  end;

  PullerRaised := False;
  try
    ParseWithPuller('[01]').Free;
  except
    on EJsonError do
      PullerRaised := True;
  end;
  AssertTrue('JsonPuller default must reject leading zeros', PullerRaised);

  // Leading decimal point: fpjson accepts leading decimal point by default; JsonPuller rejects by default
  FpData := ParseWithGetJSON('[.5]');
  try
    AssertNotNull(FpData);
    AssertEquals(0.5, TJSONArray(FpData).Items[0].AsFloat, 0.0001);
  finally
    FpData.Free;
  end;

  PullerRaised := False;
  try
    ParseWithPuller('[.5]').Free;
  except
    on EJsonError do
      PullerRaised := True;
  end;
  AssertTrue('JsonPuller default must reject leading decimal point', PullerRaised);

  // Single quotes: fpjson accepts single quotes by default; JsonPuller rejects by default
  FpData := ParseWithGetJSON('{''a'': ''b''}');
  try
    AssertNotNull(FpData);
    AssertEquals('b', TJSONObject(FpData).Get('a'));
  finally
    FpData.Free;
  end;

  PullerRaised := False;
  try
    ParseWithPuller('{''a'': ''b''}').Free;
  except
    on EJsonError do
      PullerRaised := True;
  end;
  AssertTrue('JsonPuller default must reject single quotes', PullerRaised);

  // Unquoted keys: fpjson accepts unquoted identifiers by default; JsonPuller rejects by default
  FpData := ParseWithGetJSON('{a: 1}');
  try
    AssertNotNull(FpData);
    AssertEquals(1, TJSONObject(FpData).Get('a'));
  finally
    FpData.Free;
  end;

  PullerRaised := False;
  try
    ParseWithPuller('{a: 1}').Free;
  except
    on EJsonError do
      PullerRaised := True;
  end;
  AssertTrue('JsonPuller default must reject unquoted keys', PullerRaised);
end;

procedure TParityTest.TestNumbersAndScalars;
var
  Texts: array[0..10] of UTF8String;
  I: Integer;
  PData, FData: TJSONData;
begin
  Texts[0] := '0.1';
  Texts[1] := '1e3';
  Texts[2] := '-0';
  Texts[3] := '9223372036854775807';
  Texts[4] := '9223372036854775808';
  Texts[5] := '12345678901234567890';
  Texts[6] := '"123.45"';
  Texts[7] := 'null';
  Texts[8] := '{"nested":{"val":42}}';
  Texts[9] := '"\u0041\u00e9"';
  Texts[10] := 'true';

  for I := 0 to High(Texts) do
  begin
    PData := ParseWithPuller(Texts[I]);
    try
      FData := ParseWithGetJSON(Texts[I]);
      try
        if (Texts[I] = '-0') then
        begin
          AssertTrue('PData is TJSONNumber', PData is TJSONNumber);
          AssertTrue('FData is TJSONNumber', FData is TJSONNumber);
          AssertEquals('Value match for -0', FData.AsInt64, PData.AsInt64);
        end
        else if (Texts[I] = '"\u0041\u00e9"') then
        begin
          AssertEquals('Class match for ' + Texts[I], FData.ClassName, PData.ClassName);
          AssertEquals('String match for unicode escape', 'A'#195#169, PData.AsString);
        end
        else
        begin
          AssertEquals('Class match for ' + Texts[I], FData.ClassName, PData.ClassName);
          AssertEquals('JSON match for ' + Texts[I], FData.AsJSON, PData.AsJSON);
        end;
      finally
        FData.Free;
      end;
    finally
      PData.Free;
    end;
  end;
end;

procedure TParityTest.TestSyntaxErrors;
var
  Errors: array[0..2] of UTF8String;
  I: Integer;
  FpRaised, PullerRaised: Boolean;
begin
  Errors[0] := '[1 2]'; // missing comma
  Errors[1] := '{"a": 1'; // missing bracket
  Errors[2] := '[1,'; // unterminated array

  for I := 0 to High(Errors) do
  begin
    FpRaised := False;
    try
      ParseWithGetJSON(Errors[I]).Free;
    except
      FpRaised := True;
    end;
    AssertTrue('fpjson must raise on syntax error ' + IntToStr(I), FpRaised);

    PullerRaised := False;
    try
      ParseWithPuller(Errors[I]).Free;
    except
      on EJsonError do
        PullerRaised := True;
    end;
    AssertTrue('JsonPuller must raise on syntax error ' + IntToStr(I), PullerRaised);
  end;

  // Second top-level value: JsonPuller strictly raises because RFC 8259 allows one top-level value
  PullerRaised := False;
  try
    ParseWithPuller('1 2').Free;
  except
    on EJsonParserError do
      PullerRaised := True;
  end;
  AssertTrue('JsonPuller must raise on second top-level value', PullerRaised);
end;

initialization
  RegisterTest(TParityTest);
end.
