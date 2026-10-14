{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Example: parse a stream (plan story S14).
@br
The program creates a puller from a file stream with the FromStream method.
The caller keeps the stream.
}
program example_stream;

{$mode delphi}{$H+}

uses
  Classes, SysUtils, fpjson, JsonPuller;

var
  Factory: TJsonPullerFactory;
  Source: TFileStream;
  Puller: TJsonPuller;
  Data: TJSONData;

begin
  Factory := TJsonPullerFactory.Create;
  Source := TFileStream.Create('config.json', fmOpenRead);
  try
    Puller := Factory.FromStream(Source);
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
    Source.Free;
    Factory.Free;
  end;
end.
