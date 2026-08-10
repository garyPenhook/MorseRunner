//------------------------------------------------------------------------------
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Derived from the TModulator behavior in VCL/Mixers.pas. This core version
// renders only the real CW carrier path and has no UI, device, or global state.
//------------------------------------------------------------------------------
unit MorseToneRenderer;

{$mode delphi}{$H+}

interface

type
  TMorseToneRenderer = class
  private
    FSampleRate: Integer;
    FRequestedCarrierHz: Single;
    FActualCarrierHz: Single;
    FAmplitude: Single;
    FCarrierSamples: array of Single;
    FCarrierIndex: Integer;
    procedure RebuildCarrier;
    procedure SetSampleRate(const Value: Integer);
    procedure SetCarrierHz(const Value: Single);
    procedure SetAmplitude(const Value: Single);
  public
    constructor Create(const ASampleRate: Integer = 11025;
      const ACarrierHz: Single = 600; const AAmplitude: Single = 6000);
    procedure Reset;
    procedure RenderEnvelope(const Envelope: array of Single;
      var Output: array of Single);

    property SampleRate: Integer read FSampleRate write SetSampleRate;
    property RequestedCarrierHz: Single read FRequestedCarrierHz write SetCarrierHz;
    property ActualCarrierHz: Single read FActualCarrierHz;
    property Amplitude: Single read FAmplitude write SetAmplitude;
  end;

implementation

uses
  SysUtils;

constructor TMorseToneRenderer.Create(const ASampleRate: Integer;
  const ACarrierHz: Single; const AAmplitude: Single);
begin
  inherited Create;
  if ASampleRate <= 0 then
    raise EArgumentOutOfRangeException.Create('Carrier sample rate must be positive.');
  FSampleRate := ASampleRate;
  FRequestedCarrierHz := ACarrierHz;
  FAmplitude := 0;
  RequestedCarrierHz := ACarrierHz;
  Amplitude := AAmplitude;
end;

procedure TMorseToneRenderer.SetSampleRate(const Value: Integer);
begin
  if Value <= 0 then
    raise EArgumentOutOfRangeException.Create('Carrier sample rate must be positive.');
  FSampleRate := Value;
  if FRequestedCarrierHz > 0 then
    RebuildCarrier;
end;

procedure TMorseToneRenderer.SetCarrierHz(const Value: Single);
begin
  if (Value <= 0) or (Value > FSampleRate / 2) then
    raise EArgumentOutOfRangeException.Create(
      'Carrier frequency must be positive and below Nyquist.');
  FRequestedCarrierHz := Value;
  RebuildCarrier;
end;

procedure TMorseToneRenderer.SetAmplitude(const Value: Single);
begin
  if Value < 0 then
    raise EArgumentOutOfRangeException.Create('Carrier amplitude cannot be negative.');
  FAmplitude := Value;
end;

procedure TMorseToneRenderer.RebuildCarrier;
var
  SampleCount: Integer;
  DeltaPhase: Single;
  Index: Integer;
begin
  SampleCount := Round(FSampleRate / FRequestedCarrierHz);
  if SampleCount < 2 then
    raise EArgumentOutOfRangeException.Create(
      'Carrier frequency produces fewer than two samples per cycle.');

  FActualCarrierHz := FSampleRate / SampleCount;
  DeltaPhase := 2 * Pi / SampleCount;
  SetLength(FCarrierSamples, SampleCount);
  for Index := 0 to SampleCount - 1 do
    FCarrierSamples[Index] := Cos(Index * DeltaPhase);
  Reset;
end;

procedure TMorseToneRenderer.Reset;
begin
  FCarrierIndex := 0;
end;

procedure TMorseToneRenderer.RenderEnvelope(const Envelope: array of Single;
  var Output: array of Single);
var
  Index: Integer;
begin
  if Length(Output) <> Length(Envelope) then
    raise EArgumentException.Create(
      'Carrier output size does not match envelope size.');

  for Index := 0 to High(Envelope) do
  begin
    Output[Index] := Envelope[Index] * FCarrierSamples[FCarrierIndex] * FAmplitude;
    Inc(FCarrierIndex);
    if FCarrierIndex = Length(FCarrierSamples) then
      FCarrierIndex := 0;
  end;
end;

end.
