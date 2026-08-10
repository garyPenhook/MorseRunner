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
    FStartButton: TButton;
    FStopButton: TButton;
    FStateLabel: TLabel;
    FClockLabel: TLabel;
    FAudioStatusLabel: TLabel;
    FClockTimer: TTimer;
    procedure StartButtonClick(Sender: TObject);
    procedure StopButtonClick(Sender: TObject);
    procedure ClockTimerTick(Sender: TObject);
    procedure RefreshView;
    function SelectedMode: TRunMode;
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
  ClientWidth := 510;
  ClientHeight := 220;

  FSettingsStore := TContestSettingsStore.Create;
  Settings := FSettingsStore.Load(ImportedLegacy);
  FAudioController := TLinuxAudioSessionController.Create(Settings);

  FModeBox := TComboBox.Create(Self);
  FModeBox.Parent := Self;
  FModeBox.Left := 20;
  FModeBox.Top := 20;
  FModeBox.Width := 180;
  FModeBox.Style := csDropDownList;
  FModeBox.Items.Add('Pile-up');
  FModeBox.Items.Add('Single calls');
  FModeBox.Items.Add('WPX competition');
  FModeBox.Items.Add('HST competition');
  FModeBox.ItemIndex := 0;

  FStartButton := TButton.Create(Self);
  FStartButton.Parent := Self;
  FStartButton.Left := 220;
  FStartButton.Top := 18;
  FStartButton.Width := 100;
  FStartButton.Caption := 'Start';
  FStartButton.OnClick := StartButtonClick;

  FStopButton := TButton.Create(Self);
  FStopButton.Parent := Self;
  FStopButton.Left := 335;
  FStopButton.Top := 18;
  FStopButton.Width := 100;
  FStopButton.Caption := 'Stop';
  FStopButton.OnClick := StopButtonClick;

  FStateLabel := TLabel.Create(Self);
  FStateLabel.Parent := Self;
  FStateLabel.Left := 20;
  FStateLabel.Top := 75;
  FStateLabel.Width := 460;

  FClockLabel := TLabel.Create(Self);
  FClockLabel.Parent := Self;
  FClockLabel.Left := 20;
  FClockLabel.Top := 105;
  FClockLabel.Width := 460;

  FAudioStatusLabel := TLabel.Create(Self);
  FAudioStatusLabel.Parent := Self;
  FAudioStatusLabel.Left := 20;
  FAudioStatusLabel.Top := 145;
  FAudioStatusLabel.Width := 460;
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

procedure TMainForm.StartButtonClick(Sender: TObject);
begin
  try
    FAudioController.Start(SelectedMode);
    FClockTimer.Enabled := True;
  except
    FClockTimer.Enabled := False;
  end;
  RefreshView;
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
  FClockLabel.Caption := Format('Playback clock: %.3f seconds, %d frames',
    [FAudioController.Session.ElapsedSeconds,
    FAudioController.Session.ConsumedFrames]);
  FAudioStatusLabel.Caption := FAudioController.Status;
  FStartButton.Enabled := FAudioController.Session.State <> ssRunning;
  FStopButton.Enabled := FAudioController.Session.State = ssRunning;
end;

end.
