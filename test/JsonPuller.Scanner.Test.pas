{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Scanner tests for punctuation, literals, comments, and identifiers
(plan stories S03, S04, S05, and S06).
@br
The tests read one token at a time. An early stop leaves the tail unread.
}
unit JsonPuller.Scanner.Test;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, fpcunit, testregistry, JsonPuller, JsonPuller.Support;

type
  TScannerTest = class(TTestCase)
  published
    procedure TestPunctuation;
    procedure TestEarlyStop;
    procedure TestStringAndEscapes;
    procedure TestSurrogate;
    procedure TestRawControl;
    procedure TestNumbers;
    procedure TestLeadingZeros;
    procedure TestLeadingDot;
    procedure TestLiterals;
    procedure TestSingleQuotes;
    procedure TestQuoteEscape;
    procedure TestComments;
    procedure TestHash;
    procedure TestIdentifiers;
  end;

implementation

uses
  JsonPuller.Options, JsonPuller.Events, JsonPuller.Errors, JsonPuller.Input;

function Defaults: TJsonOptions;
begin
  Result := DefaultJsonOptions;
end;

procedure TScannerTest.TestPunctuation;
var
  Events: TEventList;
begin
  Events := CollectEvents('{}', Defaults);
  AssertEquals(4, Length(Events));
  AssertTrue(Events[1].EventType = jetObjectStart);
  AssertTrue(Events[2].EventType = jetObjectEnd);
  Events := CollectEvents('[]', Defaults);
  AssertTrue(Events[1].EventType = jetArrayStart);
  AssertTrue(Events[2].EventType = jetArrayEnd);
end;

procedure TScannerTest.TestEarlyStop;
var
  Puller: TJsonPuller;
  Event: TJsonEvent;
begin
  Puller := Pull('[1,2,3,4,5]', Defaults);
  try
    Event := Puller.Next;
    AssertTrue(Event.EventType = jetStreamStart);
    Event := Puller.Next;
    AssertTrue(Event.EventType = jetArrayStart);
    Event := Puller.Next;
    AssertEquals('1', string(Event.EventText));
    AssertEquals(3, Puller.EventLogLength);
  finally
    Puller.Free;
  end;
end;

procedure TScannerTest.TestStringAndEscapes;
var
  Events: TEventList;
begin
  Events := CollectEvents('"a\"b"', Defaults);
  AssertEquals('a"b', string(Events[1].EventText));
  Events := CollectEvents('"\"\\\/\b\f\n\r\t"', Defaults);
  AssertEquals('"'#92'/'#8#12#10#13#9, string(Events[1].EventText));
  AssertTrue(Pos('at line 1, column 1',
    ErrorMessage('"unterminated', Defaults)) > 0);
end;

procedure TScannerTest.TestSurrogate;
var
  Events: TEventList;
  Text: string;
begin
  Events := CollectEvents('"\uD83D\uDE00"', Defaults);
  Text := string(Events[1].EventText);
  AssertEquals(4, Length(Text));
  AssertEquals(#$F0, Text[1]);
  AssertEquals(#$9F, Text[2]);
  AssertEquals(#$98, Text[3]);
  AssertEquals(#$80, Text[4]);
  AssertTrue(Pos('at line 1, column 2',
    ErrorMessage('"\uD800"', Defaults)) > 0);
  AssertTrue(Pos('EJsonScannerError', ErrorMessage('"\uDE00"', Defaults)) > 0);
end;

procedure TScannerTest.TestRawControl;
begin
  AssertTrue(Pos('at line 1, column 2',
    ErrorMessage('"'#10'"', Defaults)) > 0);
  AssertTrue(Pos('control character',
    ErrorMessage('"'#0'x"', Defaults)) > 0);
end;

procedure TScannerTest.TestNumbers;
var
  Events: TEventList;
begin
  Events := CollectEvents('-1.5e+2', Defaults);
  AssertTrue(Events[1].EventType = jetNumber);
  AssertEquals('-1.5e+2', string(Events[1].EventText));
  Events := CollectEvents('0', Defaults);
  AssertEquals('0', string(Events[1].EventText));
  Events := CollectEvents('1e007', Defaults);
  AssertEquals('1e007', string(Events[1].EventText));
  AssertTrue(Pos('at line 1, column 1', ErrorMessage('+1', Defaults)) > 0);
  AssertTrue(Pos('at line 1, column 2', ErrorMessage('1.', Defaults)) > 0);
  AssertTrue(Pos('at line 1, column 1', ErrorMessage('007', Defaults)) > 0);
end;

procedure TScannerTest.TestLeadingZeros;
var
  Options: TJsonOptions;
  Events: TEventList;
begin
  Options := Defaults;
  Options.AllowLeadingZeros := True;
  Events := CollectEvents('007', Options);
  AssertEquals('007', string(Events[1].EventText));
  Events := CollectEvents('03.14', Options);
  AssertEquals('03.14', string(Events[1].EventText));
  Events := CollectEvents('-007', Options);
  AssertEquals('-007', string(Events[1].EventText));
  Events := CollectEvents('00', Options);
  AssertEquals('00', string(Events[1].EventText));
  AssertTrue(Pos('at line 1, column 1', ErrorMessage('007', Defaults)) > 0);
  Events := CollectEvents('0', Defaults);
  AssertEquals('0', string(Events[1].EventText));
end;

procedure TScannerTest.TestLeadingDot;
var
  Options: TJsonOptions;
  Events: TEventList;
begin
  Options := Defaults;
  Options.AllowLeadingDecimalPoint := True;
  Events := CollectEvents('.507', Options);
  AssertEquals('.507', string(Events[1].EventText));
  Events := CollectEvents('-.507', Options);
  AssertEquals('-.507', string(Events[1].EventText));
  Events := CollectEvents('.5e1', Options);
  AssertEquals('.5e1', string(Events[1].EventText));
  AssertTrue(Pos('at line 1, column 1', ErrorMessage('.507', Defaults)) > 0);
  AssertTrue(Pos('decimal point', ErrorMessage('.', Options)) > 0);
  AssertTrue(Pos('decimal point', ErrorMessage('.', Defaults)) > 0);
end;

procedure TScannerTest.TestLiterals;
var
  Events: TEventList;
begin
  Events := CollectEvents('true', Defaults);
  AssertTrue(Events[1].EventType = jetTrue);
  AssertEquals('true', string(Events[1].EventText));
  Events := CollectEvents('false', Defaults);
  AssertTrue(Events[1].EventType = jetFalse);
  Events := CollectEvents('null', Defaults);
  AssertTrue(Events[1].EventType = jetNull);
  AssertTrue(Pos('EJsonScannerError', ErrorMessage('True', Defaults)) > 0);
end;

procedure TScannerTest.TestSingleQuotes;
var
  Options: TJsonOptions;
begin
  Options := Defaults;
  Options.AllowSingleQuotes := True;
  AssertEquals('say "hi"',
    string(CollectEvents('''say "hi"''', Options)[1].EventText));
  AssertEquals('it'#39's',
    string(CollectEvents('"it'#39's"', Defaults)[1].EventText));
  AssertEquals('{"a":"b","c":"d"}',
    JsonText('{"a": '#39'b'#39', '#39'c'#39': "d"}', Options));
  AssertTrue(Pos('at line 1, column 1', ErrorMessage('''text''', Defaults)) > 0);
end;

procedure TScannerTest.TestQuoteEscape;
var
  Options: TJsonOptions;
begin
  Options := Defaults;
  Options.AllowSingleQuotes := True;
  AssertEquals('it'#39's',
    string(CollectEvents('''' + 'it\' + '''' + 's' + '''', Options)[1].EventText));
  AssertEquals('it'#39's',
    string(CollectEvents('"it\' + '''' + 's"', Options)[1].EventText));
  AssertTrue(Pos('escape',
    ErrorMessage('"it\' + '''' + 's"', Defaults)) > 0);
end;

procedure TScannerTest.TestComments;
var
  Options: TJsonOptions;
  Events: TEventList;
begin
  Events := CollectEvents('{ /* c' + #10 + '*/ "a": 1 }', Defaults);
  AssertEquals('a', string(Events[2].EventText));
  AssertEquals(2, Events[2].Line);
  Events := CollectEvents('"//"', Defaults);
  AssertEquals('//', string(Events[1].EventText));
  Events := CollectEvents('"/*"', Defaults);
  AssertEquals('/*', string(Events[1].EventText));
  AssertTrue(Pos('at line 1, column 1', ErrorMessage('/* unterminated', Defaults)) > 0);
  Options := Defaults;
  Options.AllowComments := False;
  AssertTrue(Pos('at line 1, column 1',
    ErrorMessage('// comment'#10'1', Options)) > 0);
end;

procedure TScannerTest.TestHash;
var
  Options: TJsonOptions;
begin
  AssertTrue(Pos('at line 1, column 1', ErrorMessage('# comment', Defaults)) > 0);
  Options := Defaults;
  Options.AllowComments := False;
  AssertTrue(Pos('#', ErrorMessage('# comment', Options)) > 0);
end;

procedure TScannerTest.TestIdentifiers;
var
  Options: TJsonOptions;
  Events: TEventList;
begin
  Options := Defaults;
  Options.AllowUnquotedKeys := True;
  Events := CollectEvents('{host: 1}', Options);
  AssertTrue(Events[2].EventType = jetName);
  AssertEquals('host', string(Events[2].EventText));
  Events := CollectEvents('{$id_1: 1}', Options);
  AssertEquals('$id_1', string(Events[2].EventText));
  AssertTrue(Pos('at line 1, column 1', ErrorMessage('host', Defaults)) > 0);
  AssertTrue(Pos('EJson', ErrorMessage('{my-key: 1}', Options)) > 0);
  Events := CollectEvents('{"caf' + #$C3#$A9 + '": 1}', Options);
  AssertTrue(Events[2].EventType = jetName);
  Events := CollectEvents('{true: false}', Options);
  AssertTrue(Events[2].EventType = jetName);
  AssertTrue(Events[3].EventType = jetFalse);
  AssertEquals('true', string(Events[2].EventText));
end;

initialization
  RegisterTest(TScannerTest);
end.
