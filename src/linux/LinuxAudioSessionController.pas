unit LinuxAudioSessionController;

{$mode delphi}{$H+}

interface

uses
  ContestSession,
  ContestSettings,
  MorseMessageTemplate,
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
    FQueuedMessage: string;
    FRepeatPreview: Boolean;
    FStatus: string;
    function GetSession: TContestSession;
    function PreviewMessage: string;
    procedure ProduceUntilRingFull;
    procedure CloseOutput(const AbortStream: Boolean);
  public
    constructor Create(const Settings: TContestSettings);
    destructor Destroy; override;
    procedure Configure(const Settings: TContestSettings);
    procedure Start(const Mode: TRunMode);
    procedure Stop;
    procedure Tick;
    procedure QueueMessage(const TemplateText: string);

    property Session: TContestSession read GetSession;
    property Settings: TContestSettings read FSettings;
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

function TLinuxAudioSessionController.PreviewMessage: string;
begin
  Result := ExpandMorseMessageTemplate('CQ <my> TEST', FSettings.Callsign,
    '', 599, 1);
end;

procedure TLinuxAudioSessionController.ProduceUntilRingFull;
begin
  while FRing.AvailableToWrite > 0 do
  begin
    if not FProducer.HasPendingBlocks then
    begin
      if FQueuedMessage <> '' then
      begin
        FProducer.PrepareMessage(FQueuedMessage);
        FQueuedMessage := '';
      end
      else if FRepeatPreview then
        FProducer.PrepareMessage(PreviewMessage)
      else
        Exit;
    end;
    if not FProducer.TryProduceNextBlock then
      Exit;
  end;
end;

procedure TLinuxAudioSessionController.Configure(const Settings: TContestSettings);
begin
  if FSession.State = ssRunning then
    raise EInvalidOp.Create('Stop the audio session before changing its settings.');

  CloseOutput(False);
  FOutput.Free;
  FProducer.Free;
  FRing.Free;

  FSettings := Settings;
  NormalizeContestSettings(FSettings);
  FSession.Configure(FSettings);
  FRing := TPcmSpscRing.Create(FSettings.Audio.FramesPerBlock,
    FSettings.Audio.RingBlockCount);
  FProducer := TMorseAudioProducer.Create(FRing, FSettings.Wpm,
    FSettings.Audio.SampleRate, FSettings.PitchHz, 6000);
  FOutput := TPortAudioOutput.Create(FRing);
  FQueuedMessage := '';
  FRepeatPreview := False;
  FStatus := 'Audio idle: settings updated.';
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
  FQueuedMessage := '';
  FRepeatPreview := True;
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
      FQueuedMessage := '';
      FRepeatPreview := False;
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
  FQueuedMessage := '';
  FRepeatPreview := False;
  FStatus := 'Audio stopped.';
end;

procedure TLinuxAudioSessionController.QueueMessage(const TemplateText: string);
var
  MessageText: string;
begin
  if FSession.State <> ssRunning then
    raise EInvalidOp.Create('Start the audio session before transmitting.');

  MessageText := Trim(TemplateText);
  if MessageText = '' then
    raise EArgumentException.Create('Enter text to transmit.');

  FQueuedMessage := ExpandMorseMessageTemplate(MessageText, FSettings.Callsign,
    '', 599, FSession.Log.Count + 1);
  FRepeatPreview := False;
  FStatus := 'Queued Morse transmission: ' + FQueuedMessage;
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
