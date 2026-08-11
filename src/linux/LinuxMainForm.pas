unit LinuxMainForm;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  Forms,
  Controls,
  StdCtrls,
  ExtCtrls,
  LCLType,
  Spin,
  ContestSettings,
  ContestSession,
  LinuxAudioSessionController,
  SettingsStore;

type
  TMainForm = class(TForm)
  private
    FAudioController: TLinuxAudioSessionController;
    FSettingsStore: TContestSettingsStore;
    FModeBox: TComboBox;
    FCallsignEdit: TEdit;
    FWpmSpin: TSpinEdit;
    FPitchSpin: TSpinEdit;
    FDurationSpin: TSpinEdit;
    FTransmitEdit: TEdit;
    FStartButton: TButton;
    FStopButton: TButton;
    FTransmitButton: TButton;
    FPracticeGuideLabel: TLabel;
    FLogLabel: TLabel;
    FStateLabel: TLabel;
    FClockLabel: TLabel;
    FAudioStatusLabel: TLabel;
    FClockTimer: TTimer;
    procedure StartButtonClick(Sender: TObject);
    procedure StopButtonClick(Sender: TObject);
    procedure TransmitButtonClick(Sender: TObject);
    procedure TransmitEditKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure ClockTimerTick(Sender: TObject);
    procedure RefreshView;
    function SelectedMode: TRunMode;
    function EditedSettings: TContestSettings;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

constructor TMainForm.Create(TheOwner: TComponent);
var
  Settings: TContestSettings;
  ImportedLegacy: Boolean;
begin
  inherited Create(TheOwner);
  Caption := 'MorseRunner Linux — native audio preview';
  Position := poScreenCenter;
  ClientWidth := 580;
  ClientHeight := 340;

  FSettingsStore := TContestSettingsStore.Create;
  Settings := FSettingsStore.Load(ImportedLegacy);
  FAudioController := TLinuxAudioSessionController.Create(Settings);

  with TLabel.Create(Self) do
  begin
    Parent := Self;
    Left := 20;
    Top := 22;
    Caption := 'My call';
  end;
  FCallsignEdit := TEdit.Create(Self);
  FCallsignEdit.Parent := Self;
  FCallsignEdit.Left := 90;
  FCallsignEdit.Top := 18;
  FCallsignEdit.Width := 100;
  FCallsignEdit.Text := Settings.Callsign;

  with TLabel.Create(Self) do
  begin
    Parent := Self;
    Left := 210;
    Top := 22;
    Caption := 'WPM';
  end;
  FWpmSpin := TSpinEdit.Create(Self);
  FWpmSpin.Parent := Self;
  FWpmSpin.Left := 250;
  FWpmSpin.Top := 18;
  FWpmSpin.Width := 60;
  FWpmSpin.MinValue := 10;
  FWpmSpin.MaxValue := 120;
  FWpmSpin.Value := Settings.Wpm;

  with TLabel.Create(Self) do
  begin
    Parent := Self;
    Left := 330;
    Top := 22;
    Caption := 'Pitch';
  end;
  FPitchSpin := TSpinEdit.Create(Self);
  FPitchSpin.Parent := Self;
  FPitchSpin.Left := 370;
  FPitchSpin.Top := 18;
  FPitchSpin.Width := 70;
  FPitchSpin.MinValue := 300;
  FPitchSpin.MaxValue := 900;
  FPitchSpin.Increment := 50;
  FPitchSpin.Value := Settings.PitchHz;

  with TLabel.Create(Self) do
  begin
    Parent := Self;
    Left := 455;
    Top := 22;
    Caption := 'Minutes';
  end;
  FDurationSpin := TSpinEdit.Create(Self);
  FDurationSpin.Parent := Self;
  FDurationSpin.Left := 510;
  FDurationSpin.Top := 18;
  FDurationSpin.Width := 50;
  FDurationSpin.MinValue := 1;
  FDurationSpin.MaxValue := 240;
  FDurationSpin.Value := Settings.DurationMinutes;

  FModeBox := TComboBox.Create(Self);
  FModeBox.Parent := Self;
  FModeBox.Left := 20;
  FModeBox.Top := 58;
  FModeBox.Width := 180;
  FModeBox.Style := csDropDownList;
  FModeBox.Items.Add('Timed Morse preview');
  FModeBox.Items.Add('Single-session preview');
  FModeBox.Items.Add('WPX-timed preview');
  FModeBox.Items.Add('HST-timed preview');
  FModeBox.ItemIndex := 0;

  FStartButton := TButton.Create(Self);
  FStartButton.Parent := Self;
  FStartButton.Left := 220;
  FStartButton.Top := 56;
  FStartButton.Width := 100;
  FStartButton.Caption := 'Start';
  FStartButton.OnClick := StartButtonClick;

  FStopButton := TButton.Create(Self);
  FStopButton.Parent := Self;
  FStopButton.Left := 335;
  FStopButton.Top := 56;
  FStopButton.Width := 100;
  FStopButton.Caption := 'Stop';
  FStopButton.OnClick := StopButtonClick;

  FTransmitEdit := TEdit.Create(Self);
  FTransmitEdit.Parent := Self;
  FTransmitEdit.Left := 20;
  FTransmitEdit.Top := 105;
  FTransmitEdit.Width := 405;
  FTransmitEdit.Text := 'CQ <my> TEST';

  FTransmitButton := TButton.Create(Self);
  FTransmitButton.Parent := Self;
  FTransmitButton.Left := 440;
  FTransmitButton.Top := 103;
  FTransmitButton.Width := 120;
  FTransmitButton.Caption := 'Transmit text';
  FTransmitButton.OnClick := TransmitButtonClick;

  FTransmitEdit.OnKeyDown := TransmitEditKeyDown;

  FPracticeGuideLabel := TLabel.Create(Self);
  FPracticeGuideLabel.Parent := Self;
  FPracticeGuideLabel.Left := 20;
  FPracticeGuideLabel.Top := 136;
  FPracticeGuideLabel.Width := 540;

  FStateLabel := TLabel.Create(Self);
  FStateLabel.Parent := Self;
  FStateLabel.Left := 20;
  FStateLabel.Top := 166;
  FStateLabel.Width := 540;

  FClockLabel := TLabel.Create(Self);
  FClockLabel.Parent := Self;
  FClockLabel.Left := 20;
  FClockLabel.Top := 196;
  FClockLabel.Width := 540;

  FAudioStatusLabel := TLabel.Create(Self);
  FAudioStatusLabel.Parent := Self;
  FAudioStatusLabel.Left := 20;
  FLogLabel := TLabel.Create(Self);
  FLogLabel.Parent := Self;
  FLogLabel.Left := 20;
  FLogLabel.Top := 222;
  FLogLabel.Width := 540;

  FAudioStatusLabel.Top := 252;
  FAudioStatusLabel.Width := 540;
  FAudioStatusLabel.WordWrap := True;
  FAudioStatusLabel.Caption := FAudioController.Status;

  FClockTimer := TTimer.Create(Self);
  FClockTimer.Interval := 30;
  FClockTimer.OnTimer := ClockTimerTick;
  FClockTimer.Enabled := False;
  RefreshView;
end;

destructor TMainForm.Destroy;
begin
  try
    FSettingsStore.Save(FAudioController.Settings);
  except
    { Shutdown must still release the audio device when persistence fails. }
  end;
  FAudioController.Free;
  FSettingsStore.Free;
  inherited Destroy;
end;

function TMainForm.SelectedMode: TRunMode;
begin
  case FModeBox.ItemIndex of
    1: Result := rmSingle;
    2: Result := rmWpx;
    3: Result := rmHst;
  else
    Result := rmPileup;
  end;
end;

function TMainForm.EditedSettings: TContestSettings;
begin
  Result := FAudioController.Settings;
  Result.Callsign := FCallsignEdit.Text;
  Result.Wpm := FWpmSpin.Value;
  Result.PitchHz := FPitchSpin.Value;
  Result.DurationMinutes := FDurationSpin.Value;
  NormalizeContestSettings(Result);
  if not IsValidCallsign(Result.Callsign) then
    raise EArgumentException.Create('Enter a valid callsign before starting.');
end;

procedure TMainForm.StartButtonClick(Sender: TObject);
begin
  try
    FAudioController.Configure(EditedSettings);
    FAudioController.Start(SelectedMode);
    if SelectedMode = rmSingle then
      FTransmitEdit.Text := '<his> <#>';
    FClockTimer.Enabled := True;
  except
    on Error: Exception do
    begin
      FClockTimer.Enabled := False;
      FAudioStatusLabel.Caption := 'Audio start failed: ' + Error.Message;
    end;
  end;
  RefreshView;
end;

procedure TMainForm.TransmitButtonClick(Sender: TObject);
begin
  try
    FAudioController.QueueMessage(FTransmitEdit.Text);
  except
    on Error: Exception do
      FAudioStatusLabel.Caption := 'Transmit failed: ' + Error.Message;
  end;
  RefreshView;
end;

procedure TMainForm.TransmitEditKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    Key := 0;
    TransmitButtonClick(Sender);
  end;
end;

procedure TMainForm.StopButtonClick(Sender: TObject);
begin
  FAudioController.Stop;
  FClockTimer.Enabled := False;
  RefreshView;
end;

procedure TMainForm.ClockTimerTick(Sender: TObject);
begin
  FAudioController.Tick;
  if FAudioController.Session.State <> ssRunning then
    FClockTimer.Enabled := False;
  RefreshView;
end;

procedure TMainForm.RefreshView;
const
  StateText: array[TSessionState] of string =
    ('Stopped', 'Running', 'Finished');
  EndText: array[TSessionEndReason] of string =
    ('none', 'time elapsed', 'user stop');
begin
  FStateLabel.Caption := Format('Session: %s (end reason: %s)',
    [StateText[FAudioController.Session.State],
    EndText[FAudioController.Session.EndReason]]);
  if FAudioController.Session.State = ssRunning then
    FStateLabel.Caption := FStateLabel.Caption + Format(
      '  Caller: %s (%d database calls)', [FAudioController.PracticeCall,
      FAudioController.CallListCount]);
  if (FAudioController.Session.State = ssRunning) and
     (FAudioController.Session.Settings.RunMode = rmSingle) then
    FPracticeGuideLabel.Caption :=
      'Single Calls: send <his> <#>, wait for R 599nnn, then send TU. Press Enter to transmit.'
  else
    FPracticeGuideLabel.Caption :=
      'Use <my>, <his>, and <#> in transmitted text. Press Enter to transmit.';
  FClockLabel.Caption := Format('Playback clock: %.3f seconds, %d frames, %d QSO(s)',
    [FAudioController.Session.ElapsedSeconds,
    FAudioController.Session.ConsumedFrames, FAudioController.Session.Log.Count]);
  if FAudioController.Session.Log.Count > 0 then
    with FAudioController.Session.Log.Items[FAudioController.Session.Log.Count - 1] do
      FLogLabel.Caption := Format('Last QSO: %s  %d%3.3d  %s',
        [Call, Rst, Nr, Err])
  else
    FLogLabel.Caption := 'Last QSO: none';
  FAudioStatusLabel.Caption := FAudioController.Status;
  FStartButton.Enabled := FAudioController.Session.State <> ssRunning;
  FStopButton.Enabled := FAudioController.Session.State = ssRunning;
  FTransmitButton.Enabled := FAudioController.Session.State = ssRunning;
  FCallsignEdit.Enabled := FAudioController.Session.State <> ssRunning;
  FWpmSpin.Enabled := FAudioController.Session.State <> ssRunning;
  FPitchSpin.Enabled := FAudioController.Session.State <> ssRunning;
  FDurationSpin.Enabled := FAudioController.Session.State <> ssRunning;
  FModeBox.Enabled := FAudioController.Session.State <> ssRunning;
end;

end.
