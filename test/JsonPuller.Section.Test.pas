{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Subsection parse tests (plan story S10).
@br
The tests check the event log, the start match, the value table, and the
stop at the end event. The ports example returns [80,443].
}
unit JsonPuller.Section.Test;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, fpjson, fpcunit, testregistry, JsonPuller, JsonPuller.Events,
  JsonPuller.Errors, JsonPuller.Input;

type
  TCountStream = class(TStream)
  public
    Data: TBytes;
    Posi: Int64;
    ReadN: Int64;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

  TSectionTest = class(TTestCase)
  published
    procedure TestLogLength;
    procedure TestOtherPuller;
    procedure TestName;
    procedure TestObjectAndScalars;
    procedure TestPortsExample;
    procedure TestStopAtEnd;
    procedure TestEmptyStructural;
  end;

implementation

function TCountStream.Read(var Buffer; Count: Longint): Longint;
var
  Avail: Int64;
begin
  Avail := Length(Data) - Posi;
  if Avail < 0 then
    Avail := 0;
  if Count < Avail then
    Result := Count
  else
    Result := Avail;
  if Result > 0 then
    Move(Data[Posi], Buffer, Result);
  Inc(Posi, Result);
  Inc(ReadN, Result);
end;

function TCountStream.Write(const Buffer; Count: Longint): Longint;
begin
  Result := 0;
end;

function TCountStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := Posi;
end;

procedure TSectionTest.TestLogLength;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Count: Integer;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('[1,2,3]');
    try
      Count := 0;
      while (Count < 3) and Puller.HasNext do
      begin
        Puller.Next;
        Inc(Count);
      end;
      AssertEquals(Count, Puller.EventLogLength);
      AssertEquals(3, Puller.EventLogLength);
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TSectionTest.TestOtherPuller;
var
  Factory: TJsonPullerFactory;
  First, Second: TJsonPuller;
  Event: TJsonEvent;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    First := Factory.FromString('"alpha"');
    Second := Factory.FromString('"beta"');
    try
      repeat
        Event := First.Next;
      until Event.EventType = jetString;
      try
        Second.Parse(Event, Data);
        Data.Free;
        Fail('The foreign event did not raise');
      except
        on E: EJsonParserError do
          AssertTrue(Pos('not part of this puller', E.Message) > 0);
      end;
    finally
      First.Free;
      Second.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TSectionTest.TestName;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Event, NextEvent: TJsonEvent;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('{"a":1}');
    try
      repeat
        Event := Puller.Next;
      until Event.EventType = jetName;
      Puller.Parse(Event, Data);
      try
        AssertTrue(Data is TJSONString);
        AssertEquals('"a"', Data.AsJSON);
      finally
        Data.Free;
      end;
      NextEvent := Puller.Next;
      AssertTrue(NextEvent.EventType = jetNumber);
      AssertEquals('1', string(NextEvent.EventText));
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TSectionTest.TestObjectAndScalars;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Event: TJsonEvent;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('{"a":[1,true,null,"s"]}');
    try
      repeat
        Event := Puller.Next;
      until Event.EventType = jetObjectStart;
      Puller.Parse(Event, Data);
      try
        AssertEquals('{"a":[1,true,null,"s"]}', Data.AsJSON);
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

procedure TSectionTest.TestPortsExample;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Event, Found: TJsonEvent;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('{"ports":[80,443],"note":"later"}');
    try
      Found := Default(TJsonEvent);
      while Puller.HasNext do
      begin
        Event := Puller.Next;
        if Event.EventType = jetArrayStart then
        begin
          Found := Event;
          Break;
        end;
      end;
      AssertTrue(Found.EventType = jetArrayStart);
      Puller.Parse(Found, Data);
      try
        AssertEquals('[80,443]', Data.AsJSON);
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

procedure TSectionTest.TestStopAtEnd;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Stream: TCountStream;
  Event, Found: TJsonEvent;
  Data: TJSONData;
  Text: UTF8String;
  Bytes: TBytes;
  Before: Int64;
  I: Integer;
begin
  Text := '{"ports":[80,443],"note":"';
  for I := 1 to 20000 do
    Text := Text + 'x';
  Text := Text + '"}';
  SetLength(Bytes, Length(Text));
  Move(Text[1], Bytes[0], Length(Text));
  Stream := TCountStream.Create;
  Factory := TJsonPullerFactory.Create;
  try
    Stream.Data := Bytes;
    Puller := Factory.FromStream(Stream);
    try
      Found := Default(TJsonEvent);
      while Puller.HasNext do
      begin
        Event := Puller.Next;
        if Event.EventType = jetArrayStart then
        begin
          Found := Event;
          Break;
        end;
      end;
      Before := Stream.ReadN;
      Puller.Parse(Found, Data);
      try
        AssertEquals('[80,443]', Data.AsJSON);
      finally
        Data.Free;
      end;
      AssertEquals(Before, Stream.ReadN);
      Event := Puller.Next;
      AssertTrue(Event.EventType = jetName);
      AssertEquals('note', string(Event.EventText));
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
    Stream.Free;
  end;
end;

procedure TSectionTest.TestEmptyStructural;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Event: TJsonEvent;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('1');
    try
      Event := Puller.Next;
      AssertTrue(Event.EventType = jetStreamStart);
      Puller.Parse(Event, Data);
      AssertNull(Data);
      while Puller.HasNext do
        Event := Puller.Next;
      AssertTrue(Event.EventType = jetStreamEnd);
      Puller.Parse(Event, Data);
      AssertNull(Data);
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

initialization
  RegisterTest(TSectionTest);
end.
