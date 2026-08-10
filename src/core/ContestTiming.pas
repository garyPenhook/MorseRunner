//------------------------------------------------------------------------------
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit ContestTiming;

{$mode delphi}{$H+}

interface

uses
  ContestSettings;

function SecondsToBlocks(const Settings: TContestSettings;
  Seconds: Double): Integer;
function BlocksToSeconds(const Settings: TContestSettings;
  Blocks: Int64): Double;
function FramesToSeconds(const Settings: TContestSettings;
  Frames: Int64): Double;
function SessionDurationSeconds(const Settings: TContestSettings): Double;
function IsSessionFinished(const Settings: TContestSettings;
  ConsumedFrames: Int64): Boolean;

implementation

uses
  Math;

function SecondsToBlocks(const Settings: TContestSettings;
  Seconds: Double): Integer;
begin
  if (Settings.Audio.SampleRate <= 0) or
    (Settings.Audio.FramesPerBlock <= 0) then
  begin
    Result := 0;
    Exit;
  end;

  Result := Round(Settings.Audio.SampleRate /
    Settings.Audio.FramesPerBlock * Seconds);
end;

function BlocksToSeconds(const Settings: TContestSettings;
  Blocks: Int64): Double;
begin
  if Settings.Audio.SampleRate <= 0 then
  begin
    Result := 0.0;
    Exit;
  end;

  Result := Blocks * Settings.Audio.FramesPerBlock /
    Settings.Audio.SampleRate;
end;

function FramesToSeconds(const Settings: TContestSettings;
  Frames: Int64): Double;
begin
  if Settings.Audio.SampleRate <= 0 then
  begin
    Result := 0.0;
    Exit;
  end;

  Result := Frames / Settings.Audio.SampleRate;
end;

function SessionDurationSeconds(const Settings: TContestSettings): Double;
begin
  case Settings.RunMode of
    rmWpx, rmHst:
      Result := Settings.CompetitionDurationMinutes * 60.0;
  else
    Result := Settings.DurationMinutes * 60.0;
  end;
end;

function IsSessionFinished(const Settings: TContestSettings;
  ConsumedFrames: Int64): Boolean;
begin
  Result := FramesToSeconds(Settings, ConsumedFrames) >=
    SessionDurationSeconds(Settings);
end;

end.
