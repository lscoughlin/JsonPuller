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
  SysUtils, Classes, fpjson, fpcunit, testregistry, JsonPuller, JsonPuller.Input;

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
  private
    function BuildArrayText(ACount: Integer): UTF8String;
  published
    procedure TestPrefixRead;
    procedure TestSpanningToken;
    procedure TestReferenceText;
    procedure TestEventLog;
    procedure TestStreamingBoundedMemory5000;
    procedure TestStreamingDefaultKeepsLog5000;
    procedure TestStreamingItemsMatchWholeParse;
    procedure TestStreamingLinearTime;
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

function TStreamingTest.BuildArrayText(ACount: Integer): UTF8String;
var
  I: Integer;
begin
  Result := '[';
  for I := 0 to ACount - 1 do
  begin
    if I > 0 then
      Result := Result + ',';
    Result := Result + '{"id":' + IntToStr(I) + ',"name":"item' + IntToStr(I) + '","val":' + IntToStr(I * 2) + '}';
  end;
  Result := Result + ']';
end;

procedure TStreamingTest.TestStreamingBoundedMemory5000;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Text: UTF8String;
  Event: TJsonEvent;
  Item: TJSONData;
  ItemCount: Integer;
begin
  Text := BuildArrayText(5000);
  Factory := TJsonPullerFactory.Create;
  try
    Factory.KeepLog(False);
    Puller := Factory.FromString(Text);
    try
      Event := Puller.Next;
      AssertTrue(Event.EventType = jetStreamStart);
      Event := Puller.Next;
      AssertTrue(Event.EventType = jetArrayStart);
      ItemCount := 0;
      while Puller.HasNext do
      begin
        Event := Puller.Next;
        if Event.EventType = jetArrayEnd then
          Break;
        AssertTrue(Event.EventType = jetObjectStart);
        Puller.Parse(Event, Item);
        try
          AssertNotNull(Item);
          AssertTrue(Item is TJSONObject);
          AssertEquals(ItemCount, TJSONObject(Item).Get('id'));
          AssertTrue(Puller.EventLogLength <= 10);
        finally
          Item.Free;
        end;
        AssertTrue(Puller.EventLogLength <= 10);
        Inc(ItemCount);
      end;
      AssertEquals(5000, ItemCount);
      AssertEquals(0, Puller.EventLogLength);
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TStreamingTest.TestStreamingDefaultKeepsLog5000;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Text: UTF8String;
  Event: TJsonEvent;
  Item: TJSONData;
  ItemCount: Integer;
begin
  Text := BuildArrayText(5000);
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString(Text);
    try
      Event := Puller.Next;
      AssertTrue(Event.EventType = jetStreamStart);
      Event := Puller.Next;
      AssertTrue(Event.EventType = jetArrayStart);
      ItemCount := 0;
      while Puller.HasNext do
      begin
        Event := Puller.Next;
        if Event.EventType = jetArrayEnd then
          Break;
        AssertTrue(Event.EventType = jetObjectStart);
        Puller.Parse(Event, Item);
        try
          AssertNotNull(Item);
          AssertEquals(ItemCount, TJSONObject(Item).Get('id'));
        finally
          Item.Free;
        end;
        Inc(ItemCount);
      end;
      AssertEquals(5000, ItemCount);
      AssertTrue(Puller.EventLogLength > 30000);
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TStreamingTest.TestStreamingItemsMatchWholeParse;
var
  Factory: TJsonPullerFactory;
  PullerWhole, PullerStream: TJsonPuller;
  Text: UTF8String;
  WholeData, Item: TJSONData;
  WholeArray: TJSONArray;
  Event: TJsonEvent;
  ItemCount: Integer;
begin
  Text := BuildArrayText(500);
  Factory := TJsonPullerFactory.Create;
  try
    PullerWhole := Factory.FromString(Text);
    try
      WholeData := PullerWhole.Parse;
    finally
      PullerWhole.Free;
    end;
    try
      AssertTrue(WholeData is TJSONArray);
      WholeArray := TJSONArray(WholeData);
      AssertEquals(500, WholeArray.Count);

      Factory.KeepLog(False);
      PullerStream := Factory.FromString(Text);
      try
        PullerStream.Next;
        PullerStream.Next;
        ItemCount := 0;
        while PullerStream.HasNext do
        begin
          Event := PullerStream.Next;
          if Event.EventType = jetArrayEnd then
            Break;
          PullerStream.Parse(Event, Item);
          try
            AssertEquals('Class match at ' + IntToStr(ItemCount),
              WholeArray.Items[ItemCount].ClassName, Item.ClassName);
            AssertEquals('JSON match at ' + IntToStr(ItemCount),
              WholeArray.Items[ItemCount].AsJSON, Item.AsJSON);
            AssertEquals('Field id match',
              TJSONObject(WholeArray.Items[ItemCount]).Get('id', -1),
              TJSONObject(Item).Get('id', -1));
            AssertEquals('Field name match',
              string(TJSONObject(WholeArray.Items[ItemCount]).Get('name', '')),
              string(TJSONObject(Item).Get('name', '')));
            AssertEquals('Field val match',
              TJSONObject(WholeArray.Items[ItemCount]).Get('val', -1),
              TJSONObject(Item).Get('val', -1));
          finally
            Item.Free;
          end;
          Inc(ItemCount);
        end;
        AssertEquals(500, ItemCount);
      finally
        PullerStream.Free;
      end;
    finally
      WholeData.Free;
    end;
  finally
    Factory.Free;
  end;
end;

procedure TStreamingTest.TestStreamingLinearTime;
var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Text2500, Text5000: UTF8String;
  Event: TJsonEvent;
  Item: TJSONData;
  TStart, T2500, T5000: Int64;
  Ratio: Double;
begin
  Text2500 := BuildArrayText(2500);
  Text5000 := BuildArrayText(5000);
  Factory := TJsonPullerFactory.Create;
  try
    Factory.KeepLog(False);

    // Time for 2,500 items
    TStart := GetTickCount64;
    Puller := Factory.FromString(Text2500);
    try
      Puller.Next;
      Puller.Next;
      while Puller.HasNext do
      begin
        Event := Puller.Next;
        if Event.EventType = jetArrayEnd then Break;
        Puller.Parse(Event, Item);
        Item.Free;
      end;
    finally
      Puller.Free;
    end;
    T2500 := GetTickCount64 - TStart;
    if T2500 < 1 then
      T2500 := 1;

    // Time for 5,000 items
    TStart := GetTickCount64;
    Puller := Factory.FromString(Text5000);
    try
      Puller.Next;
      Puller.Next;
      while Puller.HasNext do
      begin
        Event := Puller.Next;
        if Event.EventType = jetArrayEnd then Break;
        Puller.Parse(Event, Item);
        Item.Free;
      end;
    finally
      Puller.Free;
    end;
    T5000 := GetTickCount64 - TStart;

    Ratio := T5000 / T2500;
    AssertTrue('Time ratio must be linear (near 2), got ' + FloatToStr(Ratio), Ratio < 4.0);
  finally
    Factory.Free;
  end;
end;

initialization
  RegisterTest(TStreamingTest);
end.
