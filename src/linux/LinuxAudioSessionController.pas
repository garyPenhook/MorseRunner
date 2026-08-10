unit LinuxAudioSessionController;

{$mode delphi}{$H+}

interface

uses
  ContestSession,
  ContestSettings,
  MorseAudioProducer,
  PcmRing,
  PortAudioOutput;

type
  TLinuxAudioSessionController = class
  private
    FSettings: TContestSettings;
    FSession: TContestSession;
    FRing: TPcmSpscRing;
    FProducer: TMorseAudioProducer;
    FOutput: TPortAudioOutput;
    FStatus: string;
    function GetSession: TContestSession;
    procedure ProduceUntilRingFull;
    procedure CloseOutput(const AbortStream: Boolean);
  public
    constructor Create(const Settings: TContestSettings);
    destructor Destroy; override;
    procedure Start(const Mode: TRunMode);
    procedure Stop;
    procedure Tick;

    property Session: TContestSession read GetSession;
    property Status: string read FStatus;
  end;

implementation

uses
  SysUtils;

constructor TLinuxAudioSessionController.Create(const Settings: TContestSettings);
begin
  inherited Create;
  FSettings := Settings;
  NormalizeContestSettings(FSettings);
  FSession := TContestSession.Create(FSettings);
  FRing := TPcmSpscRing.Create(FSettings.Audio.FramesPerBlock,
    FSettings.Audio.RingBlockCount);
  FProducer := TMorseAudioProducer.Create(FRing, FSettings.Wpm,
    FSettings.Audio.SampleRate, FSettings.PitchHz, 6000);
  FOutput := TPortAudioOutput.Create(FRing);
  FStatus := 'Audio idle: choose a mode and start the native preview.';
end;

destructor TLinuxAudioSessionController.Destroy;
begin
  try
    CloseOutput(True);
  except
    { Destructors cannot report a device-cleanup error. }
  end;
  FOutput.Free;
  FProducer.Free;
  FRing.Free;
  FSession.Free;
  inherited Destroy;
end;

function TLinuxAudioSessionController.GetSession: TContestSession;
begin
  Result := FSession;
end;

procedure TLinuxAudioSessionController.ProduceUntilRingFull;
begin
  while FRing.AvailableToWrite > 0 do
  begin
    if not FProducer.HasPendingBlocks then
      FProducer.PrepareMessage('CQ');
    if not FProducer.TryProduceNextBlock then
      Exit;
  end;
end;

procedure TLinuxAudioSessionController.CloseOutput(const AbortStream: Boolean);
begin
  if FOutput.State = paosStarted then
  begin
    if AbortStream then
      FOutput.Abort
    else
      FOutput.Stop;
  end;
  if FOutput.State <> paosClosed then
    FOutput.Close;
end;

procedure TLinuxAudioSessionController.Start(const Mode: TRunMode);
begin
  if FSession.State = ssRunning then
    raise EInvalidOp.Create('The audio session is already running.');

  FRing.Reset;
  FProducer.Reset;
  FSession.Start(Mode);
  try
    FOutput.Open(FSettings.Audio.SampleRate);
    ProduceUntilRingFull;
    FOutput.Start;
    FStatus := Format(
      'Native PortAudio preview active: %d Hz, %d-frame blocks, CQ loop.',
      [FSettings.Audio.SampleRate, FSettings.Audio.FramesPerBlock]);
  except
    on Error: Exception do
    begin
      try
        CloseOutput(True);
      except
      end;
      FSession.RequestStop;
      FRing.Reset;
      FProducer.Reset;
      FStatus := 'Audio start failed: ' + Error.Message;
      raise;
    end;
  end;
end;

procedure TLinuxAudioSessionController.Stop;
begin
  CloseOutput(False);
  FSession.RequestStop;
  FProducer.Reset;
  FRing.Reset;
  FStatus := 'Audio stopped.';
end;

procedure TLinuxAudioSessionController.Tick;
var
  PlayedFrames: Int64;
begin
  PlayedFrames := FOutput.TakePlayedFrames;
  if PlayedFrames > 0 then
    FSession.ConsumeFrames(PlayedFrames);

  if FSession.State = ssRunning then
    ProduceUntilRingFull
  else if FOutput.State <> paosClosed then
    CloseOutput(False);

  FStatus := Format('Native PortAudio preview: %d playback frames, %d underruns.',
    [FOutput.PlayedFrames, FRing.UnderrunCount]);
end;

end.
