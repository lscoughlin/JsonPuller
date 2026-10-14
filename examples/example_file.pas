{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Example: parse a file (plan story S14).
@br
The program creates a puller from an open file handle with the FromFile
method. The program takes the file name from the command line, or uses a
temporary file.
}
program example_file;

{$mode delphi}{$H+}

uses
  SysUtils, fpjson, JsonPuller;

var
  FileName: string;
  Handle: THandle;
  Factory: TJsonPullerFactory;
  Puller: TJsonPuller;
  Data: TJSONData;
  OutFile: System.Text;

begin
  if ParamCount >= 1 then
    FileName := ParamStr(1)
  else
    FileName := GetTempDir(False) + 'jsonpuller-example.json';
  if ParamCount < 1 then
  begin
    Assign(OutFile, FileName);
    Rewrite(OutFile);
    WriteLn(OutFile, '{"name":"example","count":3,"enabled":true}');
    Close(OutFile);
  end;
  Handle := FileOpen(FileName, fmOpenRead);
  if Handle = THandle(-1) then
  begin
    WriteLn('cannot open ', FileName);
    Halt(1);
  end;
  Factory := TJsonPullerFactory.Create;
  try
    Puller := Factory.FromFile(Handle);
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
    FileClose(Handle);
    Factory.Free;
    if ParamCount < 1 then
      DeleteFile(FileName);
  end;
end.
