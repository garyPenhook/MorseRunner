//------------------------------------------------------------------------------
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit SettingsStore;

{$mode delphi}{$H+}

interface

uses
  ContestSettings;

type
  TContestSettingsStore = class
  private
    FConfigFileName: string;
    FLegacyConfigFileName: string;
    function LoadNativeSettings: TContestSettings;
    function LoadLegacySettings: TContestSettings;
  public
    constructor Create(const ConfigFileName: string = '';
      const LegacyConfigFileName: string = '');
    function Load(out ImportedLegacy: Boolean): TContestSettings;
    procedure Save(const Settings: TContestSettings);

    property ConfigFileName: string read FConfigFileName;
  end;

function DefaultSettingsFileName: string;

implementation

uses
  IniFiles,
  SysUtils;

const
  SECTION_STATION = 'Station';
  SECTION_BAND = 'Band';
  SECTION_CONTEST = 'Contest';
  SECTION_AUDIO = 'Audio';
  SECTION_SYSTEM = 'System';

function XdgConfigHome: string;
begin
  Result := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if Result = '' then
  begin
    Result := GetEnvironmentVariable('HOME');
    if Result = '' then
      Result := GetCurrentDir
    else
      Result := IncludeTrailingPathDelimiter(Result) + '.config';
  end;
end;

function DefaultSettingsFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(XdgConfigHome) + 'morserunner' +
    PathDelim + 'config.ini';
end;

function RunModeToString(const Mode: TRunMode): string;
begin
  case Mode of
    rmPileup: Result := 'pileup';
    rmSingle: Result := 'single';
    rmWpx: Result := 'wpx';
    rmHst: Result := 'hst';
  else
    Result := 'stop';
  end;
end;

function StringToRunMode(const Value: string): TRunMode;
begin
  if SameText(Value, 'pileup') then
    Result := rmPileup
  else if SameText(Value, 'single') then
    Result := rmSingle
  else if SameText(Value, 'wpx') then
    Result := rmWpx
  else if SameText(Value, 'hst') then
    Result := rmHst
  else
    Result := rmStop;
end;

function ExistingLegacyFileName: string;
var
  Candidate: string;
begin
  Candidate := IncludeTrailingPathDelimiter(GetCurrentDir) + 'MorseRunner.ini';
  if FileExists(Candidate) then
    Exit(Candidate);

  Candidate := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) +
    'MorseRunner.ini';
  if FileExists(Candidate) then
    Exit(Candidate);

  Result := '';
end;

constructor TContestSettingsStore.Create(const ConfigFileName: string;
  const LegacyConfigFileName: string);
begin
  inherited Create;
  if ConfigFileName = '' then
    FConfigFileName := DefaultSettingsFileName
  else
    FConfigFileName := ConfigFileName;

  if LegacyConfigFileName = '' then
    FLegacyConfigFileName := ExistingLegacyFileName
  else
    FLegacyConfigFileName := LegacyConfigFileName;
end;

function TContestSettingsStore.LoadNativeSettings: TContestSettings;
var
  Ini: TIniFile;
begin
  Result := DefaultContestSettings;
  Ini := TIniFile.Create(FConfigFileName);
  try
    Result.Callsign := Ini.ReadString(SECTION_STATION, 'Callsign',
      Result.Callsign);
    Result.HamName := Ini.ReadString(SECTION_STATION, 'Name', Result.HamName);
    Result.Wpm := Ini.ReadInteger(SECTION_STATION, 'Wpm', Result.Wpm);
    Result.BandwidthHz := Ini.ReadInteger(SECTION_STATION, 'BandwidthHz',
      Result.BandwidthHz);
    Result.PitchHz := Ini.ReadInteger(SECTION_STATION, 'PitchHz', Result.PitchHz);
    Result.Qsk := Ini.ReadBool(SECTION_STATION, 'Qsk', Result.Qsk);
    Result.RitHz := Ini.ReadInteger(SECTION_STATION, 'RitHz', Result.RitHz);
    Result.CallsFromKeyer := Ini.ReadBool(SECTION_STATION, 'CallsFromKeyer',
      Result.CallsFromKeyer);
    Result.SaveWav := Ini.ReadBool(SECTION_STATION, 'SaveWav', Result.SaveWav);

    Result.Band.Activity := Ini.ReadInteger(SECTION_BAND, 'Activity',
      Result.Band.Activity);
    Result.Band.Qrn := Ini.ReadBool(SECTION_BAND, 'Qrn', Result.Band.Qrn);
    Result.Band.Qrm := Ini.ReadBool(SECTION_BAND, 'Qrm', Result.Band.Qrm);
    Result.Band.Qsb := Ini.ReadBool(SECTION_BAND, 'Qsb', Result.Band.Qsb);
    Result.Band.Flutter := Ini.ReadBool(SECTION_BAND, 'Flutter',
      Result.Band.Flutter);
    Result.Band.Lids := Ini.ReadBool(SECTION_BAND, 'Lids', Result.Band.Lids);

    Result.DurationMinutes := Ini.ReadInteger(SECTION_CONTEST, 'DurationMinutes',
      Result.DurationMinutes);
    Result.CompetitionDurationMinutes := Ini.ReadInteger(SECTION_CONTEST,
      'CompetitionDurationMinutes', Result.CompetitionDurationMinutes);
    Result.RunMode := StringToRunMode(Ini.ReadString(SECTION_CONTEST, 'RunMode',
      RunModeToString(Result.RunMode)));

    Result.Audio.SampleRate := Ini.ReadInteger(SECTION_AUDIO, 'SampleRate',
      Result.Audio.SampleRate);
    Result.Audio.FramesPerBlock := Ini.ReadInteger(SECTION_AUDIO,
      'FramesPerBlock', Result.Audio.FramesPerBlock);
    Result.Audio.RingBlockCount := Ini.ReadInteger(SECTION_AUDIO,
      'RingBlockCount', Result.Audio.RingBlockCount);
    Result.Audio.MonitorLevelDb := Ini.ReadInteger(SECTION_AUDIO,
      'MonitorLevelDb', Result.Audio.MonitorLevelDb);
  finally
    Ini.Free;
  end;
  NormalizeContestSettings(Result);
end;

function TContestSettingsStore.LoadLegacySettings: TContestSettings;
var
  Ini: TIniFile;
  BufferSizeExponent: Integer;
begin
  Result := DefaultContestSettings;
  Ini := TIniFile.Create(FLegacyConfigFileName);
  try
    Result.Callsign := Ini.ReadString(SECTION_STATION, 'Call', Result.Callsign);
    Result.HamName := Ini.ReadString(SECTION_STATION, 'Name', Result.HamName);
    Result.Wpm := Ini.ReadInteger(SECTION_STATION, 'Wpm', Result.Wpm);
    Result.PitchHz := 300 + 50 * Ini.ReadInteger(SECTION_STATION, 'Pitch', 6);
    Result.BandwidthHz := 100 + 50 * Ini.ReadInteger(SECTION_STATION,
      'BandWidth', 8);
    Result.Qsk := Ini.ReadBool(SECTION_STATION, 'Qsk', Result.Qsk);
    Result.CallsFromKeyer := Ini.ReadBool(SECTION_STATION, 'CallsFromKeyer',
      Result.CallsFromKeyer);
    Result.SaveWav := Ini.ReadBool(SECTION_STATION, 'SaveWav', Result.SaveWav);

    Result.Band.Activity := Ini.ReadInteger(SECTION_BAND, 'Activity',
      Result.Band.Activity);
    Result.Band.Qrn := Ini.ReadBool(SECTION_BAND, 'Qrn', Result.Band.Qrn);
    Result.Band.Qrm := Ini.ReadBool(SECTION_BAND, 'Qrm', Result.Band.Qrm);
    Result.Band.Qsb := Ini.ReadBool(SECTION_BAND, 'Qsb', Result.Band.Qsb);
    Result.Band.Flutter := Ini.ReadBool(SECTION_BAND, 'Flutter',
      Result.Band.Flutter);
    Result.Band.Lids := Ini.ReadBool(SECTION_BAND, 'Lids', Result.Band.Lids);

    Result.DurationMinutes := Ini.ReadInteger(SECTION_CONTEST, 'Duration',
      Result.DurationMinutes);
    Result.CompetitionDurationMinutes := Ini.ReadInteger(SECTION_CONTEST,
      'CompetitionDuration', Result.CompetitionDurationMinutes);

    BufferSizeExponent := Ini.ReadInteger(SECTION_SYSTEM, 'BufSize', 3);
    if BufferSizeExponent < 1 then
      BufferSizeExponent := 1
    else if BufferSizeExponent > 5 then
      BufferSizeExponent := 5;
    Result.Audio.FramesPerBlock := 64 shl BufferSizeExponent;
  finally
    Ini.Free;
  end;
  NormalizeContestSettings(Result);
end;

function TContestSettingsStore.Load(out ImportedLegacy: Boolean): TContestSettings;
begin
  ImportedLegacy := False;
  if FileExists(FConfigFileName) then
    Exit(LoadNativeSettings);

  if (FLegacyConfigFileName <> '') and FileExists(FLegacyConfigFileName) then
  begin
    Result := LoadLegacySettings;
    Save(Result);
    ImportedLegacy := True;
  end
  else
    Result := DefaultContestSettings;
end;

procedure TContestSettingsStore.Save(const Settings: TContestSettings);
var
  Ini: TMemIniFile;
  NormalizedSettings: TContestSettings;
  ConfigDirectory: string;
  TemporaryFileName: string;
begin
  NormalizedSettings := Settings;
  NormalizeContestSettings(NormalizedSettings);
  ConfigDirectory := ExtractFileDir(FConfigFileName);
  if (ConfigDirectory <> '') and not ForceDirectories(ConfigDirectory) then
    raise Exception.CreateFmt('Cannot create configuration directory "%s".',
      [ConfigDirectory]);

  // Never rewrite the live configuration in place. A complete same-directory
  // temporary file can be atomically renamed on POSIX filesystems, so a crash
  // leaves either the old valid settings or the new valid settings.
  TemporaryFileName := FConfigFileName + '.new';
  DeleteFile(TemporaryFileName);
  Ini := TMemIniFile.Create(TemporaryFileName);
  try
    Ini.WriteString(SECTION_STATION, 'Callsign', NormalizedSettings.Callsign);
    Ini.WriteString(SECTION_STATION, 'Name', NormalizedSettings.HamName);
    Ini.WriteInteger(SECTION_STATION, 'Wpm', NormalizedSettings.Wpm);
    Ini.WriteInteger(SECTION_STATION, 'BandwidthHz', NormalizedSettings.BandwidthHz);
    Ini.WriteInteger(SECTION_STATION, 'PitchHz', NormalizedSettings.PitchHz);
    Ini.WriteBool(SECTION_STATION, 'Qsk', NormalizedSettings.Qsk);
    Ini.WriteInteger(SECTION_STATION, 'RitHz', NormalizedSettings.RitHz);
    Ini.WriteBool(SECTION_STATION, 'CallsFromKeyer',
      NormalizedSettings.CallsFromKeyer);
    Ini.WriteBool(SECTION_STATION, 'SaveWav', NormalizedSettings.SaveWav);

    Ini.WriteInteger(SECTION_BAND, 'Activity', NormalizedSettings.Band.Activity);
    Ini.WriteBool(SECTION_BAND, 'Qrn', NormalizedSettings.Band.Qrn);
    Ini.WriteBool(SECTION_BAND, 'Qrm', NormalizedSettings.Band.Qrm);
    Ini.WriteBool(SECTION_BAND, 'Qsb', NormalizedSettings.Band.Qsb);
    Ini.WriteBool(SECTION_BAND, 'Flutter', NormalizedSettings.Band.Flutter);
    Ini.WriteBool(SECTION_BAND, 'Lids', NormalizedSettings.Band.Lids);

    Ini.WriteInteger(SECTION_CONTEST, 'DurationMinutes',
      NormalizedSettings.DurationMinutes);
    Ini.WriteInteger(SECTION_CONTEST, 'CompetitionDurationMinutes',
      NormalizedSettings.CompetitionDurationMinutes);
    Ini.WriteString(SECTION_CONTEST, 'RunMode',
      RunModeToString(NormalizedSettings.RunMode));

    Ini.WriteInteger(SECTION_AUDIO, 'SampleRate',
      NormalizedSettings.Audio.SampleRate);
    Ini.WriteInteger(SECTION_AUDIO, 'FramesPerBlock',
      NormalizedSettings.Audio.FramesPerBlock);
    Ini.WriteInteger(SECTION_AUDIO, 'RingBlockCount',
      NormalizedSettings.Audio.RingBlockCount);
    Ini.WriteInteger(SECTION_AUDIO, 'MonitorLevelDb',
      NormalizedSettings.Audio.MonitorLevelDb);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;

  if not RenameFile(TemporaryFileName, FConfigFileName) then
  begin
    DeleteFile(TemporaryFileName);
    raise Exception.CreateFmt('Cannot replace configuration file "%s".',
      [FConfigFileName]);
  end;
end;

end.
