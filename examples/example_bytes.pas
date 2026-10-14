{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Example: parse a byte array (plan story S14).
@br
The program creates a puller from a byte array with the FromBytes method. The
byte array holds a UTF-8 document with a byte order mark.
}
program example_bytes;

{$mode delphi}{$H+}

uses
  SysUtils, fpjson, JsonPuller;

var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
  Bytes: TBytes;
  Source: UTF8String;
  I: Integer;

begin
  Source := '{"name":"example","count":3,"enabled":true}';
  SetLength(Bytes, 3 + Length(Source));
  Bytes[0] := $EF;
  Bytes[1] := $BB;
  Bytes[2] := $BF;
  for I := 1 to Length(Source) do
    Bytes[2 + I] := Ord(Source[I]);
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromBytes(Bytes);
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
