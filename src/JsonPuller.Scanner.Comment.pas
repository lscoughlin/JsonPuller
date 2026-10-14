{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Whitespace and comment layout (plan story S05).
@br
The scanner skips spaces, tabs, and line breaks. A comment is layout when
comments are accepted. The flag false rejects a comment at the solidus.
A hash comment is rejected in both flag states.
}
unit JsonPuller.Scanner.Comment;

{$mode delphi}{$H+}

interface

uses
  JsonPuller.Input, JsonPuller.Options;

/// skip whitespace and comments. The procedure stops at the next token
/// character. A comment error names the solidus or the hash.
procedure SkipJsonLayout(AInput: TJsonInput; const AOptions: TJsonOptions);

implementation

uses
  JsonPuller.Errors;

procedure SkipLine(AInput: TJsonInput);
begin
  AInput.Next;
  while AInput.HasChar and (AInput.Peek <> 10) do
    AInput.Next;
end;

procedure SkipBlock(AInput: TJsonInput; ALine, AColumn: Integer);
begin
  AInput.Next;
  while AInput.HasChar do
  begin
    if AInput.Peek = Ord('*') then
    begin
      AInput.Next;
      if AInput.HasChar and (AInput.Peek = Ord('/')) then
      begin
        AInput.Next;
        Exit;
      end;
    end
    else
      AInput.Next;
  end;
  raise EJsonScannerError.Create('The comment has no end', ALine, AColumn);
end;

procedure SkipJsonLayout(AInput: TJsonInput; const AOptions: TJsonOptions);
var
  Code, StartLine, StartCol: LongInt;
begin
  while AInput.HasChar do
  begin
    Code := AInput.Peek;
    if (Code = 32) or (Code = 9) or (Code = 10) or (Code = 13) then
      AInput.Next
    else if Code = Ord('#') then
      raise EJsonScannerError.Create(
        'The character # is not a comment', AInput.Line, AInput.Column)
    else if Code = Ord('/') then
    begin
      StartLine := AInput.Line;
      StartCol := AInput.Column;
      if not AOptions.AllowComments then
        raise EJsonScannerError.Create(
          'The solidus does not start a comment', StartLine, StartCol);
      AInput.Next;
      if not AInput.HasChar then
        raise EJsonScannerError.Create(
          'The solidus does not start a comment', StartLine, StartCol);
      if AInput.Peek = Ord('/') then
        SkipLine(AInput)
      else if AInput.Peek = Ord('*') then
        SkipBlock(AInput, StartLine, StartCol)
      else
        raise EJsonScannerError.Create(
          'The solidus does not start a comment', StartLine, StartCol);
    end
    else
      Break;
  end;
end;

end.
