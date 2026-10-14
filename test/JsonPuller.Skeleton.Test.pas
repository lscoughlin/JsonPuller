{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Skeleton assertions, one per unit (plan story S00).
@br
The test links every library unit and checks the Pascal file header.
}
unit JsonPuller.Skeleton.Test;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, fpcunit, testregistry, fpjson, JsonPuller,
  JsonPuller.Options, JsonPuller.Input, JsonPuller.Events, JsonPuller.Errors,
  JsonPuller.Scanner.Core, JsonPuller.Scanner, JsonPuller.Scanner.Literal,
  JsonPuller.Scanner.Comment, JsonPuller.Parser, JsonPuller.JSON;

type
  TSkeletonTest = class(TTestCase)
  published
    procedure TestOptions;
    procedure TestInput;
    procedure TestEvents;
    procedure TestErrors;
    procedure TestScannerCore;
    procedure TestScanner;
    procedure TestLiteral;
    procedure TestComment;
    procedure TestParser;
    procedure TestJson;
    procedure TestPuller;
    procedure TestHeaders;
  end;

implementation

procedure TSkeletonTest.TestOptions;
var
  Options: TJsonOptions;
begin
  Options := DefaultJsonOptions;
  AssertTrue(Options.AllowComments);
  AssertFalse(Options.AllowUnquotedKeys);
end;

procedure TSkeletonTest.TestInput;
var
  Input: TJsonInput;
begin
  Input := TJsonInput.FromString('');
  try
    AssertFalse(Input.HasChar);
    AssertEquals(1, Input.Line);
    AssertEquals(1, Input.Column);
  finally
    Input.Free;
  end;
end;

procedure TSkeletonTest.TestEvents;
var
  Event: TJsonEvent;
begin
  Event := MakeJsonEvent(jetNull, 'null', 1, 2, 3);
  AssertTrue(Event.EventType = jetNull);
  AssertEquals('null', string(Event.EventText));
  AssertEquals(1, Event.NestLevel);
end;

procedure TSkeletonTest.TestErrors;
var
  Error: EJsonError;
begin
  Error := EJsonError.Create('The text has no value', 4, 5);
  try
    AssertEquals('The text has no value at line 4, column 5', Error.Message);
    AssertEquals(4, Error.Line);
    AssertEquals(5, Error.Column);
  finally
    Error.Free;
  end;
end;

procedure TSkeletonTest.TestScannerCore;
var
  Token: TJsonToken;
begin
  Token := MakeJsonToken(jtkLBrace, '{', 1, 1);
  AssertTrue(Token.Kind = jtkLBrace);
  AssertEquals('{', string(Token.Text));
end;

procedure TSkeletonTest.TestScanner;
var
  Input: TJsonInput;
  Scanner: TJsonScanner;
  Token: TJsonToken;
begin
  Input := TJsonInput.FromString('{}');
  Scanner := TJsonScanner.Create(Input, DefaultJsonOptions);
  try
    AssertTrue(Scanner.HasToken);
    Token := Scanner.NextToken;
    AssertTrue(Token.Kind = jtkLBrace);
    Token := Scanner.NextToken;
    AssertTrue(Token.Kind = jtkRBrace);
    AssertFalse(Scanner.HasToken);
  finally
    Scanner.Free;
    Input.Free;
  end;
end;

procedure TSkeletonTest.TestLiteral;
var
  Input: TJsonInput;
  Token: TJsonToken;
begin
  Input := TJsonInput.FromString('"a\"b"');
  try
    Token := ScanJsonString(Input, DefaultJsonOptions);
    AssertEquals('a"b', string(Token.Text));
  finally
    Input.Free;
  end;
end;

procedure TSkeletonTest.TestComment;
var
  Input: TJsonInput;
begin
  Input := TJsonInput.FromString('  1');
  try
    SkipJsonLayout(Input, DefaultJsonOptions);
    AssertEquals(Ord('1'), Input.Peek);
  finally
    Input.Free;
  end;
end;

procedure TSkeletonTest.TestParser;
begin
  AssertEquals(1000, MaxDepth);
end;

procedure TSkeletonTest.TestJson;
var
  Data: TJSONData;
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('1');
    try
      Data := Puller.Parse;
      try
        AssertTrue(Data is TJSONInt64Number);
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

procedure TSkeletonTest.TestPuller;
begin
  AssertEquals('0.1.0', JSON_PULLER_VERSION);
end;

procedure TSkeletonTest.TestHeaders;
var
  Info: TSearchRec;
  Index: Integer;
  Dir, Path: string;
  Dirs: array[0..1] of string;
  Lines: TStringList;
begin
  Dirs[0] := 'src';
  Dirs[1] := 'test';
  for Index := 0 to 1 do
  begin
    Dir := Dirs[Index];
    if FindFirst(Dir + '/*', faAnyFile, Info) <> 0 then
      Fail('The directory ' + Dir + ' is missing');
    try
      repeat
        if ((Info.Attr and faDirectory) = 0) and
          (ExtractFileExt(Info.Name) = '.pas') then
        begin
          Path := Dir + '/' + Info.Name;
          Lines := TStringList.Create;
          try
            Lines.LoadFromFile(Path);
            AssertTrue(Lines.Count > 4);
            AssertEquals('{**', Lines[0]);
            AssertEquals('license: Apache-2.0', Lines[1]);
            AssertEquals('copyright: Copyright 2026 Liam Seamus Coughlin', Lines[2]);
          finally
            Lines.Free;
          end;
        end;
      until FindNext(Info) <> 0;
    finally
      FindClose(Info);
    end;
  end;
end;

initialization
  RegisterTest(TSkeletonTest);
end.
