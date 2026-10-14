{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Diagnostic tests (plan story S11).
@br
Each error family has one class. The message names the line and the column.
A later call raises the recorded error.
}
unit JsonPuller.Errors.Test;

{$mode delphi}{$H+}

interface

uses
  SysUtils, fpjson, fpcunit, testregistry, JsonPuller, JsonPuller.Errors;

type
  TErrorsTest = class(TTestCase)
  published
    procedure TestClasses;
    procedure TestPositionText;
    procedure TestScannerError;
    procedure TestParserError;
    procedure TestRepeatedFailure;
  end;

implementation

procedure TErrorsTest.TestClasses;
var
  Scanner: EJsonScannerError;
  Parser: EJsonParserError;
  Base: EJsonError;
begin
  Base := EJsonError.Create('The text has an error', 1, 1);
  Scanner := EJsonScannerError.Create('The text has a bad token', 2, 3);
  Parser := EJsonParserError.Create('The text has a bad value', 4, 5);
  try
    AssertTrue(Base is EJsonError);
    AssertTrue(Scanner is EJsonScannerError);
    AssertTrue(Parser is EJsonParserError);
    AssertTrue(Scanner is EJsonError);
    AssertTrue(Parser is EJsonError);
  finally
    Base.Free;
    Scanner.Free;
    Parser.Free;
  end;
end;

procedure TErrorsTest.TestPositionText;
var
  Error: EJsonError;
begin
  Error := EJsonParserError.Create('The text has no value', 1, 1);
  try
    AssertEquals('The text has no value at line 1, column 1', Error.Message);
    AssertTrue(Pos('at line 1, column 1', Error.Message) > 0);
  finally
    Error.Free;
  end;
end;

procedure TErrorsTest.TestScannerError;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('+1');
    try
      try
        Data := Puller.Parse;
        Data.Free;
        Fail('The leading plus did not raise');
      except
        on E: EJsonScannerError do
          AssertTrue(Pos('at line 1, column 1', E.Message) > 0);
      end;
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TErrorsTest.TestParserError;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('1 2');
    try
      try
        Data := Puller.Parse;
        Data.Free;
        Fail('The second value did not raise');
      except
        on E: EJsonParserError do
          AssertTrue(Pos('at line 1, column 3', E.Message) > 0);
      end;
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TErrorsTest.TestRepeatedFailure;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  First, Second: string;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('');
    try
      try
        Puller.Next;
        Fail('The empty text did not raise');
      except
        on E: EJsonParserError do
          First := E.Message;
      end;
      try
        Puller.Next;
        Fail('The second call did not raise');
      except
        on E: EJsonParserError do
          Second := E.Message;
      end;
      AssertEquals(First, Second);
      try
        Data := Puller.Parse;
        Data.Free;
        Fail('The later parse did not raise');
      except
        on E: EJsonParserError do
          AssertEquals(First, E.Message);
      end;
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

initialization
  RegisterTest(TErrorsTest);
end.
