{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Input layer tests (plan story S01).
@br
The tests cover the four sources, the block bound, the copy, the byte
order marks, the rejected wide encoding, the line breaks, and the column.
}
unit JsonPuller.Input.Test;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, fpcunit, testregistry, JsonPuller.Input, JsonPuller.Errors;

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

  TInputTest = class(TTestCase)
  published
    procedure TestFourSources;
    procedure TestBlockBound;
    procedure TestCopy;
    procedure TestBomEncodings;
    procedure TestBomLessUtf8;
    procedure TestUtf16WithoutBom;
    procedure TestLineBreaks;
    procedure TestColumn;
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

function Collect(AInput: TJsonInput): UTF8String;
begin
  Result := '';
  try
    while AInput.HasChar do
    begin
      if AInput.Peek < 128 then
        Result := Result + Char(AInput.Peek)
      else
        Result := Result + Char('?');
      AInput.Next;
    end;
  finally
    AInput.Free;
  end;
end;

function BytesOfText(const AText: UTF8String): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AText));
  if Length(AText) > 0 then
    Move(AText[1], Result[0], Length(AText));
end;

procedure TInputTest.TestFourSources;
var
  Source: UTF8String;
  Bytes: TBytes;
  Stream: TMemoryStream;
  Handle: THandle;
  Name: string;
  FileText: System.Text;
begin
  Source := '{"a":1}';
  AssertEquals(Source, Collect(TJsonInput.FromString(Source)));
  Bytes := BytesOfText(Source);
  AssertEquals(Source, Collect(TJsonInput.FromBytes(Bytes)));
  Stream := TMemoryStream.Create;
  try
    Stream.WriteBuffer(Source[1], Length(Source));
    Stream.Position := 0;
    AssertEquals(Source, Collect(TJsonInput.FromStream(Stream)));
  finally
    Stream.Free;
  end;
  Name := GetTempDir(False) + 'jsonpuller-input.json';
  Assign(FileText, Name);
  Rewrite(FileText);
  Write(FileText, Source);
  Close(FileText);
  Handle := FileOpen(Name, fmOpenRead);
  try
    AssertTrue(Handle <> THandle(-1));
    AssertEquals(Source, Collect(TJsonInput.FromFile(Handle)));
  finally
    FileClose(Handle);
    DeleteFile(Name);
  end;
end;

procedure TInputTest.TestBlockBound;
var
  Stream: TCountStream;
  Input: TJsonInput;
  Body: UTF8String;
  I: Integer;
begin
  Body := '{"a":1,"pad":"';
  for I := 1 to 20000 do
    Body := Body + 'x';
  Body := Body + '"}';
  Stream := TCountStream.Create;
  try
    Stream.Data := BytesOfText(Body);
    Stream.Posi := 0;
    Stream.ReadN := 0;
    Input := TJsonInput.FromStream(Stream);
    try
      AssertTrue(Input.HasChar);
      AssertEquals(Ord('{'), Input.Peek);
      AssertTrue(Stream.ReadN <= JsonInputBlockSize);
      AssertTrue(Stream.ReadN < Length(Body));
    finally
      Input.Free;
    end;
  finally
    Stream.Free;
  end;
end;

procedure TInputTest.TestCopy;
var
  Text: UTF8String;
  Bytes: TBytes;
  Input: TJsonInput;
begin
  Text := '{"a":1}';
  Input := TJsonInput.FromString(Text);
  Text[1] := 'X';
  try
    AssertEquals('{', Char(Input.Peek));
  finally
    Input.Free;
  end;
  Bytes := BytesOfText('{"a":1}');
  Input := TJsonInput.FromBytes(Bytes);
  Bytes[0] := Ord('X');
  try
    AssertEquals('{', Char(Input.Peek));
  finally
    Input.Free;
  end;
end;

procedure TInputTest.TestBomEncodings;
var
  Bytes: TBytes;
begin
  SetLength(Bytes, 6);
  Bytes[0] := $EF;
  Bytes[1] := $BB;
  Bytes[2] := $BF;
  Bytes[3] := Ord('[');
  Bytes[4] := Ord('1');
  Bytes[5] := Ord(']');
  AssertEquals('[1]', Collect(TJsonInput.FromBytes(Bytes)));

  SetLength(Bytes, 6);
  Bytes[0] := $FF;
  Bytes[1] := $FE;
  Bytes[2] := Ord('[');
  Bytes[3] := 0;
  Bytes[4] := Ord(']');
  Bytes[5] := 0;
  AssertEquals('[]', Collect(TJsonInput.FromBytes(Bytes)));

  SetLength(Bytes, 6);
  Bytes[0] := $FE;
  Bytes[1] := $FF;
  Bytes[2] := 0;
  Bytes[3] := Ord('[');
  Bytes[4] := 0;
  Bytes[5] := Ord(']');
  AssertEquals('[]', Collect(TJsonInput.FromBytes(Bytes)));

  SetLength(Bytes, 8);
  Bytes[0] := $FF;
  Bytes[1] := $FE;
  Bytes[2] := 0;
  Bytes[3] := 0;
  Bytes[4] := Ord('{');
  Bytes[5] := 0;
  Bytes[6] := 0;
  Bytes[7] := 0;
  AssertEquals('{', Collect(TJsonInput.FromBytes(Bytes)));

  SetLength(Bytes, 8);
  Bytes[0] := 0;
  Bytes[1] := 0;
  Bytes[2] := $FE;
  Bytes[3] := $FF;
  Bytes[4] := 0;
  Bytes[5] := 0;
  Bytes[6] := 0;
  Bytes[7] := Ord('1');
  AssertEquals('1', Collect(TJsonInput.FromBytes(Bytes)));
end;

procedure TInputTest.TestBomLessUtf8;
begin
  AssertEquals('{"a":1}', Collect(TJsonInput.FromBytes(BytesOfText('{"a":1}'))));
end;

procedure TInputTest.TestUtf16WithoutBom;
var
  Bytes: TBytes;
  Input: TJsonInput;
begin
  SetLength(Bytes, 4);
  Bytes[0] := Ord('{');
  Bytes[1] := 0;
  Bytes[2] := Ord('}');
  Bytes[3] := 0;
  try
    Input := TJsonInput.FromBytes(Bytes);
    Input.Free;
    Fail('The wide text did not raise');
  except
    on E: EJsonScannerError do
      AssertTrue(Pos('at line 1, column 1', E.Message) > 0);
  end;
end;

procedure TInputTest.TestLineBreaks;
begin
  AssertEquals('a'#10'b', Collect(TJsonInput.FromString('a'#10'b')));
  AssertEquals('a'#10'b', Collect(TJsonInput.FromString('a'#13#10'b')));
  AssertEquals('a'#10'b', Collect(TJsonInput.FromString('a'#13'b')));
end;

procedure TInputTest.TestColumn;
var
  Input: TJsonInput;
begin
  Input := TJsonInput.FromString('a'#9'b'#10'c');
  try
    AssertEquals(1, Input.Line);
    AssertEquals(1, Input.Column);
    AssertEquals(Ord('a'), Input.Peek);
    Input.Next;
    AssertEquals(9, Input.Peek);
    AssertEquals(2, Input.Column);
    Input.Next;
    AssertEquals(Ord('b'), Input.Peek);
    AssertEquals(3, Input.Column);
    Input.Next;
    Input.Next;
    AssertEquals(2, Input.Line);
    AssertEquals(1, Input.Column);
    AssertEquals(Ord('c'), Input.Peek);
  finally
    Input.Free;
  end;
end;

initialization
  RegisterTest(TInputTest);
end.
