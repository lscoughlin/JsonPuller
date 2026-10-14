{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Compliance fixtures (plan story S12).
@br
The RFC set has a recorded count. Each dialect flag has an accepting case
and a rejecting case. Each rejected form raises an error with a position.
}
unit JsonPuller.Compliance.Test;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, fpcunit, testregistry;

type
  TComplianceTest = class(TTestCase)
  private
    procedure Expect(const AText: UTF8String;
      AUnquoted, AComments, ATrailing, ASingle, AMissing, AAsNull, AZeros,
      ADot: Boolean; const AExpected: string);
    procedure ExpectError(const AText: UTF8String;
      AUnquoted, AComments, ATrailing, ASingle, AMissing, AAsNull, AZeros,
      ADot: Boolean);
  published
    procedure TestFixtureCount;
    procedure TestRoundTrip;
    procedure TestDialectFlags;
    procedure TestRejectedForms;
    procedure TestEdgeCases;
  end;

implementation

uses
  fpjson, JsonPuller, JsonPuller.Errors;

const
  RfcFixtureCount = 12;

function ReadRaw(const APath: string): UTF8String;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(APath, fmOpenRead);
  try
    SetLength(Result, Stream.Size);
    if Stream.Size > 0 then
      Stream.ReadBuffer(Result[1], Stream.Size);
  finally
    Stream.Free;
  end;
  while (Length(Result) > 0) and
    ((Result[Length(Result)] = #10) or (Result[Length(Result)] = #13)) do
    SetLength(Result, Length(Result) - 1);
end;

function ParseRaw(const AText: UTF8String): string;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString(AText);
    try
      Data := Puller.Parse;
      try
        Result := Data.AsJSON;
      finally
        Data.Free;
      end;
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TComplianceTest.TestFixtureCount;
var
  Info: TSearchRec;
  Count: Integer;
begin
  Count := 0;
  if FindFirst('test/fixtures/rfc/*.json', faAnyFile, Info) = 0 then
  begin
    try
      repeat
        Inc(Count);
      until FindNext(Info) <> 0;
    finally
      FindClose(Info);
    end;
  end;
  AssertEquals(RfcFixtureCount, Count);
end;

procedure TComplianceTest.TestRoundTrip;
var
  Info: TSearchRec;
  Input, Expected: UTF8String;
begin
  if FindFirst('test/fixtures/rfc/*.json', faAnyFile, Info) <> 0 then
    Fail('The RFC fixtures are missing');
  try
    repeat
      Input := ReadRaw('test/fixtures/rfc/' + Info.Name);
      Expected := ReadRaw('test/fixtures/rfc/' +
        ChangeFileExt(Info.Name, '.expected'));
      AssertEquals(Info.Name, Expected, ParseRaw(Input));
    until FindNext(Info) <> 0;
  finally
    FindClose(Info);
  end;
end;

procedure TComplianceTest.Expect(const AText: UTF8String;
  AUnquoted, AComments, ATrailing, ASingle, AMissing, AAsNull, AZeros, ADot: Boolean;
  const AExpected: string);
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Factory.AllowUnquotedKeys(AUnquoted);
    Factory.AllowComments(AComments);
    Factory.AllowTrailingCommas(ATrailing);
    Factory.AllowSingleQuotes(ASingle);
    Factory.AllowMissingValues(AMissing, AAsNull);
    Factory.AllowLeadingZeros(AZeros);
    Factory.AllowLeadingDecimalPoint(ADot);
    Puller := Factory.FromString(AText);
    try
      Data := Puller.Parse;
      try
        AssertEquals(AExpected, Data.AsJSON);
      finally
        Data.Free;
      end;
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TComplianceTest.ExpectError(const AText: UTF8String;
  AUnquoted, AComments, ATrailing, ASingle, AMissing, AAsNull, AZeros, ADot: Boolean);
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Factory.AllowUnquotedKeys(AUnquoted);
    Factory.AllowComments(AComments);
    Factory.AllowTrailingCommas(ATrailing);
    Factory.AllowSingleQuotes(ASingle);
    Factory.AllowMissingValues(AMissing, AAsNull);
    Factory.AllowLeadingZeros(AZeros);
    Factory.AllowLeadingDecimalPoint(ADot);
    Puller := Factory.FromString(AText);
    try
      try
        Data := Puller.Parse;
        Data.Free;
        Fail('The text did not raise: ' + AText);
      except
        on E: EJsonError do
          AssertTrue(Pos('at line ', E.Message) > 0);
      end;
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TComplianceTest.TestDialectFlags;
begin
  Expect(ReadRaw('test/fixtures/dialect/comments-ok.json'),
    False, True, False, False, False, False, False, False, '{"a":1}');
  ExpectError(ReadRaw('test/fixtures/dialect/comments-bad.json'),
    False, False, False, False, False, False, False, False);
  Expect(ReadRaw('test/fixtures/dialect/unquoted-ok.json'),
    True, True, False, False, False, False, False, False, '{"host":1}');
  ExpectError(ReadRaw('test/fixtures/dialect/unquoted-bad.json'),
    False, True, False, False, False, False, False, False);
  Expect(ReadRaw('test/fixtures/dialect/trailing-ok.json'),
    False, True, True, False, False, False, False, False, '[1]');
  ExpectError(ReadRaw('test/fixtures/dialect/trailing-bad.json'),
    False, True, False, False, False, False, False, False);
  Expect(ReadRaw('test/fixtures/dialect/quotes-ok.json'),
    False, True, False, True, False, False, False, False, '"ab"');
  ExpectError(ReadRaw('test/fixtures/dialect/quotes-bad.json'),
    False, True, False, False, False, False, False, False);
  Expect(ReadRaw('test/fixtures/dialect/missing-ok.json'),
    False, True, False, False, True, False, False, False, '[1,2]');
  ExpectError(ReadRaw('test/fixtures/dialect/missing-bad.json'),
    False, True, False, False, False, False, False, False);
  Expect(ReadRaw('test/fixtures/dialect/zeros-ok.json'),
    False, True, False, False, False, False, True, False, '7');
  ExpectError(ReadRaw('test/fixtures/dialect/zeros-bad.json'),
    False, True, False, False, False, False, False, False);
  Expect(ReadRaw('test/fixtures/dialect/dot-ok.json'),
    False, True, False, False, False, False, False, True,
    '5.0000000000000000E-001');
  ExpectError(ReadRaw('test/fixtures/dialect/dot-bad.json'),
    False, True, False, False, False, False, False, False);
end;

procedure TComplianceTest.TestRejectedForms;
begin
  ExpectError(ReadRaw('test/fixtures/rejected/hex.json'),
    False, True, False, False, False, False, False, False);
  ExpectError(ReadRaw('test/fixtures/rejected/plus.json'),
    False, True, False, False, False, False, False, False);
  ExpectError(ReadRaw('test/fixtures/rejected/nan.json'),
    True, True, False, False, False, False, False, False);
  ExpectError(ReadRaw('test/fixtures/rejected/infinity.json'),
    True, True, False, False, False, False, False, False);
  ExpectError(ReadRaw('test/fixtures/rejected/true.json'),
    True, True, False, False, False, False, False, False);
  ExpectError(ReadRaw('test/fixtures/rejected/false.json'),
    True, True, False, False, False, False, False, False);
  ExpectError(ReadRaw('test/fixtures/rejected/null.json'),
    True, True, False, False, False, False, False, False);
  ExpectError(ReadRaw('test/fixtures/rejected/hash.json'),
    False, True, False, False, False, False, False, False);
  ExpectError(ReadRaw('test/fixtures/rejected/second.json'),
    False, True, False, False, False, False, False, False);
  ExpectError(ReadRaw('test/fixtures/rejected/ident.json'),
    True, True, False, False, False, False, False, False);
end;

procedure TComplianceTest.TestEdgeCases;
begin
  ExpectError('', False, True, False, False, False, False, False, False);
  Expect('{}', False, True, False, False, False, False, False, False, '{}');
  Expect('[]', False, True, False, False, False, False, False, False, '[]');
  Expect('  1  ', False, True, False, False, False, False, False, False, '1');
end;

initialization
  RegisterTest(TComplianceTest);
end.
