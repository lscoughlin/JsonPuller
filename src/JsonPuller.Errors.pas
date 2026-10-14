{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Exception hierarchy for JsonPuller (plan story S11).
@br
Every error names the cause and the position. The message uses ASD-STE100
Simplified Technical English. The position text has the form
"at line L, column C".
}
unit JsonPuller.Errors;

{$mode delphi}{$H+}

interface

uses
  SysUtils;

type
  /// the base class for every JsonPuller error
  EJsonError = class(Exception)
  private
    FLine: Integer;
    FColumn: Integer;
  public
    /// create an error. The message gains the position when the line and
    /// the column are both greater than zero.
    constructor Create(const AMessage: string; ALine, AColumn: Integer); overload;
    constructor Create(const AMessage: string); overload;
    /// the 1-based line, or 0 when the error has no position
    property Line: Integer read FLine;
    /// the 1-based column, or 0 when the error has no position
    property Column: Integer read FColumn;
  end;

  EJsonErrorClass = class of EJsonError;

  /// an error from the input layer or the scanner
  EJsonScannerError = class(EJsonError);

  /// an error from the parser or the JSON bridge
  EJsonParserError = class(EJsonError);

implementation

constructor EJsonError.Create(const AMessage: string; ALine, AColumn: Integer);
begin
  FLine := ALine;
  FColumn := AColumn;
  if (ALine > 0) and (AColumn > 0) then
    inherited Create(Format('%s at line %d, column %d', [AMessage, ALine, AColumn]))
  else
    inherited Create(AMessage);
end;

constructor EJsonError.Create(const AMessage: string);
begin
  Create(AMessage, 0, 0);
end;

end.
