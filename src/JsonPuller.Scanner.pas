{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Scanner driver: one token on request (plan story S03).
@br
The driver reads characters and produces one token. The family units
supply the literal and comment functions. The scanner holds the current
token only.
}
unit JsonPuller.Scanner;

{$mode delphi}{$H+}

interface

uses
  JsonPuller.Input, JsonPuller.Options, JsonPuller.Scanner.Core;

type
  /// the scanner. NextToken returns one token. HasToken is false at the
  /// end of the text.
  TJsonScanner = class
  private
    FInput: TJsonInput;
    FOptions: TJsonOptions;
    FToken: TJsonToken;
    FLoaded: Boolean;
    procedure Load;
    function ScanOne: TJsonToken;
  public
    constructor Create(AInput: TJsonInput; const AOptions: TJsonOptions);
    /// true when a token remains
    function HasToken: Boolean;
    /// the next token. The end token has kind jtkEnd.
    function NextToken: TJsonToken;
  end;

implementation

uses
  JsonPuller.Errors, JsonPuller.Scanner.Comment, JsonPuller.Scanner.Literal;

constructor TJsonScanner.Create(AInput: TJsonInput; const AOptions: TJsonOptions);
begin
  inherited Create;
  FInput := AInput;
  FOptions := AOptions;
  FLoaded := False;
end;

function TJsonScanner.ScanOne: TJsonToken;
var
  Code, Line, Column: LongInt;
begin
  Code := FInput.Peek;
  Line := FInput.Line;
  Column := FInput.Column;
  case Code of
    Ord('{'):
      begin
        FInput.Next;
        Exit(MakeJsonToken(jtkLBrace, '{', Line, Column));
      end;
    Ord('}'):
      begin
        FInput.Next;
        Exit(MakeJsonToken(jtkRBrace, '}', Line, Column));
      end;
    Ord('['):
      begin
        FInput.Next;
        Exit(MakeJsonToken(jtkLBracket, '[', Line, Column));
      end;
    Ord(']'):
      begin
        FInput.Next;
        Exit(MakeJsonToken(jtkRBracket, ']', Line, Column));
      end;
    Ord(':'):
      begin
        FInput.Next;
        Exit(MakeJsonToken(jtkColon, ':', Line, Column));
      end;
    Ord(','):
      begin
        FInput.Next;
        Exit(MakeJsonToken(jtkComma, ',', Line, Column));
      end;
    Ord('"'), Ord(''''):
      Exit(ScanJsonString(FInput, FOptions));
    Ord('+'), Ord('-'), Ord('.'), Ord('0')..Ord('9'):
      Exit(ScanJsonNumber(FInput, FOptions));
  else
    if IsIdentStart(Code) then
      Exit(ScanJsonWord(FInput, FOptions));
    raise EJsonScannerError.Create(
      'The text has a character that is not valid', Line, Column);
  end;
end;

procedure TJsonScanner.Load;
begin
  if FLoaded then
    Exit;
  SkipJsonLayout(FInput, FOptions);
  if not FInput.HasChar then
    FToken := MakeJsonToken(jtkEnd, '', FInput.Line, FInput.Column)
  else
    FToken := ScanOne;
  FLoaded := True;
end;

function TJsonScanner.HasToken: Boolean;
begin
  Load;
  Result := FToken.Kind <> jtkEnd;
end;

function TJsonScanner.NextToken: TJsonToken;
begin
  Load;
  Result := FToken;
  if FToken.Kind <> jtkEnd then
    FLoaded := False;
end;

end.
