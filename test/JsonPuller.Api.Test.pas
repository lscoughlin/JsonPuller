{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Public API tests (plan stories S08 and S09).
@br
The tests check the factory defaults, the flag copy, the four sources,
the event loop, and the FCL conversion.
}
unit JsonPuller.Api.Test;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, fpjson, fpcunit, testregistry, JsonPuller,
  JsonPuller.Events, JsonPuller.Errors;

type
  TApiTest = class(TTestCase)
  published
    procedure TestInitialFlags;
    procedure TestMissingDefault;
    procedure TestFlagCopy;
    procedure TestSources;
    procedure TestEventLoop;
    procedure TestIndependence;
    procedure TestVersion;
    procedure TestScalars;
    procedure TestIntegerAndFloat;
    procedure TestNested;
    procedure TestDuplicateName;
    procedure TestRelaxedNumbers;
    procedure TestCallerOwnsResult;
  end;

implementation

procedure TApiTest.TestInitialFlags;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('{/*c*/"a":1}');
    try
      Data := Puller.Parse;
      try
        AssertEquals('{"a":1}', Data.AsJSON);
      finally
        Data.Free;
      end;
    finally
      Puller.Free;
    end;
    Puller := Factory.FromString('{host:1}');
    try
      try
        Data := Puller.Parse;
        Data.Free;
        Fail('The unquoted key did not raise');
      except
        on E: EJsonScannerError do
          AssertTrue(Pos('at line', E.Message) > 0);
      end;
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TApiTest.TestMissingDefault;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Factory.AllowMissingValues(True);
    Puller := Factory.FromString('[1,,2]');
    try
      Data := Puller.Parse;
      try
        AssertEquals('[1,2]', Data.AsJSON);
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

procedure TApiTest.TestFlagCopy;
var
  Factory: TJsonPullerFactory;
  First, Second: TJsonPuller;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Factory.AllowComments(False);
    First := Factory.FromString('{/*c*/"a":1}');
    Factory.AllowComments(True);
    Second := Factory.FromString('{/*c*/"a":1}');
    try
      try
        Data := First.Parse;
        Data.Free;
        Fail('The copied flag did not reject the comment');
      except
        on E: EJsonScannerError do
          AssertTrue(Pos('solidus', E.Message) > 0);
      end;
      Data := Second.Parse;
      try
        AssertEquals('{"a":1}', Data.AsJSON);
      finally
        Data.Free;
      end;
    finally
      First.Free;
      Second.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TApiTest.TestSources;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
  Bytes: TBytes;
  Stream: TMemoryStream;
  Source: UTF8String;
  Handle: THandle;
  Name: string;
  FileText: System.Text;
begin
  Source := '{"n":1}';
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString(Source);
    try
      Data := Puller.Parse;
      Data.Free;
    finally
      Puller.Free;
    end;
    SetLength(Bytes, Length(Source));
    Move(Source[1], Bytes[0], Length(Source));
    Puller := Factory.FromBytes(Bytes);
    try
      Data := Puller.Parse;
      try
        AssertEquals('{"n":1}', Data.AsJSON);
      finally
        Data.Free;
      end;
    finally
      Puller.Free;
    end;
    Stream := TMemoryStream.Create;
    try
      Stream.WriteBuffer(Source[1], Length(Source));
      Stream.Position := 0;
      Puller := Factory.FromStream(Stream);
      try
        Data := Puller.Parse;
        Data.Free;
      finally
        Puller.Free;
      end;
    finally
      Stream.Free;
    end;
    Name := GetTempDir(False) + 'jsonpuller-api.json';
    Assign(FileText, Name);
    Rewrite(FileText);
    Write(FileText, Source);
    Close(FileText);
    Handle := FileOpen(Name, fmOpenRead);
    try
      Puller := Factory.FromFile(Handle);
      try
        Data := Puller.Parse;
        try
          AssertEquals('{"n":1}', Data.AsJSON);
        finally
          Data.Free;
        end;
      finally
        Puller.Free;
      end;
    finally
      FileClose(Handle);
      DeleteFile(Name);
    end;
  finally
    Factory.Free;
  end;
end;

procedure TApiTest.TestEventLoop;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Event: TJsonEvent;
  Count: Integer;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('{"a":[1]}');
    try
      Count := 0;
      while Puller.HasNext do
      begin
        Event := Puller.Next;
        Inc(Count);
      end;
      AssertEquals(8, Count);
      AssertTrue(Event.EventType = jetStreamEnd);
      AssertFalse(Puller.HasNext);
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TApiTest.TestIndependence;
var
  Factory: TJsonPullerFactory;
  First, Second: TJsonPuller;
  Event: TJsonEvent;
begin
  Factory := TJsonPullerFactory.Create;
  try
    First := Factory.FromString('[1]');
    Second := Factory.FromString('[2]');
    try
      Event := First.Next;
      AssertTrue(Event.EventType = jetStreamStart);
      Event := Second.Next;
      AssertTrue(Event.EventType = jetStreamStart);
      First.Next;
      Event := Second.Next;
      AssertTrue(Event.EventType = jetArrayStart);
      Event := First.Next;
      AssertEquals('1', string(Event.EventText));
      Event := Second.Next;
      AssertEquals('2', string(Event.EventText));
    finally
      First.Free;
      Second.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TApiTest.TestVersion;
begin
  AssertEquals('0.1.0', JSON_PULLER_VERSION);
end;

procedure TApiTest.TestScalars;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('["s",1,1.5,true,false,null]');
    try
      Data := Puller.Parse;
      try
        AssertTrue(TJSONArray(Data).Items[0] is TJSONString);
        AssertTrue(TJSONArray(Data).Items[1] is TJSONInt64Number);
        AssertTrue(TJSONArray(Data).Items[2] is TJSONFloatNumber);
        AssertTrue(TJSONArray(Data).Items[3] is TJSONBoolean);
        AssertTrue(TJSONBoolean(TJSONArray(Data).Items[3]).AsBoolean);
        AssertFalse(TJSONBoolean(TJSONArray(Data).Items[4]).AsBoolean);
        AssertTrue(TJSONArray(Data).Items[5] is TJSONNull);
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

procedure TApiTest.TestIntegerAndFloat;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('1');
    try
      Data := Puller.Parse;
      try
        AssertTrue(Data is TJSONInt64Number);
        AssertEquals('1', Data.AsJSON);
      finally
        Data.Free;
      end;
    finally
      Puller.Free;
    end;
    Puller := Factory.FromString('1.5');
    try
      Data := Puller.Parse;
      try
        AssertTrue(Data is TJSONFloatNumber);
      finally
        Data.Free;
      end;
    finally
      Puller.Free;
    end;
    Puller := Factory.FromString('1e309');
    try
      try
        Data := Puller.Parse;
        Data.Free;
        Fail('The huge number did not raise');
      except
        on E: EJsonParserError do
          AssertTrue(Pos('at line 1, column 1', E.Message) > 0);
      end;
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TApiTest.TestNested;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('{"a":[1,{"b":false}]}');
    try
      Data := Puller.Parse;
      try
        AssertEquals('{"a":[1,{"b":false}]}', Data.AsJSON);
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

procedure TApiTest.TestDuplicateName;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Event: TJsonEvent;
  Names: Integer;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('{"a":1,"a":2}');
    try
      Names := 0;
      while Puller.HasNext do
      begin
        Event := Puller.Next;
        if Event.EventType = jetName then
          Inc(Names);
      end;
      AssertEquals(2, Names);
    finally
      Puller.Free;
    end;
    Puller := Factory.FromString('{"a":1,"a":2}');
    try
      try
        Data := Puller.Parse;
        Data.Free;
        Fail('The duplicate name did not raise');
      except
        on E: EJsonParserError do
          AssertTrue(Pos('at line 1, column 8', E.Message) > 0);
      end;
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TApiTest.TestRelaxedNumbers;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
  Event: TJsonEvent;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Factory.AllowLeadingZeros(True);
    Factory.AllowLeadingDecimalPoint(True);
    Puller := Factory.FromString('[007,03.14,.507]');
    try
      Event := Puller.Next;
      while Event.EventType <> jetNumber do
        Event := Puller.Next;
      AssertEquals('007', string(Event.EventText));
    finally
      Puller.Free;
    end;
    Puller := Factory.FromString('[007,03.14,.507]');
    try
      Data := Puller.Parse;
      try
        AssertTrue(TJSONArray(Data).Items[0] is TJSONInt64Number);
        AssertEquals('7', TJSONArray(Data).Items[0].AsJSON);
        AssertTrue(TJSONArray(Data).Items[1] is TJSONFloatNumber);
        AssertTrue(TJSONArray(Data).Items[2] is TJSONFloatNumber);
        AssertEquals('[7,3.1400000000000001E+000,5.0700000000000001E-001]',
          Data.AsJSON);
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

procedure TApiTest.TestCallerOwnsResult;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('[1]');
    try
      Data := Puller.Parse;
      AssertEquals('[1]', Data.AsJSON);
      Data.Free;
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

initialization
  RegisterTest(TApiTest);
end.
