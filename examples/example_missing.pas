{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Example: missing values (plan story S14).
@br
The program accepts consecutive commas and maps an array hole to null.
}
program example_missing;

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
    Factory.AllowMissingValues(True, True);
    Puller := Factory.FromString('[1,,2]');
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
