{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Parser state machine tests (plan story S07).
@br
The tests check the event sequence, the nest levels, the name role, the
comma rules, the missing-value rules, and the depth bound.
}
unit JsonPuller.Parser.Test;

{$mode delphi}{$H+}

interface

uses
  SysUtils, fpcunit, testregistry, JsonPuller.Support;

type
  TParserTest = class(TTestCase)
  published
    procedure TestNestLevels;
    procedure TestNameAndValue;
    procedure TestEmptyCollections;
    procedure TestOneValue;
    procedure TestTrailingComma;
    procedure TestMissingValues;
    procedure TestUnquotedNames;
    procedure TestQuotedNamesOnly;
    procedure TestDepth;
    procedure TestCombination;
  end;

implementation

uses
  JsonPuller.Events, JsonPuller.Options;

function Defaults: TJsonOptions;
begin
  Result := DefaultJsonOptions;
end;

procedure TParserTest.TestNestLevels;
var
  Events: TEventList;
begin
  Events := CollectEvents('{"a":[1]}', Defaults);
  AssertEquals(8, Length(Events));
  AssertTrue(Events[0].EventType = jetStreamStart);
  AssertEquals(0, Events[0].NestLevel);
  AssertTrue(Events[1].EventType = jetObjectStart);
  AssertEquals(0, Events[1].NestLevel);
  AssertTrue(Events[2].EventType = jetName);
  AssertEquals('a', string(Events[2].EventText));
  AssertEquals(1, Events[2].NestLevel);
  AssertEquals(2, Events[2].Column);
  AssertTrue(Events[3].EventType = jetArrayStart);
  AssertEquals(1, Events[3].NestLevel);
  AssertTrue(Events[4].EventType = jetNumber);
  AssertEquals('1', string(Events[4].EventText));
  AssertEquals(2, Events[4].NestLevel);
  AssertTrue(Events[5].EventType = jetArrayEnd);
  AssertEquals(1, Events[5].NestLevel);
  AssertTrue(Events[6].EventType = jetObjectEnd);
  AssertEquals(0, Events[6].NestLevel);
  AssertTrue(Events[7].EventType = jetStreamEnd);
  AssertEquals(0, Events[7].NestLevel);
end;

procedure TParserTest.TestNameAndValue;
var
  Events: TEventList;
begin
  Events := CollectEvents('{"a":1}', Defaults);
  AssertTrue(Events[2].EventType = jetName);
  AssertTrue(Events[3].EventType = jetNumber);
  AssertEquals('1', string(Events[3].EventText));
end;

procedure TParserTest.TestEmptyCollections;
var
  Events: TEventList;
begin
  Events := CollectEvents('{}', Defaults);
  AssertTrue(Events[1].EventType = jetObjectStart);
  AssertTrue(Events[2].EventType = jetObjectEnd);
  Events := CollectEvents('[]', Defaults);
  AssertTrue(Events[1].EventType = jetArrayStart);
  AssertTrue(Events[2].EventType = jetArrayEnd);
end;

procedure TParserTest.TestOneValue;
begin
  AssertTrue(Pos('at line 1, column 1', ErrorMessage('', Defaults)) > 0);
  AssertTrue(Pos('at line 1, column 3', ErrorMessage('1 2', Defaults)) > 0);
end;

procedure TParserTest.TestTrailingComma;
var
  Options: TJsonOptions;
begin
  Options := Defaults;
  Options.AllowTrailingCommas := True;
  AssertEquals('[1,2]', JsonText('[1, 2, ]', Options));
  AssertEquals('{"a":1}', JsonText('{ "a": 1, }', Options));
  AssertTrue(Pos('trailing comma', ErrorMessage('[1,]', Defaults)) > 0);
  AssertTrue(Pos('before the first', ErrorMessage('{,}', Options)) > 0);
  AssertTrue(Pos('before the first', ErrorMessage('[,1]', Options)) > 0);
end;

procedure TParserTest.TestMissingValues;
var
  Options: TJsonOptions;
begin
  Options := Defaults;
  Options.AllowMissingValues := True;
  Options.MissingAsNull := False;
  AssertEquals('[1,2]', JsonText('[1,,2]', Options));
  AssertEquals('[1,2]', JsonText('[1,,,2]', Options));
  AssertEquals('[1]', JsonText('[1,,]', Options));
  AssertEquals('{"a":1,"b":2}', JsonText('{"a": 1,, "b": 2}', Options));
  AssertTrue(Pos('trailing comma', ErrorMessage('[1,]', Options)) > 0);
  Options.MissingAsNull := True;
  AssertEquals('[1,null,2]', JsonText('[1,,2]', Options));
  AssertEquals('[1,null,null,2]', JsonText('[1,,,2]', Options));
  AssertEquals('{"a":1,"b":2}', JsonText('{"a": 1,, "b": 2}', Options));
  AssertTrue(Pos('missing value', ErrorMessage('[1,,2]', Defaults)) > 0);
  AssertTrue(Pos('before the first', ErrorMessage('[,,]', Options)) > 0);
end;

procedure TParserTest.TestUnquotedNames;
var
  Options: TJsonOptions;
  Events: TEventList;
begin
  Options := Defaults;
  Options.AllowUnquotedKeys := True;
  Events := CollectEvents('{true: false}', Options);
  AssertTrue(Events[2].EventType = jetName);
  AssertEquals('true', string(Events[2].EventText));
  AssertTrue(Events[3].EventType = jetFalse);
  Events := CollectEvents('{1: "one"}', Options);
  AssertEquals('1', string(Events[2].EventText));
  Options.AllowLeadingZeros := True;
  Events := CollectEvents('{007: "one"}', Options);
  AssertEquals('007', string(Events[2].EventText));
end;

procedure TParserTest.TestQuotedNamesOnly;
begin
  AssertTrue(Pos('needs quotes', ErrorMessage('{1: "one"}', Defaults)) > 0);
  AssertTrue(Pos('needs quotes', ErrorMessage('{true: false}', Defaults)) > 0);
end;

procedure TParserTest.TestDepth;
var
  Text: UTF8String;
  I: Integer;
begin
  Text := '';
  for I := 1 to 1000 do
    Text := Text + '[';
  Text := Text + '1';
  for I := 1 to 1000 do
    Text := Text + ']';
  AssertTrue(Length(JsonText(Text, Defaults)) > 1000);
  Text := '[' + Text;
  AssertTrue(Pos('nest level', ErrorMessage(Text, Defaults)) > 0);
end;

procedure TParserTest.TestCombination;
var
  Options: TJsonOptions;
  Text: UTF8String;
begin
  Options := Defaults;
  Options.AllowUnquotedKeys := True;
  Options.AllowTrailingCommas := True;
  Options.AllowSingleQuotes := True;
  Text := '{' + #10 +
    '  // endpoint' + #10 +
    '  host: "localhost",' + #10 +
    '  label: ''primary'',' + #10 +
    '  ports: [80, 443,],' + #10 +
    '}';
  AssertEquals('{"host":"localhost","label":"primary","ports":[80,443]}',
    JsonText(Text, Options));
end;

initialization
  RegisterTest(TParserTest);
end.
