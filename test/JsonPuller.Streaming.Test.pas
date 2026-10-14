{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Streaming and memory tests (plan story S13).
@br
A prefix read stays inside one block plus the current token. The event log
holds only the events that Next has returned.
}
unit JsonPuller.Streaming.Test;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, fpcunit, testregistry, JsonPuller, JsonPuller.Input;

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

  TStreamingTest = class(TTestCase)
  published
    procedure TestPrefixRead;
    procedure TestSpanningToken;
    procedure TestReferenceText;
    procedure TestEventLog;
  end;

implementation

uses
  JsonPuller.Events;

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

function BytesOf(const AText: UTF8String): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(AText[1], Result[0], Length(AText));
end;

procedure TStreamingTest.TestPrefixRead;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Stream: TCountStream;
  Text: UTF8String;
  I: Integer;
begin
  Text := '{"a":1,"b":"';
  for I := 1 to 20000 do
    Text := Text + 'y';
  Text := Text + '"}';
  Stream := TCountStream.Create;
  Factory := TJsonPullerFactory.Create;
  try
    Stream.Data := BytesOf(Text);
    Puller := Factory.FromStream(Stream);
    try
      Puller.Next;
      Puller.Next;
      Puller.Next;
      Puller.Next;
      AssertTrue(Stream.ReadN <= JsonInputBlockSize);
      AssertTrue(Stream.ReadN < Length(Text));
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
    Stream.Free;
  end;
end;

procedure TStreamingTest.TestSpanningToken;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Stream: TCountStream;
  Text: UTF8String;
  I: Integer;
begin
  Text := '"';
  for I := 1 to 8300 do
    Text := Text + 'z';
  Text := Text + '"';
  for I := 1 to 20000 do
    Text := Text + ' ';
  Text := Text + '1';
  Stream := TCountStream.Create;
  Factory := TJsonPullerFactory.Create;
  try
    Stream.Data := BytesOf(Text);
    Puller := Factory.FromStream(Stream);
    try
      while Puller.HasNext do
      begin
        if Puller.Next.EventType = jetString then
          Break;
      end;
      AssertTrue(Stream.ReadN > JsonInputBlockSize);
      AssertTrue(Stream.ReadN <= JsonInputBlockSize * 2);
      AssertTrue(Stream.ReadN < Length(Text));
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
    Stream.Free;
  end;
end;

procedure TStreamingTest.TestReferenceText;
var
  Stream: TFileStream;
  Text: UTF8String;
begin
  Stream := TFileStream.Create('test/fixtures/large/items.json', fmOpenRead);
  try
    SetLength(Text, Stream.Size);
    if Stream.Size > 0 then
      Stream.ReadBuffer(Text[1], Stream.Size);
  finally
    Stream.Free;
  end;
  AssertTrue(Length(Text) > JsonInputBlockSize);
end;

procedure TStreamingTest.TestEventLog;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Count: Integer;
begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('[1,2,3,4,5,6,7,8,9]');
    try
      Count := 0;
      while Count < 4 do
      begin
        Puller.Next;
        Inc(Count);
      end;
      AssertEquals(4, Puller.EventLogLength);
      AssertEquals(Count, Puller.EventLogLength);
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

initialization
  RegisterTest(TStreamingTest);
end.
