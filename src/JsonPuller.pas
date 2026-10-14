{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
The public API (plan story S08).
@br
TJsonPullerFactory holds the dialect settings and returns a puller.
TJsonPuller reads one event at a time or builds an FCL JSON value. The
README holds the public contract. The version constant is the one source
of the library version.
}
unit JsonPuller;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, fpjson, JsonPuller.Events, JsonPuller.Errors,
  JsonPuller.Options, JsonPuller.Input, JsonPuller.Scanner, JsonPuller.Parser;

const
  /// the library version. The package file holds the same version.
  JSON_PULLER_VERSION = '0.1.0';

type
  /// a file handle. The caller keeps ownership of the handle.
  handle = THandle;

  /// the pull parser. Next returns one event. Parse builds one JSON value.
  TJsonPuller = class
  private
    FInput: TJsonInput;
    FScanner: TJsonScanner;
    FParser: TJsonParser;
    FLog: array of TJsonEvent;
    FLogLen: Integer;
    FDone: Boolean;
    FFailed: Boolean;
    FErrorClass: EJsonErrorClass;
    FErrorMessage: string;
    procedure Remember(E: EJsonError);
    procedure Guard;
    function EventAt(AIndex: Integer): TJsonEvent;
    function FindEvent(const AEvent: TJsonEvent): Integer;
  public
    constructor Create(AInput: TJsonInput; const AOptions: TJsonOptions);
    destructor Destroy; override;
    /// the next event
    function Next: TJsonEvent;
    /// true while an event remains
    function HasNext: Boolean;
    /// read the whole event stream into one FCL JSON value. The caller
    /// releases the result.
    function Parse: TJSONData; overload;
    /// read the value that starts at event. The caller releases data.
    /// A stream start and a stream end set data to nil.
    procedure Parse(const event: TJsonEvent; out data: TJSONData); overload;
    /// the number of events that Next has returned
    function EventLogLength: Integer;
  end;

  /// the source factory. The factory holds the dialect settings.
  TJsonPullerFactory = class
  private
    FOptions: TJsonOptions;
  public
    constructor Create;
    procedure AllowUnquotedKeys(value: Boolean = False);
    procedure AllowComments(value: Boolean = True);
    procedure AllowTrailingCommas(value: Boolean = False);
    procedure AllowSingleQuotes(value: Boolean = False);
    procedure AllowMissingValues(value: Boolean; asNull: Boolean = False);
    procedure AllowLeadingZeros(value: Boolean = False);
    procedure AllowLeadingDecimalPoint(value: Boolean = False);
    function FromFile(&file: handle): TJsonPuller;
    function FromStream(astream: TStream): TJsonPuller;
    function FromBytes(const astream: TBytes): TJsonPuller;
    function FromString(const astream: UTF8String): TJsonPuller;
  end;

implementation

uses
  JsonPuller.JSON;

{ TJsonPuller }

constructor TJsonPuller.Create(AInput: TJsonInput; const AOptions: TJsonOptions);
begin
  inherited Create;
  FInput := AInput;
  FScanner := TJsonScanner.Create(AInput, AOptions);
  FParser := TJsonParser.Create(FScanner, AOptions);
  FLogLen := 0;
  FDone := False;
  FFailed := False;
end;

destructor TJsonPuller.Destroy;
begin
  FParser.Free;
  FScanner.Free;
  FInput.Free;
  inherited Destroy;
end;

procedure TJsonPuller.Remember(E: EJsonError);
begin
  FFailed := True;
  FErrorClass := EJsonErrorClass(E.ClassType);
  FErrorMessage := E.Message;
end;

procedure TJsonPuller.Guard;
begin
  if FFailed then
    raise FErrorClass.Create(FErrorMessage);
end;

function TJsonPuller.EventLogLength: Integer;
begin
  Result := FLogLen;
end;

function TJsonPuller.Next: TJsonEvent;
begin
  Guard;
  if FDone then
  begin
    FFailed := True;
    FErrorClass := EJsonParserError;
    FErrorMessage := 'The puller has no further event at line 1, column 1';
    raise EJsonParserError.Create('The puller has no further event', 1, 1);
  end;
  try
    Result := FParser.NextEvent;
  except
    on E: EJsonError do
    begin
      Remember(E);
      raise;
    end;
  end;
  if FLogLen >= Length(FLog) then
    SetLength(FLog, FLogLen + 32);
  FLog[FLogLen] := Result;
  Inc(FLogLen);
  if Result.EventType = jetStreamEnd then
    FDone := True;
end;

function TJsonPuller.HasNext: Boolean;
begin
  Guard;
  Result := not FDone;
end;

function TJsonPuller.EventAt(AIndex: Integer): TJsonEvent;
begin
  while AIndex >= FLogLen do
  begin
    if FDone then
      raise EJsonParserError.Create(
        'The text ended before the value ended', 1, 1);
    Next;
  end;
  Result := FLog[AIndex];
end;

function TJsonPuller.FindEvent(const AEvent: TJsonEvent): Integer;
var
  I: Integer;
begin
  for I := 0 to FLogLen - 1 do
    if (FLog[I].EventType = AEvent.EventType) and
      (FLog[I].EventText = AEvent.EventText) and
      (FLog[I].NestLevel = AEvent.NestLevel) and
      (FLog[I].Line = AEvent.Line) and
      (FLog[I].Column = AEvent.Column) then
      Exit(I);
  Result := -1;
end;

function TJsonPuller.Parse: TJSONData;
var
  Index: Integer;
  Event: TJsonEvent;
begin
  Result := nil;
  Guard;
  try
    Event := EventAt(0);
    if Event.EventType <> jetStreamStart then
      raise EJsonParserError.Create(
        'The puller already read the stream', Event.Line, Event.Column);
    Index := 1;
    Result := BuildJsonValue(EventAt, Index);
    Event := EventAt(Index);
    if Event.EventType <> jetStreamEnd then
      raise EJsonParserError.Create(
        'The text has a second value', Event.Line, Event.Column);
  except
    on E: EJsonError do
    begin
      Result.Free;
      Result := nil;
      Remember(E);
      raise;
    end;
  end;
end;

procedure TJsonPuller.Parse(const event: TJsonEvent; out data: TJSONData);
var
  Index: Integer;
begin
  data := nil;
  Guard;
  try
    Index := FindEvent(event);
    while (Index < 0) and (not FDone) do
    begin
      Next;
      Index := FindEvent(event);
    end;
    if Index < 0 then
      raise EJsonParserError.Create(
        'The event is not part of this puller', event.Line, event.Column);
    case event.EventType of
      jetStreamStart, jetStreamEnd, jetObjectEnd, jetArrayEnd:
        data := nil;
    else
      data := BuildJsonValue(EventAt, Index);
    end;
  except
    on E: EJsonError do
    begin
      data.Free;
      data := nil;
      Remember(E);
      raise;
    end;
  end;
end;

{ TJsonPullerFactory }

constructor TJsonPullerFactory.Create;
begin
  inherited Create;
  FOptions := DefaultJsonOptions;
end;

procedure TJsonPullerFactory.AllowUnquotedKeys(value: Boolean);
begin
  FOptions.AllowUnquotedKeys := value;
end;

procedure TJsonPullerFactory.AllowComments(value: Boolean);
begin
  FOptions.AllowComments := value;
end;

procedure TJsonPullerFactory.AllowTrailingCommas(value: Boolean);
begin
  FOptions.AllowTrailingCommas := value;
end;

procedure TJsonPullerFactory.AllowSingleQuotes(value: Boolean);
begin
  FOptions.AllowSingleQuotes := value;
end;

procedure TJsonPullerFactory.AllowMissingValues(value: Boolean; asNull: Boolean);
begin
  FOptions.AllowMissingValues := value;
  FOptions.MissingAsNull := asNull;
end;

procedure TJsonPullerFactory.AllowLeadingZeros(value: Boolean);
begin
  FOptions.AllowLeadingZeros := value;
end;

procedure TJsonPullerFactory.AllowLeadingDecimalPoint(value: Boolean);
begin
  FOptions.AllowLeadingDecimalPoint := value;
end;

function TJsonPullerFactory.FromFile(&file: handle): TJsonPuller;
begin
  Result := TJsonPuller.Create(TJsonInput.FromFile(&file), FOptions);
end;

function TJsonPullerFactory.FromStream(astream: TStream): TJsonPuller;
begin
  Result := TJsonPuller.Create(TJsonInput.FromStream(astream), FOptions);
end;

function TJsonPullerFactory.FromBytes(const astream: TBytes): TJsonPuller;
begin
  Result := TJsonPuller.Create(TJsonInput.FromBytes(astream), FOptions);
end;

function TJsonPullerFactory.FromString(const astream: UTF8String): TJsonPuller;
begin
  Result := TJsonPuller.Create(TJsonInput.FromString(astream), FOptions);
end;

end.
