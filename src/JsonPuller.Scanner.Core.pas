{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Token record for the scanner (plan story S03).
@br
A token has a kind, a text, a line, and a column. The scanner holds one
token. The parser assigns the name role.
}
unit JsonPuller.Scanner.Core;

{$mode delphi}{$H+}

interface

uses
  SysUtils;

type
  /// the kind of one token
  TJsonTokenKind = (
    jtkEnd,
    jtkLBrace,
    jtkRBrace,
    jtkLBracket,
    jtkRBracket,
    jtkColon,
    jtkComma,
    jtkString,
    jtkNumber,
    jtkTrue,
    jtkFalse,
    jtkNull,
    jtkIdentifier);

  /// one token. The text of a string is the decoded text. The text of a
  /// number is the source spelling.
  TJsonToken = record
    Kind: TJsonTokenKind;
    Text: UTF8String;
    Line: Integer;
    Column: Integer;
  end;

/// build a token
function MakeJsonToken(AKind: TJsonTokenKind; const AText: UTF8String;
  ALine, AColumn: Integer): TJsonToken;

implementation

function MakeJsonToken(AKind: TJsonTokenKind; const AText: UTF8String;
  ALine, AColumn: Integer): TJsonToken;
begin
  Result.Kind := AKind;
  Result.Text := AText;
  Result.Line := ALine;
  Result.Column := AColumn;
end;

end.
