{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Example: single quotes and double quotes (plan story S14).
@br
The program sets AllowSingleQuotes. The text mixes both quote styles. The
opening quote of each string selects the closer.
}
program example_quotes;

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
    Factory.AllowSingleQuotes(True);
    Puller := Factory.FromString(
      '{''a'': "b", "c": ''say "hi"'', "d": "it''s"}');
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
