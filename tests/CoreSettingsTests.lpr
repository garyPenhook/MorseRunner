program CoreSettingsTests;

{$mode delphi}{$H+}

uses
  Math,
  SysUtils,
  ContestSettings,
  ContestTiming;

procedure Check(const Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure CheckEquals(const Expected, Actual: Integer;
  const MessageText: string);
begin
  Check(Expected = Actual, Format('%s: expected %d, got %d',
    [MessageText, Expected, Actual]));
end;

procedure CheckClose(const Expected, Actual, Tolerance: Double;
  const MessageText: string);
begin
  Check(Abs(Expected - Actual) <= Tolerance,
    Format('%s: expected %.9f, got %.9f', [MessageText, Expected, Actual]));
end;

procedure TestDefaults;
var
  Settings: TContestSettings;
begin
  Settings := DefaultContestSettings;
  CheckEquals(30, Settings.Wpm, 'default WPM');
  CheckEquals(11025, Settings.Audio.SampleRate, 'default sample rate');
  CheckEquals(512, Settings.Audio.FramesPerBlock, 'default block size');
  CheckEquals(4, Settings.Audio.RingBlockCount, 'default ring size');
  Check(Settings.RunMode = rmStop, 'default run mode');
end;

procedure TestNormalization;
var
  Settings: TContestSettings;
begin
  Settings := DefaultContestSettings;
  Settings.Callsign := '  ve3nea  ';
  Settings.Wpm := 2;
  Settings.BandwidthHz := 999;
  Settings.PitchHz := 1;
  Settings.RitHz := -999;
  Settings.DurationMinutes := 0;
  Settings.CompetitionDurationMinutes := 999;
  Settings.Band.Activity := 999;
  Settings.Audio.SampleRate := 1;
  Settings.Audio.FramesPerBlock := 9999;
  Settings.Audio.RingBlockCount := 1;
  Settings.Audio.MonitorLevelDb := 999;

  NormalizeContestSettings(Settings);

  Check(Settings.Callsign = 'VE3NEA', 'callsign normalization');
  CheckEquals(10, Settings.Wpm, 'minimum WPM');
  CheckEquals(600, Settings.BandwidthHz, 'maximum bandwidth');
  CheckEquals(300, Settings.PitchHz, 'minimum pitch');
  CheckEquals(-500, Settings.RitHz, 'minimum RIT');
  CheckEquals(1, Settings.DurationMinutes, 'minimum session duration');
  CheckEquals(60, Settings.CompetitionDurationMinutes,
    'maximum competition duration');
  CheckEquals(6, Settings.Band.Activity, 'maximum band activity');
  CheckEquals(8000, Settings.Audio.SampleRate, 'minimum sample rate');
  CheckEquals(2048, Settings.Audio.FramesPerBlock, 'maximum block size');
  CheckEquals(2, Settings.Audio.RingBlockCount, 'minimum ring size');
  CheckEquals(20, Settings.Audio.MonitorLevelDb, 'maximum monitor level');
end;

procedure TestCallsignValidation;
begin
  Check(IsValidCallsign('VE3NEA'), 'valid standard callsign');
  Check(IsValidCallsign('ve3nea'), 'valid lower-case callsign');
  Check(IsValidCallsign('F/VE3NEA'), 'valid slash callsign');
  Check(not IsValidCallsign(''), 'empty callsign rejected');
  Check(not IsValidCallsign('VE3 NEA'), 'space rejected');
  Check(not IsValidCallsign('VE3?EA'), 'question mark rejected');
end;

procedure TestAudioBlockNormalization;
var
  Settings: TContestSettings;
begin
  Settings := DefaultContestSettings;
  Settings.Audio.FramesPerBlock := 129;
  NormalizeContestSettings(Settings);
  CheckEquals(256, Settings.Audio.FramesPerBlock,
    'block size rounds up to a supported value');

  Settings.Audio.FramesPerBlock := 512;
  NormalizeContestSettings(Settings);
  CheckEquals(512, Settings.Audio.FramesPerBlock,
    'supported block size remains unchanged');
end;

procedure TestTiming;
var
  Settings: TContestSettings;
begin
  Settings := DefaultContestSettings;
  CheckEquals(22, SecondsToBlocks(Settings, 1.0),
    'one second rounds to legacy block count');
  CheckClose(512.0 / 11025.0, BlocksToSeconds(Settings, 1),
    1.0e-8, 'one block duration');
  CheckClose(1.0, FramesToSeconds(Settings, 11025),
    1.0e-8, 'one second of frames');

  Settings.RunMode := rmPileup;
  Settings.DurationMinutes := 2;
  CheckClose(120.0, SessionDurationSeconds(Settings),
    1.0e-8, 'pile-up duration');
  Check(not IsSessionFinished(Settings, 120 * 11025 - 1),
    'session does not end early');
  Check(IsSessionFinished(Settings, 120 * 11025),
    'session ends on consumed frame boundary');

  Settings.RunMode := rmHst;
  Settings.CompetitionDurationMinutes := 15;
  CheckClose(900.0, SessionDurationSeconds(Settings),
    1.0e-8, 'HST duration');
end;

begin
  try
    TestDefaults;
    TestNormalization;
    TestCallsignValidation;
    TestAudioBlockNormalization;
    TestTiming;
    WriteLn('Core settings tests passed.');
  except
    on Error: Exception do
    begin
      WriteLn(StdErr, 'Core settings tests failed: ', Error.Message);
      Halt(1);
    end;
  end;
end.
