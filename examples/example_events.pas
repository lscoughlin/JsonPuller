{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Example: read the event stream (plan story S14).
@br
The program reads one event at a time and writes the event type, the event
text, the position, and the nest level.
}
program example_events;

{$mode delphi}{$H+}

uses
  JsonPuller, JsonPuller.Events;

var
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Event: TJsonEvent;

begin
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromString('["one","two"]');
    try
      while Puller.HasNext do
      begin
        Event := Puller.Next;
        WriteLn(Ord(Event.EventType), ': ', Event.EventText,
          ' (', Event.Line, ',', Event.Column, ') level=', Event.NestLevel);
      end;
    finally
      Puller.Free;
    end;
  finally
    Factory.Free;
  end;
end.
