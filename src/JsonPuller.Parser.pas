{**
license: Apache-2.0
copyright: Copyright 2026 Liam Seamus Coughlin
---
Parser state machine: tokens to events (plan story S07).
@br
The parser emits one event on request. A start event and its end event
share a nest level. One text holds one value. MaxDepth is 1000.
}
unit JsonPuller.Parser;

{$mode delphi}{$H+}

interface

uses
  JsonPuller.Events, JsonPuller.Options, JsonPuller.Scanner,
  JsonPuller.Scanner.Core;

const
  /// the maximum nest level. A deeper collection raises an error.
  MaxDepth = 1000;

type
  /// the event parser. NextEvent returns one event.
  TJsonParser = class
  private
    FScanner: TJsonScanner;
    FOptions: TJsonOptions;
    FState: Integer;
    FReturn: Integer;
    FLevel: Integer;
    FStack: array of Integer;
    FStackTop: Integer;
    FAfterHole: Boolean;
    FCommaLine: Integer;
    FCommaColumn: Integer;
    FToken: TJsonToken;
    FHas: Boolean;
    FFailed: Boolean;
    FFailMessage: string;
    procedure Fail(const ACause: string; ALine, AColumn: Integer);
    procedure Pull;
    procedure Consume;
    procedure PushReturn(AState: Integer);
    function PopReturn: Integer;
    function OpenObject: TJsonEvent;
    function OpenArray: TJsonEvent;
    function CloseObject: TJsonEvent;
    function CloseArray: TJsonEvent;
    function EmitScalar(AType: TJsonEventType): TJsonEvent;
    function TakeName: TJsonEvent;
    function EmitNullHole: TJsonEvent;
  public
    constructor Create(AScanner: TJsonScanner; const AOptions: TJsonOptions);
    /// the next event
    function NextEvent: TJsonEvent;
  end;

implementation

uses
  SysUtils, JsonPuller.Errors;

const
  psStart = 0;
  psStream = 1;
  psValue = 2;
  psObjFirst = 3;
  psObjColon = 4;
  psObjValue = 5;
  psObjNext = 6;
  psObjComma = 7;
  psArrFirst = 8;
  psArrNext = 9;
  psArrComma = 10;
  psAfterStream = 11;
  psDone = 12;

constructor TJsonParser.Create(AScanner: TJsonScanner; const AOptions: TJsonOptions);
begin
  inherited Create;
  FScanner := AScanner;
  FOptions := AOptions;
  FState := psStart;
  FLevel := 0;
  FStackTop := 0;
  FFailed := False;
end;

procedure TJsonParser.Fail(const ACause: string; ALine, AColumn: Integer);
begin
  FFailed := True;
  FFailMessage := Format('%s at line %d, column %d', [ACause, ALine, AColumn]);
  raise EJsonParserError.Create(ACause, ALine, AColumn);
end;

procedure TJsonParser.Pull;
begin
  if FHas then
    Exit;
  FToken := FScanner.NextToken;
  FHas := True;
end;

procedure TJsonParser.Consume;
begin
  FHas := False;
end;

procedure TJsonParser.PushReturn(AState: Integer);
begin
  if FStackTop >= Length(FStack) then
    SetLength(FStack, FStackTop + 16);
  FStack[FStackTop] := AState;
  Inc(FStackTop);
end;

function TJsonParser.PopReturn: Integer;
begin
  Dec(FStackTop);
  Result := FStack[FStackTop];
end;

function TJsonParser.OpenObject: TJsonEvent;
begin
  if FLevel >= MaxDepth then
    Fail('The nest level is above 1000', FToken.Line, FToken.Column);
  Result := MakeJsonEvent(jetObjectStart, '', FLevel, FToken.Line, FToken.Column);
  Consume;
  PushReturn(FReturn);
  Inc(FLevel);
  FState := psObjFirst;
  FAfterHole := False;
end;

function TJsonParser.OpenArray: TJsonEvent;
begin
  if FLevel >= MaxDepth then
    Fail('The nest level is above 1000', FToken.Line, FToken.Column);
  Result := MakeJsonEvent(jetArrayStart, '', FLevel, FToken.Line, FToken.Column);
  Consume;
  PushReturn(FReturn);
  Inc(FLevel);
  FState := psArrFirst;
  FAfterHole := False;
end;

function TJsonParser.CloseObject: TJsonEvent;
begin
  Dec(FLevel);
  Result := MakeJsonEvent(jetObjectEnd, '', FLevel, FToken.Line, FToken.Column);
  Consume;
  FState := PopReturn;
  FAfterHole := False;
end;

function TJsonParser.CloseArray: TJsonEvent;
begin
  Dec(FLevel);
  Result := MakeJsonEvent(jetArrayEnd, '', FLevel, FToken.Line, FToken.Column);
  Consume;
  FState := PopReturn;
  FAfterHole := False;
end;

function TJsonParser.EmitScalar(AType: TJsonEventType): TJsonEvent;
begin
  Result := MakeJsonEvent(AType, FToken.Text, FLevel, FToken.Line, FToken.Column);
  Consume;
  FState := FReturn;
  FAfterHole := False;
end;

function TJsonParser.TakeName: TJsonEvent;
var
  Allowed: Boolean;
begin
  Allowed := FOptions.AllowUnquotedKeys;
  case FToken.Kind of
    jtkString:
      Result := MakeJsonEvent(jetName, FToken.Text, FLevel, FToken.Line, FToken.Column);
    jtkIdentifier:
      if Allowed then
        Result := MakeJsonEvent(jetName, FToken.Text, FLevel, FToken.Line, FToken.Column)
      else
        Fail('The identifier is not accepted', FToken.Line, FToken.Column);
    jtkNumber, jtkTrue, jtkFalse, jtkNull:
      if Allowed then
        Result := MakeJsonEvent(jetName, FToken.Text, FLevel, FToken.Line, FToken.Column)
      else
        Fail('The member name needs quotes', FToken.Line, FToken.Column);
  else
    Fail('The parser expects a member name', FToken.Line, FToken.Column);
  end;
  Consume;
  FState := psObjColon;
end;

function TJsonParser.EmitNullHole: TJsonEvent;
var
  Line, Column: Integer;
begin
  Line := FToken.Line;
  Column := FToken.Column;
  Consume;
  FAfterHole := True;
  Result := MakeJsonEvent(jetNull, 'null', FLevel, Line, Column);
end;

function TJsonParser.NextEvent: TJsonEvent;
begin
  if FFailed then
    raise EJsonParserError.Create(FFailMessage);
  while True do
  begin
    Pull;
    case FState of
      psStart:
        begin
          if FToken.Kind = jtkEnd then
            Fail('The text has no value', FToken.Line, FToken.Column);
          FState := psStream;
          Exit(MakeJsonEvent(jetStreamStart, '', 0, 1, 1));
        end;
      psStream:
        begin
          if FToken.Kind = jtkEnd then
            Fail('The text has no value', FToken.Line, FToken.Column);
          FReturn := psAfterStream;
          FState := psValue;
        end;
      psValue:
        case FToken.Kind of
          jtkLBrace: Exit(OpenObject);
          jtkLBracket: Exit(OpenArray);
          jtkString: Exit(EmitScalar(jetString));
          jtkNumber: Exit(EmitScalar(jetNumber));
          jtkTrue: Exit(EmitScalar(jetTrue));
          jtkFalse: Exit(EmitScalar(jetFalse));
          jtkNull: Exit(EmitScalar(jetNull));
          jtkIdentifier:
            Fail('The identifier is not a value', FToken.Line, FToken.Column);
          jtkEnd:
            Fail('The text has no value', FToken.Line, FToken.Column);
        else
          Fail('The parser expects a value', FToken.Line, FToken.Column);
        end;
      psObjFirst:
        if FToken.Kind = jtkRBrace then
          Exit(CloseObject)
        else if FToken.Kind = jtkComma then
          Fail('The object has a comma before the first member',
            FToken.Line, FToken.Column)
        else
          Exit(TakeName);
      psObjColon:
        if FToken.Kind <> jtkColon then
          Fail('The parser expects a colon', FToken.Line, FToken.Column)
        else
        begin
          Consume;
          FState := psObjValue;
        end;
      psObjValue:
        begin
          FReturn := psObjNext;
          FState := psValue;
        end;
      psObjNext:
        if FToken.Kind = jtkComma then
        begin
          FCommaLine := FToken.Line;
          FCommaColumn := FToken.Column;
          Consume;
          FAfterHole := False;
          FState := psObjComma;
        end
        else if FToken.Kind = jtkRBrace then
          Exit(CloseObject)
        else
          Fail('The parser expects a comma or an end', FToken.Line, FToken.Column);
      psObjComma:
        if FToken.Kind = jtkComma then
        begin
          if not FOptions.AllowMissingValues then
            Fail('The object has a missing value', FToken.Line, FToken.Column);
          Consume;
          FAfterHole := True;
        end
        else if FToken.Kind = jtkRBrace then
        begin
          if FAfterHole or FOptions.AllowTrailingCommas then
            Exit(CloseObject)
          else
            Fail('The object has a trailing comma', FCommaLine, FCommaColumn);
        end
        else
        begin
          FAfterHole := False;
          Exit(TakeName);
        end;
      psArrFirst:
        if FToken.Kind = jtkRBracket then
          Exit(CloseArray)
        else if FToken.Kind = jtkComma then
          Fail('The array has a comma before the first element',
            FToken.Line, FToken.Column)
        else
        begin
          FReturn := psArrNext;
          FState := psValue;
        end;
      psArrNext:
        if FToken.Kind = jtkComma then
        begin
          FCommaLine := FToken.Line;
          FCommaColumn := FToken.Column;
          Consume;
          FAfterHole := False;
          FState := psArrComma;
        end
        else if FToken.Kind = jtkRBracket then
          Exit(CloseArray)
        else
          Fail('The parser expects a comma or an end', FToken.Line, FToken.Column);
      psArrComma:
        if FToken.Kind = jtkComma then
        begin
          if not FOptions.AllowMissingValues then
            Fail('The array has a missing value', FToken.Line, FToken.Column);
          if FOptions.MissingAsNull then
            Exit(EmitNullHole)
          else
          begin
            Consume;
            FAfterHole := True;
          end;
        end
        else if FToken.Kind = jtkRBracket then
        begin
          if FAfterHole or FOptions.AllowTrailingCommas then
            Exit(CloseArray)
          else
            Fail('The array has a trailing comma', FCommaLine, FCommaColumn);
        end
        else
        begin
          FAfterHole := False;
          FReturn := psArrNext;
          FState := psValue;
        end;
      psAfterStream:
        if FToken.Kind = jtkEnd then
        begin
          FState := psDone;
          Exit(MakeJsonEvent(jetStreamEnd, '', 0, FToken.Line, FToken.Column));
        end
        else
          Fail('The text has a second value', FToken.Line, FToken.Column);
    else
      Fail('The puller has no further event', FToken.Line, FToken.Column);
    end;
  end;
end;

end.
