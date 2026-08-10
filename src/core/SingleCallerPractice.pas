unit SingleCallerPractice;

{$mode delphi}{$H+}

interface

uses
  QsoLog;

type
  { The deliberately small, deterministic exchange used by the Linux port
    while the original multi-station simulator is being brought across. }
  TSingleCallerState = (scsIdle, scsAwaitingExchange, scsAwaitingSignoff,
    scsComplete);

  TSingleCallerPractice = class
  private
    FCallerCall: string;
    FSerialNumber: Integer;
    FState: TSingleCallerState;
    function IsSignoff(const MessageText: string): Boolean;
    function NewQso: TQso;
  public
    constructor Create(const ACallerCall: string; const ASerialNumber: Integer);
    function Start: string;
    function ReceiveOperatorText(const MessageText: string; out ReplyText: string;
      out CompletedQso: TQso): Boolean;

    property CallerCall: string read FCallerCall;
    property SerialNumber: Integer read FSerialNumber;
    property State: TSingleCallerState read FState;
  end;

function SingleCallerStateText(const State: TSingleCallerState): string;

implementation

uses
  SysUtils;

constructor TSingleCallerPractice.Create(const ACallerCall: string;
  const ASerialNumber: Integer);
begin
  inherited Create;
  FCallerCall := UpperCase(Trim(ACallerCall));
  if FCallerCall = '' then
    raise EArgumentException.Create('A practice caller is required.');
  if ASerialNumber < 1 then
    raise EArgumentOutOfRangeException.Create('The exchange number must be positive.');
  FSerialNumber := ASerialNumber;
  FState := scsIdle;
end;

function TSingleCallerPractice.Start: string;
begin
  if FState <> scsIdle then
    raise EInvalidOp.Create('The practice caller has already started.');
  FState := scsAwaitingExchange;
  Result := 'DE ' + FCallerCall + ' ' + FCallerCall;
end;

function TSingleCallerPractice.IsSignoff(const MessageText: string): Boolean;
var
  Normalized: string;
begin
  Normalized := ' ' + UpperCase(Trim(MessageText)) + ' ';
  Result := (Pos(' TU ', Normalized) > 0) or (Pos(' TNX ', Normalized) > 0);
end;

function TSingleCallerPractice.NewQso: TQso;
begin
  Result.T := 0;
  Result.Call := '';
  Result.TrueCall := '';
  Result.Rst := 0;
  Result.TrueRst := 0;
  Result.Nr := 0;
  Result.TrueNr := 0;
  Result.Pfx := '';
  Result.Dupe := False;
  Result.Err := '';
  Result.Call := FCallerCall;
  Result.TrueCall := FCallerCall;
  Result.Rst := 599;
  Result.TrueRst := 599;
  Result.Nr := FSerialNumber;
  Result.TrueNr := FSerialNumber;
end;

function TSingleCallerPractice.ReceiveOperatorText(const MessageText: string;
  out ReplyText: string; out CompletedQso: TQso): Boolean;
var
  Normalized: string;
begin
  ReplyText := '';
  CompletedQso.T := 0;
  CompletedQso.Call := '';
  CompletedQso.TrueCall := '';
  CompletedQso.Rst := 0;
  CompletedQso.TrueRst := 0;
  CompletedQso.Nr := 0;
  CompletedQso.TrueNr := 0;
  CompletedQso.Pfx := '';
  CompletedQso.Dupe := False;
  CompletedQso.Err := '';
  Result := False;
  Normalized := UpperCase(Trim(MessageText));

  case FState of
    scsAwaitingExchange:
      begin
        Result := True;
        if Pos(FCallerCall, Normalized) > 0 then
        begin
          ReplyText := Format('R 599%3.3d', [FSerialNumber]);
          FState := scsAwaitingSignoff;
        end
        else
          ReplyText := 'AGN';
      end;
    scsAwaitingSignoff:
      begin
        Result := True;
        if IsSignoff(Normalized) then
        begin
          ReplyText := 'TU ' + FCallerCall;
          CompletedQso := NewQso;
          FState := scsComplete;
        end
        else
          ReplyText := 'AGN';
      end;
  end;
end;

function SingleCallerStateText(const State: TSingleCallerState): string;
begin
  case State of
    scsIdle: Result := 'idle';
    scsAwaitingExchange: Result := 'send the caller and exchange';
    scsAwaitingSignoff: Result := 'send TU to complete the QSO';
    scsComplete: Result := 'QSO complete';
  end;
end;

end.
