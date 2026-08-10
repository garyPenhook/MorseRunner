unit LegacyPcmProducer;

{$mode delphi}{$H+}

interface

uses
  SysUtils,
  PcmRing;

type
  ELegacyPcmProducer = class(Exception);

  { Bridges the legacy renderer's Single sample convention to the native
    output ring. The original Windows TAlSoundOut implementation rounds then
    clamps each sample to the signed-16-bit range -32767..32767. Keeping that
    convention here avoids silently changing the existing DSP gain scale. }
  TLegacyPcmProducer = class
  private
    FRing: TPcmSpscRing;
    FScratch: TSmallIntBlock;
    function GetBlockFrames: Integer;
  public
    constructor Create(const Ring: TPcmSpscRing);
    function TrySubmit(const LegacySamples: array of Single): Boolean;

    property BlockFrames: Integer read GetBlockFrames;
  end;

function LegacySampleToPcm16(const Sample: Single): SmallInt;

implementation

uses
  Math;

function LegacySampleToPcm16(const Sample: Single): SmallInt;
var
  RoundedSample: Integer;
begin
  RoundedSample := Round(Sample);
  Result := SmallInt(Max(-32767, Min(32767, RoundedSample)));
end;

constructor TLegacyPcmProducer.Create(const Ring: TPcmSpscRing);
begin
  inherited Create;
  if Ring = nil then
    raise EArgumentNilException.Create('PCM producer requires a PCM ring.');
  FRing := Ring;
  SetLength(FScratch, FRing.BlockFrames);
end;

function TLegacyPcmProducer.GetBlockFrames: Integer;
begin
  Result := FRing.BlockFrames;
end;

function TLegacyPcmProducer.TrySubmit(
  const LegacySamples: array of Single): Boolean;
var
  Index: Integer;
begin
  if Length(LegacySamples) <> FRing.BlockFrames then
    raise EArgumentException.Create(
      'Legacy PCM block size does not match ring block size.');

  for Index := 0 to FRing.BlockFrames - 1 do
    FScratch[Index] := LegacySampleToPcm16(LegacySamples[Index]);
  Result := FRing.TryWrite(FScratch);
end;

end.
