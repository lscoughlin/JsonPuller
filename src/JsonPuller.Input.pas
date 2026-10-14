{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Input layer: bytes to characters (plan story S01).
@br
The layer copies a string or a byte source. The layer reads a stream or a
file in blocks of 8192 characters. A leading byte order mark selects the
encoding. A text with no mark is UTF-8. Line breaks become LF. The column
counts one per character, and a tab is one character.
}
unit JsonPuller.Input;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes;

const
  /// the read block for a stream or a file, in characters after decoding
  JsonInputBlockSize = 8192;

type
  /// the character source for the scanner
  TJsonInput = class
  private
    FChars: array of LongInt;
    FRead: Integer;
    FCount: Integer;
    FLine: Integer;
    FColumn: Integer;
    FEof: Boolean;
    FComplete: Boolean;
    FStream: TStream;
    FHandle: THandle;
    FUseHandle: Boolean;
    FSrcBuf: TBytes;
    FSrcPos: Integer;
    FSrcLen: Integer;
    FSrcEof: Boolean;
    FNoMoreSource: Boolean;
    FEncKnown: Boolean;
    FUnit: Integer;
    FChunkWant: Integer;
    FIsUtf16: Boolean;
    FIsUtf32: Boolean;
    FBigEndian: Boolean;
    FHasPush: Boolean;
    FPush: LongInt;
    FPosLine: Integer;
    FPosCol: Integer;
    procedure CopyBytes(const ABytes: TBytes);
    procedure Detect;
    function PullMore: Boolean;
    procedure EnsureEncoding;
    function ReadByte(out AByte: Byte): Boolean;
    function ReadRaw(out ACode: LongInt): Boolean;
    function ReadUtf8(out ACode: LongInt): Boolean;
    function ReadUtf16(out ACode: LongInt): Boolean;
    function ReadUtf32(out ACode: LongInt): Boolean;
    function NextNorm(out ACode: LongInt): Boolean;
    procedure AdvancePos(ACode: LongInt);
    procedure DecodeComplete;
    procedure LoadBlock;
    procedure Bad(const ACause: string);
    function Ensure: Boolean;
  public
    /// the caller keeps ownership of the stream
    constructor CreateStream(AStream: TStream);
    /// the caller keeps ownership of the handle
    constructor CreateFile(AHandle: THandle);
    destructor Destroy; override;
    /// copy a UTF-8 string and decode it
    class function FromString(const AText: UTF8String): TJsonInput;
    /// copy a byte buffer and decode it
    class function FromBytes(const ABytes: TBytes): TJsonInput;
    /// read a stream in blocks. The caller keeps the stream.
    class function FromStream(AStream: TStream): TJsonInput;
    /// read a file handle in blocks. The caller keeps the handle.
    class function FromFile(AHandle: THandle): TJsonInput;
    /// true when a character remains
    function HasChar: Boolean;
    /// the current character as a Unicode scalar value
    function Peek: LongInt;
    /// accept the current character and advance the position
    procedure Next;
    /// the 1-based line of the current character, or the end position
    property Line: Integer read FLine;
    /// the 1-based column of the current character, or the end position
    property Column: Integer read FColumn;
  end;

implementation

uses
  JsonPuller.Errors;

procedure TJsonInput.Bad(const ACause: string);
begin
  raise EJsonScannerError.Create(ACause, FPosLine, FPosCol);
end;

procedure TJsonInput.CopyBytes(const ABytes: TBytes);
var
  N: Integer;
begin
  N := Length(ABytes);
  SetLength(FSrcBuf, N);
  if N > 0 then
    Move(ABytes[0], FSrcBuf[0], N);
  FSrcPos := 0;
  FSrcLen := N;
end;

constructor TJsonInput.CreateStream(AStream: TStream);
begin
  inherited Create;
  FStream := AStream;
  FHandle := 0;
  FUseHandle := False;
  FLine := 1;
  FColumn := 1;
  FPosLine := 1;
  FPosCol := 1;
  FUnit := 1;
  FChunkWant := JsonInputBlockSize;
end;

constructor TJsonInput.CreateFile(AHandle: THandle);
begin
  inherited Create;
  FStream := nil;
  FHandle := AHandle;
  FUseHandle := True;
  FLine := 1;
  FColumn := 1;
  FPosLine := 1;
  FPosCol := 1;
  FUnit := 1;
  FChunkWant := JsonInputBlockSize;
end;

destructor TJsonInput.Destroy;
begin
  inherited Destroy;
end;

class function TJsonInput.FromString(const AText: UTF8String): TJsonInput;
var
  CopyText: UTF8String;
  Bytes: TBytes;
begin
  CopyText := AText;
  UniqueString(CopyText);
  Bytes := nil;
  SetLength(Bytes, Length(CopyText));
  if Length(CopyText) > 0 then
    Move(CopyText[1], Bytes[0], Length(CopyText));
  Result := FromBytes(Bytes);
end;

class function TJsonInput.FromBytes(const ABytes: TBytes): TJsonInput;
begin
  Result := TJsonInput.CreateStream(nil);
  Result.CopyBytes(ABytes);
  Result.FNoMoreSource := True;
  Result.DecodeComplete;
end;

class function TJsonInput.FromStream(AStream: TStream): TJsonInput;
begin
  Result := TJsonInput.CreateStream(AStream);
end;

class function TJsonInput.FromFile(AHandle: THandle): TJsonInput;
begin
  Result := TJsonInput.CreateFile(AHandle);
end;

procedure TJsonInput.Detect;
var
  N, P: Integer;
  B0, B1, B2, B3: Byte;

  function At(AOffset: Integer): Byte;
  begin
    Result := FSrcBuf[P + AOffset];
  end;

begin
  P := FSrcPos;
  N := FSrcLen - P;
  FEncKnown := True;
  FUnit := 1;
  FIsUtf16 := False;
  FIsUtf32 := False;
  FBigEndian := False;
  if N <= 0 then
    Exit;
  B0 := At(0);
  B1 := 0;
  B2 := 0;
  B3 := 0;
  if N > 1 then
    B1 := At(1);
  if N > 2 then
    B2 := At(2);
  if N > 3 then
    B3 := At(3);
  if (N >= 4) and (B0 = $FF) and (B1 = $FE) and (B2 = 0) and (B3 = 0) then
  begin
    FIsUtf32 := True;
    FBigEndian := False;
    FUnit := 4;
    Inc(FSrcPos, 4);
  end
  else if (N >= 4) and (B0 = 0) and (B1 = 0) and (B2 = $FE) and (B3 = $FF) then
  begin
    FIsUtf32 := True;
    FBigEndian := True;
    FUnit := 4;
    Inc(FSrcPos, 4);
  end
  else if (N >= 2) and (B0 = $FF) and (B1 = $FE) then
  begin
    FIsUtf16 := True;
    FBigEndian := False;
    FUnit := 2;
    Inc(FSrcPos, 2);
  end
  else if (N >= 2) and (B0 = $FE) and (B1 = $FF) then
  begin
    FIsUtf16 := True;
    FBigEndian := True;
    FUnit := 2;
    Inc(FSrcPos, 2);
  end
  else if (N >= 3) and (B0 = $EF) and (B1 = $BB) and (B2 = $BF) then
    Inc(FSrcPos, 3)
  else if ((N >= 4) and (B0 = 0) and (B1 = 0) and (B2 = 0)) or
    ((N >= 4) and (B1 = 0) and (B2 = 0) and (B3 = 0)) then
    Bad('The text has a UTF-32 encoding with no byte order mark')
  else if ((N >= 4) and (B0 = 0) and (B2 = 0)) or
    ((N >= 4) and (B1 = 0) and (B3 = 0)) or
    ((N >= 2) and (N < 4) and ((B0 = 0) or (B1 = 0))) then
    Bad('The text has a UTF-16 encoding with no byte order mark');
end;

function TJsonInput.PullMore: Boolean;
var
  Want, Got: Integer;
  Tmp: TBytes;
begin
  if FSrcPos < FSrcLen then
    Exit(True);
  if FNoMoreSource or FSrcEof then
  begin
    FSrcEof := True;
    Exit(False);
  end;
  Want := FChunkWant;
  if Want < 1 then
    Want := JsonInputBlockSize;
  Tmp := nil;
  SetLength(Tmp, Want);
  if FStream <> nil then
    Got := FStream.Read(Tmp[0], Want)
  else if FUseHandle then
    Got := FileRead(FHandle, Tmp[0], Want)
  else
    Got := 0;
  if Got <= 0 then
  begin
    FSrcEof := True;
    FNoMoreSource := True;
    Exit(False);
  end;
  SetLength(Tmp, Got);
  FSrcBuf := Tmp;
  FSrcPos := 0;
  FSrcLen := Got;
  Result := True;
end;

procedure TJsonInput.EnsureEncoding;
begin
  if FEncKnown then
    Exit;
  if FSrcPos >= FSrcLen then
    if not PullMore then
    begin
      FEncKnown := True;
      FUnit := 1;
      Exit;
    end;
  Detect;
end;

function TJsonInput.ReadByte(out AByte: Byte): Boolean;
begin
  if FSrcPos >= FSrcLen then
    if not PullMore then
      Exit(False);
  AByte := FSrcBuf[FSrcPos];
  Inc(FSrcPos);
  Result := True;
end;

procedure TJsonInput.AdvancePos(ACode: LongInt);
begin
  if ACode = 10 then
  begin
    Inc(FPosLine);
    FPosCol := 1;
  end
  else
    Inc(FPosCol);
end;

function TJsonInput.ReadUtf8(out ACode: LongInt): Boolean;
var
  B,   B1: Byte;
  Need, I: Integer;
  Cp: LongInt;
  Extra: array[0..2] of Byte;
begin
  if not ReadByte(B) then
    Exit(False);
  if B < $80 then
  begin
    ACode := B;
    Exit(True);
  end;
  if (B < $C2) or (B > $F4) then
    Bad('The text has a UTF-8 sequence that is not valid');
  if B < $E0 then
  begin
    Need := 1;
    Cp := B and $1F;
  end
  else if B < $F0 then
  begin
    Need := 2;
    Cp := B and $0F;
  end
  else
  begin
    Need := 3;
    Cp := B and $07;
  end;
  for I := 0 to Need - 1 do
  begin
    if not ReadByte(Extra[I]) then
      Bad('The text has a UTF-8 sequence that is not valid');
    if (Extra[I] and $C0) <> $80 then
      Bad('The text has a UTF-8 sequence that is not valid');
    Cp := (Cp shl 6) or (Extra[I] and $3F);
  end;
  B1 := Extra[0];
  if ((B = $E0) and (B1 < $A0)) or ((B = $ED) and (B1 >= $A0)) or
    ((B = $F0) and (B1 < $90)) or ((B = $F4) and (B1 >= $90)) then
    Bad('The text has a UTF-8 sequence that is not valid');
  if (Cp > $10FFFF) or ((Cp >= $D800) and (Cp <= $DFFF)) then
    Bad('The text has a UTF-8 sequence that is not valid');
  ACode := Cp;
  Result := True;
end;

function TJsonInput.ReadUtf16(out ACode: LongInt): Boolean;
var
  B0, B1: Byte;
  W, Low: LongInt;
begin
  if not ReadByte(B0) then
    Exit(False);
  if not ReadByte(B1) then
    Bad('The text has a UTF-16 sequence that is not valid');
  if FBigEndian then
    W := (B0 shl 8) or B1
  else
    W := (B1 shl 8) or B0;
  if (W >= $D800) and (W <= $DBFF) then
  begin
    if not ReadByte(B0) or not ReadByte(B1) then
      Bad('The text has an unpaired surrogate');
    if FBigEndian then
      Low := (B0 shl 8) or B1
    else
      Low := (B1 shl 8) or B0;
    if (Low < $DC00) or (Low > $DFFF) then
      Bad('The text has an unpaired surrogate');
    ACode := $10000 + ((W - $D800) shl 10) + (Low - $DC00);
  end
  else if (W >= $DC00) and (W <= $DFFF) then
    Bad('The text has an unpaired surrogate')
  else
    ACode := W;
  Result := True;
end;

function TJsonInput.ReadUtf32(out ACode: LongInt): Boolean;
var
  B: array[0..3] of Byte;
  I: Integer;
  Cp: LongInt;
begin
  for I := 0 to 3 do
  begin
    if not ReadByte(B[I]) then
    begin
      if I = 0 then
        Exit(False);
      Bad('The text has a UTF-32 sequence that is not valid');
    end;
  end;
  if FBigEndian then
    Cp := (B[0] shl 24) or (B[1] shl 16) or (B[2] shl 8) or B[3]
  else
    Cp := (B[3] shl 24) or (B[2] shl 16) or (B[1] shl 8) or B[0];
  if (Cp > $10FFFF) or ((Cp >= $D800) and (Cp <= $DFFF)) then
    Bad('The text has a UTF-32 sequence that is not valid');
  ACode := Cp;
  Result := True;
end;

function TJsonInput.ReadRaw(out ACode: LongInt): Boolean;
begin
  if FHasPush then
  begin
    ACode := FPush;
    FHasPush := False;
    Exit(True);
  end;
  EnsureEncoding;
  if FIsUtf32 then
    Result := ReadUtf32(ACode)
  else if FIsUtf16 then
    Result := ReadUtf16(ACode)
  else
    Result := ReadUtf8(ACode);
end;

function TJsonInput.NextNorm(out ACode: LongInt): Boolean;
var
  Next: LongInt;
begin
  if not ReadRaw(ACode) then
    Exit(False);
  if ACode = 13 then
  begin
    if ReadRaw(Next) then
    begin
      if Next <> 10 then
      begin
        FPush := Next;
        FHasPush := True;
      end;
    end;
    ACode := 10;
  end;
  Result := True;
end;

procedure TJsonInput.DecodeComplete;
var
  Code, N, Cap: LongInt;
begin
  N := 0;
  Cap := 0;
  while NextNorm(Code) do
  begin
    if N >= Cap then
    begin
      if Cap < 64 then
        Cap := 64
      else
        Cap := Cap * 2;
      SetLength(FChars, Cap);
    end;
    FChars[N] := Code;
    AdvancePos(Code);
    Inc(N);
  end;
  SetLength(FChars, N);
  FCount := N;
  FRead := 0;
  FComplete := True;
end;

procedure TJsonInput.LoadBlock;
var
  Code, N: Integer;
begin
  if FEof or FComplete then
    Exit;
  SetLength(FChars, JsonInputBlockSize);
  N := 0;
  while N < JsonInputBlockSize do
  begin
    FChunkWant := (JsonInputBlockSize - N) * FUnit;
    if not FEncKnown then
      FChunkWant := JsonInputBlockSize;
    if FChunkWant < 1 then
      FChunkWant := 1;
    if not NextNorm(Code) then
      Break;
    FChars[N] := Code;
    AdvancePos(Code);
    Inc(N);
  end;
  FCount := N;
  FRead := 0;
  if N = 0 then
    FEof := True;
end;

function TJsonInput.Ensure: Boolean;
begin
  if FRead < FCount then
    Exit(True);
  if FComplete or FEof then
  begin
    FEof := True;
    Exit(False);
  end;
  LoadBlock;
  Result := FRead < FCount;
end;

function TJsonInput.HasChar: Boolean;
begin
  Result := Ensure;
end;

function TJsonInput.Peek: LongInt;
begin
  if not Ensure then
    raise EJsonScannerError.Create('The text has no character', FLine, FColumn);
  Result := FChars[FRead];
end;

procedure TJsonInput.Next;
var
  Code: LongInt;
begin
  if not Ensure then
    Exit;
  Code := FChars[FRead];
  Inc(FRead);
  if Code = 10 then
  begin
    Inc(FLine);
    FColumn := 1;
  end
  else
    Inc(FColumn);
end;

end.
