{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
The fpcunit console runner (plan story S00).
@br
The runner executes every registered test case with a plain-text report.
}
program JsonPuller.RunTests;

{$mode delphi}{$H+}

uses
  SysUtils, Classes, consoletestrunner, JsonPuller.Skeleton.Test,
  JsonPuller.Input.Test, JsonPuller.Scanner.Test, JsonPuller.Parser.Test,
  JsonPuller.Api.Test, JsonPuller.Section.Test, JsonPuller.Errors.Test,
  JsonPuller.Compliance.Test, JsonPuller.Streaming.Test;

var
  App: TTestRunner;

begin
  App := TTestRunner.Create(nil);
  try
    App.Initialize;
    App.Title := 'JsonPuller test suite';
    App.Run;
  finally
    App.Free;
  end;
end.
