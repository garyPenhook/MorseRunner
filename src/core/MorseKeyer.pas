//------------------------------------------------------------------------------
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Derived from the legacy VCL/MorseKey.pas and VCL/MorseTbl.pas units. This
// core version deliberately has no Forms, Ini, sound-device, or global state.
//------------------------------------------------------------------------------
unit MorseKeyer;

{$mode delphi}{$H+}

interface

type
  TSingleSampleBlock = array of Single;

  TMorseKeyer = class
  private
    FEncoding: array[Char] of string;
    FRampOn: TSingleSampleBlock;
    FRampOff: TSingleSampleBlock;
    FRampLength: Integer;
    FWpm: Integer;
    FSampleRate: Integer;
    FBlockFrames: Integer;
    FRiseTimeSeconds: Single;
    FTrueEnvelopeFrames: Integer;
    procedure LoadMorseTable;
    procedure RebuildRamp;
    procedure SetWpm(const Value: Integer);
    procedure SetSampleRate(const Value: Integer);
    procedure SetBlockFrames(const Value: Integer);
    procedure SetRiseTimeSeconds(const Value: Single);
    function BlackmanHarrisKernel(const Position: Single): Single;
    function BlackmanHarrisStepResponse(const SampleCount: Integer): TSingleSampleBlock;
  public
    constructor Create(const AWpm: Integer = 20; const ASampleRate: Integer = 11025;
      const ABlockFrames: Integer = 512);
    function Encode(const Text: string): string;
    function BuildEnvelope(const EncodedMessage: string): TSingleSampleBlock;
    function RenderMessage(const Text: string): TSingleSampleBlock;

    property Wpm: Integer read FWpm write SetWpm;
    property SampleRate: Integer read FSampleRate write SetSampleRate;
    property BlockFrames: Integer read FBlockFrames write SetBlockFrames;
    property RiseTimeSeconds: Single read FRiseTimeSeconds write SetRiseTimeSeconds;
    property TrueEnvelopeFrames: Integer read FTrueEnvelopeFrames;
  end;

implementation

uses
  Math,
  SysUtils;

const
  { Single-character entries from the legacy MorseTable. Procedural entries
    such as "sk" and "cq" were not usable by the legacy char-indexed map and
    remain a later, explicit token-encoding concern. }
  LegacyMorseEntries: array[0..41] of string = (
    '1[.----]', '2[..---]', '3[...--]', '4[....-]', '5[.....]',
    '6[-....]', '7[--...]', '8[---..]', '9[----.]', '0[-----]',
    'A[.-]', 'B[-...]', 'C[-.-.]', 'D[-..]', 'E[.]', 'F[..-.]',
    'G[--.]', 'H[....]', 'I[..]', 'J[.---]', 'K[-.-]', 'L[.-..]',
    'M[--]', 'N[-.]', 'O[---]', 'P[.--.]', 'Q[--.-]', 'R[.-.]',
    'S[...]', 'T[-]', 'U[..-]', 'V[...-]', 'W[.--]', 'X[-..-]',
    'Y[-.--]', 'Z[--..]', '/[-..-.]', '.[.-.-.-]', ',[--..--]',
    '?[..--..]', '=[-...-]', '\[...-.]');

constructor TMorseKeyer.Create(const AWpm: Integer; const ASampleRate: Integer;
  const ABlockFrames: Integer);
begin
  inherited Create;
  LoadMorseTable;
  FWpm := 20;
  FSampleRate := 11025;
  FBlockFrames := 512;
  FRiseTimeSeconds := 0.005;
  Wpm := AWpm;
  SampleRate := ASampleRate;
  BlockFrames := ABlockFrames;
  RebuildRamp;
end;

procedure TMorseKeyer.LoadMorseTable;
var
  Index: Integer;
  Entry: string;
  Character: Char;
begin
  for Index := Low(LegacyMorseEntries) to High(LegacyMorseEntries) do
  begin
    Entry := LegacyMorseEntries[Index];
    Character := Entry[1];
    FEncoding[Character] := Copy(Entry, 3, Pos(']', Entry) - 3) + ' ';
  end;
end;

procedure TMorseKeyer.SetWpm(const Value: Integer);
begin
  if Value <= 0 then
    raise EArgumentOutOfRangeException.Create('Morse speed must be positive.');
  FWpm := Value;
end;

procedure TMorseKeyer.SetSampleRate(const Value: Integer);
begin
  if Value <= 0 then
    raise EArgumentOutOfRangeException.Create('Morse sample rate must be positive.');
  FSampleRate := Value;
  if FRiseTimeSeconds > 0 then
    RebuildRamp;
end;

procedure TMorseKeyer.SetBlockFrames(const Value: Integer);
begin
  if Value <= 0 then
    raise EArgumentOutOfRangeException.Create('Morse block size must be positive.');
  FBlockFrames := Value;
end;

procedure TMorseKeyer.SetRiseTimeSeconds(const Value: Single);
begin
  if Value <= 0 then
    raise EArgumentOutOfRangeException.Create('Morse rise time must be positive.');
  FRiseTimeSeconds := Value;
  if FSampleRate > 0 then
    RebuildRamp;
end;

function TMorseKeyer.BlackmanHarrisKernel(const Position: Single): Single;
const
  A0 = 0.35875;
  A1 = 0.48829;
  A2 = 0.14128;
  A3 = 0.01168;
begin
  Result := A0 - A1 * Cos(2 * Pi * Position) +
    A2 * Cos(4 * Pi * Position) - A3 * Cos(6 * Pi * Position);
end;

function TMorseKeyer.BlackmanHarrisStepResponse(
  const SampleCount: Integer): TSingleSampleBlock;
var
  Index: Integer;
  Scale: Single;
begin
  if SampleCount <= 0 then
    raise EArgumentOutOfRangeException.Create('Morse ramp size must be positive.');
  Result := nil;
  SetLength(Result, SampleCount);
  for Index := 0 to High(Result) do
    Result[Index] := BlackmanHarrisKernel(Index / SampleCount);
  for Index := 1 to High(Result) do
    Result[Index] := Result[Index - 1] + Result[Index];
  Scale := 1 / Result[High(Result)];
  for Index := 0 to High(Result) do
    Result[Index] := Result[Index] * Scale;
end;

procedure TMorseKeyer.RebuildRamp;
var
  Index: Integer;
begin
  FRampLength := Round(2.7 * FRiseTimeSeconds * FSampleRate);
  if FRampLength <= 0 then
    raise EArgumentOutOfRangeException.Create('Morse rise time produces no samples.');
  FRampOn := BlackmanHarrisStepResponse(FRampLength);
  SetLength(FRampOff, FRampLength);
  for Index := 0 to FRampLength - 1 do
    FRampOff[High(FRampOff) - Index] := FRampOn[Index];
end;

function TMorseKeyer.Encode(const Text: string): string;
var
  Index: Integer;
  Character: Char;
begin
  Result := '';
  for Index := 1 to Length(Text) do
  begin
    Character := UpCase(Text[Index]);
    if Character in [' ', '_'] then
      Result := Result + ' '
    else
      Result := Result + FEncoding[Character];
  end;
  if Result <> '' then
    Result[Length(Result)] := '~';
end;

function TMorseKeyer.BuildEnvelope(
  const EncodedMessage: string): TSingleSampleBlock;
var
  UnitCount: Integer;
  SampleFramesPerUnit: Integer;
  PaddedFrames: Integer;
  Index: Integer;
  Position: Integer;

  procedure AddRampOn;
  begin
    Move(FRampOn[0], Result[Position], FRampLength * SizeOf(Single));
    Inc(Position, FRampLength);
  end;

  procedure AddRampOff;
  begin
    Move(FRampOff[0], Result[Position], FRampLength * SizeOf(Single));
    Inc(Position, FRampLength);
  end;

  procedure AddOn(const DurationUnits: Integer);
  var
    SampleIndex: Integer;
    FrameCount: Integer;
  begin
    FrameCount := DurationUnits * SampleFramesPerUnit - FRampLength;
    for SampleIndex := 0 to FrameCount - 1 do
      Result[Position + SampleIndex] := 1;
    Inc(Position, FrameCount);
  end;

  procedure AddOff(const DurationUnits: Integer);
  begin
    Inc(Position, DurationUnits * SampleFramesPerUnit - FRampLength);
  end;

begin
  Result := nil;
  UnitCount := 0;
  for Index := 1 to Length(EncodedMessage) do
    case EncodedMessage[Index] of
      '.': Inc(UnitCount, 2);
      '-': Inc(UnitCount, 4);
      ' ': Inc(UnitCount, 2);
      '~': Inc(UnitCount, 1);
    end;

  SampleFramesPerUnit := Round(0.1 * FSampleRate * 12 / FWpm);
  if SampleFramesPerUnit <= FRampLength then
    raise EArgumentOutOfRangeException.Create(
      'Morse rise time is too long for the selected speed and sample rate.');

  FTrueEnvelopeFrames := UnitCount * SampleFramesPerUnit + FRampLength;
  PaddedFrames := FBlockFrames * Ceil(FTrueEnvelopeFrames / FBlockFrames);
  SetLength(Result, PaddedFrames);

  Position := 0;
  for Index := 1 to Length(EncodedMessage) do
    case EncodedMessage[Index] of
      '.': begin AddRampOn; AddOn(1); AddRampOff; AddOff(1); end;
      '-': begin AddRampOn; AddOn(3); AddRampOff; AddOff(1); end;
      ' ': AddOff(2);
      '~': AddOff(1);
    end;
end;

function TMorseKeyer.RenderMessage(const Text: string): TSingleSampleBlock;
begin
  Result := BuildEnvelope(Encode(Text));
end;

end.
