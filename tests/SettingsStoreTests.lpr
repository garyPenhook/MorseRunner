program SettingsStoreTests;

{$mode delphi}{$H+}

uses
  IniFiles,
  SysUtils,
  ContestSettings,
  SettingsStore;

procedure Check(const Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure CheckEquals(const Expected, Actual: Integer; const MessageText: string);
begin
  Check(Expected = Actual, Format('%s: expected %d, got %d',
    [MessageText, Expected, Actual]));
end;

function TestFileName(const Suffix: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'morserunner-settings-store-' + IntToStr(GetTickCount64) + '-' + Suffix;
end;

procedure TestRoundTrip;
var
  FileName: string;
  Store: TContestSettingsStore;
  Settings: TContestSettings;
  Loaded: TContestSettings;
  ImportedLegacy: Boolean;
begin
  FileName := TestFileName('roundtrip.ini');
  DeleteFile(FileName);
  Store := TContestSettingsStore.Create(FileName);
  try
    Settings := DefaultContestSettings;
    Settings.Callsign := 'f/ve3nea';
    Settings.HamName := 'Ada Lovelace';
    Settings.Wpm := 37;
    Settings.BandwidthHz := 450;
    Settings.PitchHz := 700;
    Settings.Qsk := False;
    Settings.RitHz := -120;
    Settings.DurationMinutes := 45;
    Settings.CompetitionDurationMinutes := 20;
    Settings.RunMode := rmWpx;
    Settings.SaveWav := True;
    Settings.CallsFromKeyer := True;
    Settings.Band.Activity := 5;
    Settings.Band.Qrn := False;
    Settings.Audio.SampleRate := 22050;
    Settings.Audio.FramesPerBlock := 256;
    Settings.Audio.RingBlockCount := 7;
    Settings.Audio.MonitorLevelDb := -8;
    Store.Save(Settings);
    Check(not FileExists(FileName + '.new'), 'temporary settings file is replaced');

    Loaded := Store.Load(ImportedLegacy);
    Check(not ImportedLegacy, 'native settings are not an import');
    Check(Loaded.Callsign = 'F/VE3NEA', 'callsign round trip');
    Check(Loaded.HamName = 'Ada Lovelace', 'name round trip');
    CheckEquals(37, Loaded.Wpm, 'WPM round trip');
    CheckEquals(450, Loaded.BandwidthHz, 'bandwidth round trip');
    CheckEquals(700, Loaded.PitchHz, 'pitch round trip');
    Check(not Loaded.Qsk, 'QSK round trip');
    CheckEquals(-120, Loaded.RitHz, 'RIT round trip');
    CheckEquals(45, Loaded.DurationMinutes, 'duration round trip');
    Check(Loaded.RunMode = rmWpx, 'run mode round trip');
    Check(Loaded.SaveWav, 'SaveWav round trip');
    Check(Loaded.CallsFromKeyer, 'keyer calls round trip');
    CheckEquals(5, Loaded.Band.Activity, 'activity round trip');
    Check(not Loaded.Band.Qrn, 'QRN round trip');
    CheckEquals(22050, Loaded.Audio.SampleRate, 'sample rate round trip');
    CheckEquals(256, Loaded.Audio.FramesPerBlock, 'block size round trip');
    CheckEquals(7, Loaded.Audio.RingBlockCount, 'ring size round trip');
    CheckEquals(-8, Loaded.Audio.MonitorLevelDb, 'monitor level round trip');
  finally
    Store.Free;
    DeleteFile(FileName);
  end;
end;

procedure TestLegacyImport;
var
  ConfigFileName: string;
  LegacyFileName: string;
  LegacyIni: TIniFile;
  Store: TContestSettingsStore;
  Settings: TContestSettings;
  ImportedLegacy: Boolean;
begin
  ConfigFileName := TestFileName('imported.ini');
  LegacyFileName := TestFileName('legacy.ini');
  DeleteFile(ConfigFileName);
  DeleteFile(LegacyFileName);
  LegacyIni := TIniFile.Create(LegacyFileName);
  try
    LegacyIni.WriteString('Station', 'Call', 'va3xyz');
    LegacyIni.WriteInteger('Station', 'Pitch', 3);
    LegacyIni.WriteInteger('Station', 'BandWidth', 9);
    LegacyIni.WriteInteger('Station', 'Wpm', 200);
    LegacyIni.WriteBool('Station', 'Qsk', False);
    LegacyIni.WriteBool('Station', 'CallsFromKeyer', True);
    LegacyIni.WriteBool('Station', 'SaveWav', True);
    LegacyIni.WriteInteger('Band', 'Activity', 4);
    LegacyIni.WriteBool('Band', 'Qrm', False);
    LegacyIni.WriteInteger('Contest', 'Duration', 15);
    LegacyIni.WriteInteger('Contest', 'CompetitionDuration', 20);
    LegacyIni.WriteInteger('System', 'BufSize', 2);
    LegacyIni.UpdateFile;
  finally
    LegacyIni.Free;
  end;

  Store := TContestSettingsStore.Create(ConfigFileName, LegacyFileName);
  try
    Settings := Store.Load(ImportedLegacy);
    Check(ImportedLegacy, 'legacy settings are imported once');
    Check(FileExists(ConfigFileName), 'import is persisted in XDG-style config');
    Check(Settings.Callsign = 'VA3XYZ', 'legacy call import');
    CheckEquals(450, Settings.PitchHz, 'legacy pitch index import');
    CheckEquals(550, Settings.BandwidthHz, 'legacy bandwidth index import');
    CheckEquals(120, Settings.Wpm, 'legacy settings normalize');
    Check(not Settings.Qsk, 'legacy QSK import');
    Check(Settings.CallsFromKeyer, 'legacy keyer calls import');
    Check(Settings.SaveWav, 'legacy WAV flag import');
    CheckEquals(4, Settings.Band.Activity, 'legacy activity import');
    Check(not Settings.Band.Qrm, 'legacy QRM import');
    CheckEquals(15, Settings.DurationMinutes, 'legacy duration import');
    CheckEquals(20, Settings.CompetitionDurationMinutes,
      'legacy competition duration import');
    CheckEquals(256, Settings.Audio.FramesPerBlock, 'legacy block size import');

    Settings := Store.Load(ImportedLegacy);
    Check(not ImportedLegacy, 'native config wins after the initial import');
    Check(Settings.Callsign = 'VA3XYZ', 'persisted import reloads');
  finally
    Store.Free;
    DeleteFile(ConfigFileName);
    DeleteFile(LegacyFileName);
  end;
end;

procedure TestLegacyBufferSizeClamp;
var
  ConfigFileName: string;
  LegacyFileName: string;
  LegacyIni: TIniFile;
  Store: TContestSettingsStore;
  Settings: TContestSettings;
  ImportedLegacy: Boolean;
begin
  ConfigFileName := TestFileName('clamped.ini');
  LegacyFileName := TestFileName('large-buffer.ini');
  DeleteFile(ConfigFileName);
  DeleteFile(LegacyFileName);
  LegacyIni := TIniFile.Create(LegacyFileName);
  try
    LegacyIni.WriteInteger('System', 'BufSize', 999);
    LegacyIni.UpdateFile;
  finally
    LegacyIni.Free;
  end;

  Store := TContestSettingsStore.Create(ConfigFileName, LegacyFileName);
  try
    Settings := Store.Load(ImportedLegacy);
    Check(ImportedLegacy, 'legacy oversized buffer is imported');
    CheckEquals(2048, Settings.Audio.FramesPerBlock,
      'legacy buffer exponent is clamped before shifting');
  finally
    Store.Free;
    DeleteFile(ConfigFileName);
    DeleteFile(LegacyFileName);
  end;
end;

begin
  try
    TestRoundTrip;
    TestLegacyImport;
    TestLegacyBufferSizeClamp;
    WriteLn('Settings store tests passed.');
  except
    on Error: Exception do
    begin
      WriteLn(StdErr, 'Settings store tests failed: ', Error.Message);
      Halt(1);
    end;
  end;
end.
