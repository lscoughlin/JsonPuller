{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Dialect settings for one puller (plan story S05).
@br
The record holds the README settings. The factory copies the record into
each puller. The initial values accept a strict JSON text and comments.
}
unit JsonPuller.Options;

{$mode delphi}{$H+}

interface

type
  /// the dialect settings. Each field is one factory setting.
  TJsonOptions = record
    AllowUnquotedKeys: Boolean;
    AllowComments: Boolean;
    AllowTrailingCommas: Boolean;
    AllowSingleQuotes: Boolean;
    AllowMissingValues: Boolean;
    /// true when an array hole becomes null. The flag has an effect only
    /// when AllowMissingValues is true.
    MissingAsNull: Boolean;
    AllowLeadingZeros: Boolean;
    AllowLeadingDecimalPoint: Boolean;
  end;

/// the initial settings from the README
function DefaultJsonOptions: TJsonOptions;

implementation

function DefaultJsonOptions: TJsonOptions;
begin
  Result.AllowUnquotedKeys := False;
  Result.AllowComments := True;
  Result.AllowTrailingCommas := False;
  Result.AllowSingleQuotes := False;
  Result.AllowMissingValues := False;
  Result.MissingAsNull := False;
  Result.AllowLeadingZeros := False;
  Result.AllowLeadingDecimalPoint := False;
end;

end.
