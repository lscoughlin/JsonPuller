{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Example: unquoted keys and trailing commas (plan story S14).
@br
The program sets the two flags that start false. The text uses an identifier
name, a numeric name, and a trailing comma.
}
program example_dialect;

{$mode delphi}{$H+}

uses
  fpjson, JsonPuller;

var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;

begin
  Factory := TJsonPullerFactory.Create;
  try
    Factory.AllowUnquotedKeys(True);
    Factory.AllowTrailingCommas(True);
    Puller := Factory.FromString('{host: "localhost", 1: "one",}');
    try
      Data := Puller.Parse;
      try
        WriteLn(Data.AsJSON);
      finally
        Data.Free;
      end;
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end.
