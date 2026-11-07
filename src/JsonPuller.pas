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
  JSON_PULLER_VERSION = '0.3.0';

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
    FCount: Integer;
    FKeepLog: Boolean;
    FMultiple: Boolean;
    FDuplicateNames: Boolean;
    FWindowActive: Boolean;
    FLast: TJsonEvent;
    FDone: Boolean;
    FFailed: Boolean;
    FErrorClass: EJsonErrorClass;
    FErrorMessage: string;
    procedure Remember(E: EJsonError);
    procedure Guard;
    function EventAt(AIndex: Integer): TJsonEvent;
    function FindEvent(const AEvent: TJsonEvent): Integer;
    procedure ResetWindow;
    procedure ParseWindow(const AEvent: TJsonEvent; out AData: TJSONData);
  public
    constructor Create(AInput: TJsonInput; const AOptions: TJsonOptions);
    destructor Destroy; override;
    /// the next event
    function Next: TJsonEvent;
    /// true while an event remains
    function HasNext: Boolean;
    /// read the whole event stream into one FCL JSON value. The caller
    /// releases the result. When the factory allowed several values, the
    /// result is a TJSONArray that holds each value.
    function Parse: TJSONData; overload;
    /// read the value that starts at event. The caller releases data.
    /// A stream start and a stream end set data to nil. After the call,
    /// the next Next returns the event that follows the value.
    /// When the factory turned the event log off, event must be the event
    /// that Next returned last.
    procedure Parse(const event: TJsonEvent; out data: TJSONData); overload;
    /// the number of events in the event log
    function EventLogLength: Integer;
    /// true while the puller keeps a log of the events. The factory sets the
    /// initial value. The caller can change it before the first call of Next.
    property KeepEventLog: Boolean read FKeepLog write FKeepLog;
    /// alias for KeepEventLog
    property KeepLog: Boolean read FKeepLog write FKeepLog;
    /// true when the text can hold several top-level values
    property AllowMultipleValues: Boolean read FMultiple;
    /// true when an object can have duplicate member names
    property AllowDuplicateNames: Boolean read FDuplicateNames;
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
    /// with true, an object can have duplicate member names.
    procedure AllowDuplicateNames(value: Boolean = True);
    /// with false, the puller keeps no log of the events. Memory then follows
    /// the nesting depth and the size of the largest value that Parse builds.
    procedure KeepEventLog(value: Boolean = True);
    /// alias for KeepEventLog
    procedure KeepLog(value: Boolean = True);
    /// with true, the text can hold several top-level values separated by white
    /// space, as JSON Lines does. The events of the values follow each other
    /// between one stream start and one stream end.
    procedure AllowMultipleValues(value: Boolean = False);
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
  FCount := 0;
  FKeepLog := AOptions.KeepEventLog;
  FMultiple := AOptions.AllowMultipleValues;
  FDuplicateNames := AOptions.AllowDuplicateNames;
  FWindowActive := False;
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

procedure TJsonPuller.ResetWindow;
begin
  FWindowActive := False;
  FLogLen := 0;
  SetLength(FLog, 0);
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
  if FKeepLog or FWindowActive then
  begin
    if FLogLen >= Length(FLog) then
      SetLength(FLog, FLogLen + 32);
    FLog[FLogLen] := Result;
    Inc(FLogLen);
  end;
  Inc(FCount);
  FLast := Result;
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
  if not FKeepLog then
  begin
    if FCount > 0 then
      raise EJsonParserError.Create(
        'The puller already read the stream', 1, 1);
    FWindowActive := True;
  end;
  try
    Event := EventAt(0);
    if Event.EventType <> jetStreamStart then
      raise EJsonParserError.Create(
        'The puller already read the stream', Event.Line, Event.Column);
    Index := 1;
    if FMultiple then
    begin
      // several values: the result is an array of the values
      Result := TJSONArray.Create;
      while EventAt(Index).EventType <> jetStreamEnd do
        TJSONArray(Result).Add(BuildJsonValue(EventAt, Index, FDuplicateNames));
    end
    else
    begin
      Result := BuildJsonValue(EventAt, Index, FDuplicateNames);
      Event := EventAt(Index);
      if Event.EventType <> jetStreamEnd then
        raise EJsonParserError.Create(
          'The text has a second value', Event.Line, Event.Column);
    end;
    if not FKeepLog then
      ResetWindow;
  except
    on E: EJsonError do
    begin
      Result.Free;
      Result := nil;
      if not FKeepLog then
        ResetWindow;
      Remember(E);
      raise;
    end;
  end;
end;

procedure TJsonPuller.ParseWindow(const AEvent: TJsonEvent;
  out AData: TJSONData);
var
  Index: Integer;
begin
  AData := nil;
  case AEvent.EventType of
    jetStreamStart, jetStreamEnd, jetObjectEnd, jetArrayEnd:
      Exit;
  end;
  if (FCount = 0) or (FLast.EventType <> AEvent.EventType) or
    (FLast.EventText <> AEvent.EventText) or
    (FLast.NestLevel <> AEvent.NestLevel) or
    (FLast.Line <> AEvent.Line) or (FLast.Column <> AEvent.Column) then
    raise EJsonParserError.Create(
      'The event log is off. The event is not the last event of the puller',
      AEvent.Line, AEvent.Column);
  // the log holds only the events of this value, from the event on
  FLogLen := 0;
  SetLength(FLog, 1);
  FLog[0] := AEvent;
  FLogLen := 1;
  FWindowActive := True;
  try
    Index := 0;
    AData := BuildJsonValue(EventAt, Index, FDuplicateNames);
  finally
    ResetWindow;
  end;
end;

procedure TJsonPuller.Parse(const event: TJsonEvent; out data: TJSONData);
var
  Index: Integer;
begin
  data := nil;
  Guard;
  if not FKeepLog then
  begin
    try
      ParseWindow(event, data);
    except
      on E: EJsonError do
      begin
        data.Free;
        data := nil;
        Remember(E);
        raise;
      end;
    end;
    Exit;
  end;
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
      data := BuildJsonValue(EventAt, Index, FDuplicateNames);
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

procedure TJsonPullerFactory.AllowDuplicateNames(value: Boolean);
begin
  FOptions.AllowDuplicateNames := value;
end;

procedure TJsonPullerFactory.AllowMultipleValues(value: Boolean);
begin
  FOptions.AllowMultipleValues := value;
end;

procedure TJsonPullerFactory.KeepEventLog(value: Boolean);
begin
  FOptions.KeepEventLog := value;
end;

procedure TJsonPullerFactory.KeepLog(value: Boolean);
begin
  FOptions.KeepEventLog := value;
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
