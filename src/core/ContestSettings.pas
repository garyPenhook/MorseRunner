//------------------------------------------------------------------------------
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit ContestSettings;

{$mode delphi}{$H+}

interface

type
  TRunMode = (rmStop, rmPileup, rmSingle, rmWpx, rmHst);

  TBandConditions = record
    Activity: Integer;
    Qrn: Boolean;
    Qrm: Boolean;
    Qsb: Boolean;
    Flutter: Boolean;
    Lids: Boolean;
  end;

  TAudioSettings = record
    SampleRate: Integer;
    FramesPerBlock: Integer;
    RingBlockCount: Integer;
    MonitorLevelDb: Integer;
  end;

  TContestSettings = record
    Callsign: string;
    HamName: string;
    Wpm: Integer;
    BandwidthHz: Integer;
    PitchHz: Integer;
    Qsk: Boolean;
    RitHz: Integer;
    DurationMinutes: Integer;
    CompetitionDurationMinutes: Integer;
    RunMode: TRunMode;
    SaveWav: Boolean;
    CallsFromKeyer: Boolean;
    Band: TBandConditions;
    Audio: TAudioSettings;
  end;

function DefaultContestSettings: TContestSettings;
procedure NormalizeContestSettings(var Settings: TContestSettings);
function IsValidCallsign(const Callsign: string): Boolean;

implementation

uses
  SysUtils;

const
  DEFAULT_SAMPLE_RATE = 11025;
  DEFAULT_FRAMES_PER_BLOCK = 512;
  DEFAULT_RING_BLOCK_COUNT = 4;

function Clamp(Value, MinValue, MaxValue: Integer): Integer;
begin
  if Value < MinValue then
    Result := MinValue
  else if Value > MaxValue then
    Result := MaxValue
  else
    Result := Value;
end;

function NormalizeFramesPerBlock(Value: Integer): Integer;
begin
  if Value <= 128 then
    Result := 128
  else if Value <= 256 then
    Result := 256
  else if Value <= 512 then
    Result := 512
  else if Value <= 1024 then
    Result := 1024
  else
    Result := 2048;
end;

function DefaultContestSettings: TContestSettings;
begin
  Result.Callsign := 'VE3NEA';
  Result.HamName := '';
  Result.Wpm := 30;
  Result.BandwidthHz := 500;
  Result.PitchHz := 600;
  Result.Qsk := True;
  Result.RitHz := 0;
  Result.DurationMinutes := 30;
  Result.CompetitionDurationMinutes := 60;
  Result.RunMode := rmStop;
  Result.SaveWav := False;
  Result.CallsFromKeyer := False;

  Result.Band.Activity := 2;
  Result.Band.Qrn := True;
  Result.Band.Qrm := True;
  Result.Band.Qsb := True;
  Result.Band.Flutter := True;
  Result.Band.Lids := True;

  Result.Audio.SampleRate := DEFAULT_SAMPLE_RATE;
  Result.Audio.FramesPerBlock := DEFAULT_FRAMES_PER_BLOCK;
  Result.Audio.RingBlockCount := DEFAULT_RING_BLOCK_COUNT;
  Result.Audio.MonitorLevelDb := 0;
end;

procedure NormalizeContestSettings(var Settings: TContestSettings);
begin
  Settings.Callsign := UpperCase(Trim(Settings.Callsign));
  Settings.Wpm := Clamp(Settings.Wpm, 10, 120);
  Settings.BandwidthHz := Clamp(Settings.BandwidthHz, 100, 600);
  Settings.PitchHz := Clamp(Settings.PitchHz, 300, 900);
  Settings.RitHz := Clamp(Settings.RitHz, -500, 500);
  Settings.DurationMinutes := Clamp(Settings.DurationMinutes, 1, 240);
  Settings.CompetitionDurationMinutes :=
    Clamp(Settings.CompetitionDurationMinutes, 1, 60);
  Settings.Band.Activity := Clamp(Settings.Band.Activity, 1, 6);

  Settings.Audio.SampleRate := Clamp(Settings.Audio.SampleRate, 8000, 48000);
  Settings.Audio.FramesPerBlock :=
    NormalizeFramesPerBlock(Settings.Audio.FramesPerBlock);
  Settings.Audio.RingBlockCount :=
    Clamp(Settings.Audio.RingBlockCount, 2, 16);
  Settings.Audio.MonitorLevelDb :=
    Clamp(Settings.Audio.MonitorLevelDb, -60, 20);
end;

function IsValidCallsign(const Callsign: string): Boolean;
var
  Index: Integer;
  Character: Char;
begin
  Result := (Callsign <> '') and (Length(Callsign) <= 15);
  if not Result then
    Exit;

  for Index := 1 to Length(Callsign) do
  begin
    Character := UpCase(Callsign[Index]);
    if not (Character in ['A'..'Z', '0'..'9', '/']) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

end.
