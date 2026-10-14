{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Example: parse a UTF-8 string (plan story S14).
@br
The program creates a puller from a string with the FromString method. The
program parses the text and writes the JSON value.
}
program example_string;

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
    Puller := Factory.FromString(
      '{"name":"example","count":3,"enabled":true}');
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
