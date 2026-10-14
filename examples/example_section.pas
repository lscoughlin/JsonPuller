{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Example: parse a subsection (plan story S14).
@br
The program reads events until the array that is the value of the member
ports. The program parses that array alone.
}
program example_section;

{$mode delphi}{$H+}

uses
  fpjson, JsonPuller, JsonPuller.Events;

var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Event: TJsonEvent;
  Data: TJSONData;
  Found: TJsonEvent;

begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString(
      '{"ports":[80,443],"note":"later"}');
    try
      Found := Default(TJsonEvent);
      while Puller.HasNext do
      begin
        Event := Puller.Next;
        if Event.EventType = jetArrayStart then
        begin
          Found := Event;
          Break;
        end;
      end;
      if Found.EventType = jetArrayStart then
      begin
        Puller.Parse(Found, Data);
        try
          WriteLn(Data.AsJSON);
        finally
          Data.Free;
        end;
      end;
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end.
