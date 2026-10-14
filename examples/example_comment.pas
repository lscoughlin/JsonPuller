{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Example: comments in the initial dialect (plan story S14).
@br
The program parses a text that holds a line comment and a block comment.
Comments are accepted by the initial flags.
}
program example_comment;

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
      '{ /* service */ "port": 8080 }' + LineEnding);
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
