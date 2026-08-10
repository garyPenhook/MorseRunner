unit ContestSession;

{$mode delphi}{$H+}

interface

uses
  ContestSettings,
  QsoLog;

type
  TSessionState = (ssStopped, ssRunning, ssFinished);
  TSessionEndReason = (serNone, serTimeElapsed, serStoppedByUser);

  TContestSession = class
  private
    FSettings: TContestSettings;
    FState: TSessionState;
    FEndReason: TSessionEndReason;
    FConsumedFrames: Int64;
    FLog: TQsoLog;
    procedure Finish(const Reason: TSessionEndReason);
    function GetElapsedSeconds: Double;
    function GetScore: TContestScore;
  public
    constructor Create(const InitialSettings: TContestSettings);
    destructor Destroy; override;
    procedure Configure(const NewSettings: TContestSettings);
    procedure Start(const Mode: TRunMode);
    procedure ConsumeFrames(const FrameCount: Int64);
    procedure RequestStop;
    function SubmitQso(Qso: TQso): Boolean;

    property Settings: TContestSettings read FSettings;
    property State: TSessionState read FState;
    property EndReason: TSessionEndReason read FEndReason;
    property ConsumedFrames: Int64 read FConsumedFrames;
    property ElapsedSeconds: Double read GetElapsedSeconds;
    property Log: TQsoLog read FLog;
    property Score: TContestScore read GetScore;
  end;

implementation

uses
  ContestTiming,
  SysUtils;

constructor TContestSession.Create(const InitialSettings: TContestSettings);
begin
  inherited Create;
  FLog := TQsoLog.Create;
  Configure(InitialSettings);
end;

destructor TContestSession.Destroy;
begin
  FLog.Free;
  inherited Destroy;
end;

procedure TContestSession.Configure(const NewSettings: TContestSettings);
begin
  if FState = ssRunning then
    raise Exception.Create('Cannot change contest settings while a session is running.');

  FSettings := NewSettings;
  NormalizeContestSettings(FSettings);
  FSettings.RunMode := rmStop;
  FState := ssStopped;
  FEndReason := serNone;
  FConsumedFrames := 0;
  FLog.Clear;
end;

procedure TContestSession.Start(const Mode: TRunMode);
begin
  if Mode = rmStop then
  begin
    RequestStop;
    Exit;
  end;

  FSettings.RunMode := Mode;
  NormalizeContestSettings(FSettings);
  FConsumedFrames := 0;
  FLog.Clear;
  FEndReason := serNone;
  FState := ssRunning;
end;

procedure TContestSession.Finish(const Reason: TSessionEndReason);
begin
  FState := ssFinished;
  FEndReason := Reason;
end;

procedure TContestSession.ConsumeFrames(const FrameCount: Int64);
begin
  if (FState <> ssRunning) or (FrameCount <= 0) then
    Exit;

  Inc(FConsumedFrames, FrameCount);
  if IsSessionFinished(FSettings, FConsumedFrames) then
    Finish(serTimeElapsed);
end;

procedure TContestSession.RequestStop;
begin
  if FState = ssRunning then
    Finish(serStoppedByUser);
end;

function TContestSession.SubmitQso(Qso: TQso): Boolean;
begin
  Result := FState = ssRunning;
  if not Result then
    Exit;

  Qso.Call := UpperCase(Trim(Qso.Call));
  Qso.TrueCall := UpperCase(Trim(Qso.TrueCall));
  Qso.Dupe := FLog.IsDuplicateCall(Qso.Call);
  if FSettings.RunMode = rmHst then
    Qso.Pfx := IntToStr(CallToHstScore(Qso.Call))
  else
    Qso.Pfx := ExtractPrefix(Qso.Call);
  Qso.Err := DetermineQsoError(Qso);
  FLog.Add(Qso);
end;

function TContestSession.GetElapsedSeconds: Double;
begin
  Result := FramesToSeconds(FSettings, FConsumedFrames);
end;

function TContestSession.GetScore: TContestScore;
begin
  if FSettings.RunMode = rmHst then
    Result := HstScore(FLog)
  else
    Result := ContestScore(FLog);
end;

end.
