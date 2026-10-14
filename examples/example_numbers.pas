{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Example: leading zeros and a leading decimal point (plan story S14).
@br
The program accepts both number spellings. Parse stores the numeric value.
FCL writes a float in the FCL float form.
}
program example_numbers;

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
    Factory.AllowLeadingZeros(True);
    Factory.AllowLeadingDecimalPoint(True);
    Puller := Factory.FromString('[007,03.14,.507]');
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
