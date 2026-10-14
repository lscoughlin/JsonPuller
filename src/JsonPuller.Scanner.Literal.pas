{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Literal tokens: strings, numbers, words, and identifiers (plan stories S04 and S06).
@br
A string token holds the decoded text. A number token holds the source
spelling. The literals true, false, and null are lowercase. An identifier
exists only when unquoted keys are accepted.
}
unit JsonPuller.Scanner.Literal;

{$mode delphi}{$H+}

interface

uses
  JsonPuller.Input, JsonPuller.Options, JsonPuller.Scanner.Core;

/// true when the scalar can start an identifier
function IsIdentStart(ACode: LongInt): Boolean;

/// scan one string. The opening quote selects the closer.
function ScanJsonString(AInput: TJsonInput;
  const AOptions: TJsonOptions): TJsonToken;

/// scan one number. The token text is the source spelling.
function ScanJsonNumber(AInput: TJsonInput;
  const AOptions: TJsonOptions): TJsonToken;

/// scan one literal or one identifier
function ScanJsonWord(AInput: TJsonInput;
  const AOptions: TJsonOptions): TJsonToken;

implementation

uses
  SysUtils, JsonPuller.Errors;

function IsIdentStart(ACode: LongInt): Boolean;
begin
  Result := ((ACode >= Ord('A')) and (ACode <= Ord('Z'))) or
    ((ACode >= Ord('a')) and (ACode <= Ord('z'))) or
    (ACode = Ord('_')) or (ACode = Ord('$'));
end;

function IsDigit(ACode: LongInt): Boolean;
begin
  Result := (ACode >= Ord('0')) and (ACode <= Ord('9'));
end;

function IsIdentCont(ACode: LongInt): Boolean;
begin
  Result := IsIdentStart(ACode) or IsDigit(ACode);
end;

procedure AddUtf8(var AText: UTF8String; var ALen: Integer; ACode: LongInt);
var
  Bytes: array[0..3] of Byte;
  N, I: Integer;
begin
  if ACode < $80 then
  begin
    N := 1;
    Bytes[0] := Byte(ACode);
  end
  else if ACode < $800 then
  begin
    N := 2;
    Bytes[0] := Byte($C0 or (ACode shr 6));
    Bytes[1] := Byte($80 or (ACode and $3F));
  end
  else if ACode < $10000 then
  begin
    N := 3;
    Bytes[0] := Byte($E0 or (ACode shr 12));
    Bytes[1] := Byte($80 or ((ACode shr 6) and $3F));
    Bytes[2] := Byte($80 or (ACode and $3F));
  end
  else
  begin
    N := 4;
    Bytes[0] := Byte($F0 or (ACode shr 18));
    Bytes[1] := Byte($80 or ((ACode shr 12) and $3F));
    Bytes[2] := Byte($80 or ((ACode shr 6) and $3F));
    Bytes[3] := Byte($80 or (ACode and $3F));
  end;
  if ALen + N > Length(AText) then
  begin
    if Length(AText) < 32 then
      SetLength(AText, 32)
    else
      SetLength(AText, Length(AText) * 2);
    if ALen + N > Length(AText) then
      SetLength(AText, ALen + N);
  end;
  for I := 0 to N - 1 do
  begin
    Inc(ALen);
    AText[ALen] := Char(Bytes[I]);
  end;
end;

function HexValue(ACode: LongInt): Integer;
begin
  if (ACode >= Ord('0')) and (ACode <= Ord('9')) then
    Result := ACode - Ord('0')
  else if (ACode >= Ord('a')) and (ACode <= Ord('f')) then
    Result := ACode - Ord('a') + 10
  else if (ACode >= Ord('A')) and (ACode <= Ord('F')) then
    Result := ACode - Ord('A') + 10
  else
    Result := -1;
end;

function ScanJsonString(AInput: TJsonInput;
  const AOptions: TJsonOptions): TJsonToken;
var
  Quote, Code, StartLine, StartCol, EscLine, EscCol: LongInt;
  UnitCode, Low: LongInt;
  Text: UTF8String;
  Len, I, Hex: Integer;
begin
  Quote := AInput.Peek;
  StartLine := AInput.Line;
  StartCol := AInput.Column;
  if (Quote = Ord('''')) and (not AOptions.AllowSingleQuotes) then
    raise EJsonScannerError.Create(
      'The text has a single quote', StartLine, StartCol);
  AInput.Next;
  Text := '';
  Len := 0;
  while AInput.HasChar do
  begin
    Code := AInput.Peek;
    if Code = Quote then
    begin
      AInput.Next;
      SetLength(Text, Len);
      Exit(MakeJsonToken(jtkString, Text, StartLine, StartCol));
    end;
    if (Code >= 0) and (Code < 32) then
      raise EJsonScannerError.Create(
        'The string has a control character', AInput.Line, AInput.Column);
    if Code = Ord('\') then
    begin
      EscLine := AInput.Line;
      EscCol := AInput.Column;
      AInput.Next;
      if not AInput.HasChar then
        raise EJsonScannerError.Create(
          'The string has an escape that is not valid', EscLine, EscCol);
      Code := AInput.Peek;
      AInput.Next;
      case Code of
        Ord('"'): AddUtf8(Text, Len, Ord('"'));
        Ord('\'): AddUtf8(Text, Len, Ord('\'));
        Ord('/'): AddUtf8(Text, Len, Ord('/'));
        Ord('b'): AddUtf8(Text, Len, 8);
        Ord('f'): AddUtf8(Text, Len, 12);
        Ord('n'): AddUtf8(Text, Len, 10);
        Ord('r'): AddUtf8(Text, Len, 13);
        Ord('t'): AddUtf8(Text, Len, 9);
        Ord(''''):
          if AOptions.AllowSingleQuotes then
            AddUtf8(Text, Len, Ord(''''))
          else
            raise EJsonScannerError.Create(
              'The string has an escape that is not valid', EscLine, EscCol);
        Ord('u'):
          begin
            UnitCode := 0;
            for I := 1 to 4 do
            begin
              if not AInput.HasChar then
                raise EJsonScannerError.Create(
                  'The string has an escape that is not valid', EscLine, EscCol);
              Hex := HexValue(AInput.Peek);
              if Hex < 0 then
                raise EJsonScannerError.Create(
                  'The string has an escape that is not valid', EscLine, EscCol);
              UnitCode := (UnitCode shl 4) or Hex;
              AInput.Next;
            end;
            if (UnitCode >= $D800) and (UnitCode <= $DBFF) then
            begin
              if (not AInput.HasChar) or (AInput.Peek <> Ord('\')) then
                raise EJsonScannerError.Create(
                  'The string has an unpaired surrogate', EscLine, EscCol);
              AInput.Next;
              if (not AInput.HasChar) or (AInput.Peek <> Ord('u')) then
                raise EJsonScannerError.Create(
                  'The string has an unpaired surrogate', EscLine, EscCol);
              AInput.Next;
              Low := 0;
              for I := 1 to 4 do
              begin
                if not AInput.HasChar then
                  raise EJsonScannerError.Create(
                    'The string has an unpaired surrogate', EscLine, EscCol);
                Hex := HexValue(AInput.Peek);
                if Hex < 0 then
                  raise EJsonScannerError.Create(
                    'The string has an unpaired surrogate', EscLine, EscCol);
                Low := (Low shl 4) or Hex;
                AInput.Next;
              end;
              if (Low < $DC00) or (Low > $DFFF) then
                raise EJsonScannerError.Create(
                  'The string has an unpaired surrogate', EscLine, EscCol);
              UnitCode := $10000 + ((UnitCode - $D800) shl 10) + (Low - $DC00);
            end
            else if (UnitCode >= $DC00) and (UnitCode <= $DFFF) then
              raise EJsonScannerError.Create(
                'The string has an unpaired surrogate', EscLine, EscCol);
            AddUtf8(Text, Len, UnitCode);
          end;
      else
        raise EJsonScannerError.Create(
          'The string has an escape that is not valid', EscLine, EscCol);
      end;
    end
    else
    begin
      AddUtf8(Text, Len, Code);
      AInput.Next;
    end;
  end;
  raise EJsonScannerError.Create('The string has no end', StartLine, StartCol);
end;

function ScanJsonNumber(AInput: TJsonInput;
  const AOptions: TJsonOptions): TJsonToken;
var
  StartLine, StartCol, DotLine, DotCol, ExpLine, ExpCol, ZeroLine, ZeroCol: LongInt;
  Text: UTF8String;

  procedure Take;
  begin
    Text := Text + Char(AInput.Peek);
    AInput.Next;
  end;

  function HasDigit: Boolean;
  begin
    Result := AInput.HasChar and IsDigit(AInput.Peek);
  end;

  procedure TakeDigits;
  begin
    while HasDigit do
      Take;
  end;

  procedure TakeExponent;
  begin
    if not AInput.HasChar then
      Exit;
    if (AInput.Peek <> Ord('e')) and (AInput.Peek <> Ord('E')) then
      Exit;
    ExpLine := AInput.Line;
    ExpCol := AInput.Column;
    Take;
    if AInput.HasChar and
      ((AInput.Peek = Ord('+')) or (AInput.Peek = Ord('-'))) then
      Take;
    if not HasDigit then
      raise EJsonScannerError.Create(
        'The number has an exponent with no digit', ExpLine, ExpCol);
    TakeDigits;
  end;

  procedure TakeFraction(ARequired: Boolean);
  begin
    if not AInput.HasChar then
    begin
      if ARequired then
        raise EJsonScannerError.Create(
          'The number has a decimal point with no digit', DotLine, DotCol);
      Exit;
    end;
    if AInput.Peek <> Ord('.') then
    begin
      if ARequired then
        raise EJsonScannerError.Create(
          'The number has a decimal point with no digit', DotLine, DotCol);
      Exit;
    end;
    DotLine := AInput.Line;
    DotCol := AInput.Column;
    Take;
    if not HasDigit then
      raise EJsonScannerError.Create(
        'The number has a decimal point with no digit', DotLine, DotCol);
    TakeDigits;
  end;

begin
  StartLine := AInput.Line;
  StartCol := AInput.Column;
  Text := '';
  if AInput.Peek = Ord('+') then
    raise EJsonScannerError.Create(
      'The number has a leading plus', StartLine, StartCol);
  if AInput.Peek = Ord('-') then
    Take;
  if AInput.HasChar and (AInput.Peek = Ord('.')) then
  begin
    if not AOptions.AllowLeadingDecimalPoint then
      raise EJsonScannerError.Create(
        'The number starts with a decimal point', AInput.Line, AInput.Column);
    DotLine := AInput.Line;
    DotCol := AInput.Column;
    TakeFraction(True);
  end
  else
  begin
    if not HasDigit then
      raise EJsonScannerError.Create(
        'The number has no digit', StartLine, StartCol);
    if AInput.Peek = Ord('0') then
    begin
      ZeroLine := AInput.Line;
      ZeroCol := AInput.Column;
      Take;
      if HasDigit then
      begin
        if not AOptions.AllowLeadingZeros then
          raise EJsonScannerError.Create(
            'The number has a leading zero', ZeroLine, ZeroCol);
        TakeDigits;
      end;
    end
    else
      TakeDigits;
    TakeFraction(False);
  end;
  TakeExponent;
  Result := MakeJsonToken(jtkNumber, Text, StartLine, StartCol);
end;

function ScanJsonWord(AInput: TJsonInput;
  const AOptions: TJsonOptions): TJsonToken;
var
  StartLine, StartCol: LongInt;
  Text: UTF8String;
  Kind: TJsonTokenKind;
begin
  StartLine := AInput.Line;
  StartCol := AInput.Column;
  Text := '';
  while AInput.HasChar and IsIdentCont(AInput.Peek) do
  begin
    if (Text = '') and (not IsIdentStart(AInput.Peek)) then
      Break;
    Text := Text + Char(AInput.Peek);
    AInput.Next;
  end;
  if Text = 'true' then
    Kind := jtkTrue
  else if Text = 'false' then
    Kind := jtkFalse
  else if Text = 'null' then
    Kind := jtkNull
  else if AOptions.AllowUnquotedKeys then
    Kind := jtkIdentifier
  else
    raise EJsonScannerError.Create(
      'The identifier is not accepted', StartLine, StartCol);
  Result := MakeJsonToken(Kind, Text, StartLine, StartCol);
end;

end.
