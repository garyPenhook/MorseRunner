//------------------------------------------------------------------------------
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//------------------------------------------------------------------------------
unit MorseAudioProducer;

{$mode delphi}{$H+}

interface

uses
  SysUtils,
  LegacyPcmProducer,
  MorseKeyer,
  MorseToneRenderer,
  PcmRing;

type
  EMorseAudioProducer = class(Exception);

  { Producer-side bridge from an encoded Morse message to the PCM SPSC ring.
    PrepareMessage and Reset are lifecycle/command operations. TryProduceNextBlock
    is called only by the single simulation producer; it never runs in the
    PortAudio callback. }
  TMorseAudioProducer = class
  private
    FRing: TPcmSpscRing;
    FKeyer: TMorseKeyer;
    FToneRenderer: TMorseToneRenderer;
    FPcmProducer: TLegacyPcmProducer;
    FEnvelope: TSingleSampleBlock;
    FEnvelopeBlock: TSingleSampleBlock;
    FRenderedBlock: TSingleSampleBlock;
    FFrameCursor: Integer;
    FSubmittedFrames: Int64;
    function GetHasPendingBlocks: Boolean;
    function GetPendingBlocks: Integer;
  public
    constructor Create(const Ring: TPcmSpscRing; const AWpm: Integer = 20;
      const ASampleRate: Integer = 11025; const ACarrierHz: Single = 600;
      const AAmplitude: Single = 6000);
    destructor Destroy; override;
    procedure PrepareMessage(const Text: string);
    procedure CancelMessage;
    procedure Reset;
    function TryProduceNextBlock: Boolean;

    property HasPendingBlocks: Boolean read GetHasPendingBlocks;
    property PendingBlocks: Integer read GetPendingBlocks;
    property SubmittedFrames: Int64 read FSubmittedFrames;
  end;

implementation

constructor TMorseAudioProducer.Create(const Ring: TPcmSpscRing;
  const AWpm: Integer; const ASampleRate: Integer; const ACarrierHz: Single;
  const AAmplitude: Single);
begin
  inherited Create;
  if Ring = nil then
    raise EArgumentNilException.Create('Morse audio producer requires a PCM ring.');
  if Ring.BlockFrames <= 0 then
    raise EArgumentOutOfRangeException.Create('PCM ring block size must be positive.');
  FRing := Ring;
  FKeyer := TMorseKeyer.Create(AWpm, ASampleRate, FRing.BlockFrames);
  FToneRenderer := TMorseToneRenderer.Create(ASampleRate, ACarrierHz, AAmplitude);
  FPcmProducer := TLegacyPcmProducer.Create(FRing);
  SetLength(FEnvelopeBlock, FRing.BlockFrames);
  SetLength(FRenderedBlock, FRing.BlockFrames);
end;

destructor TMorseAudioProducer.Destroy;
begin
  FPcmProducer.Free;
  FToneRenderer.Free;
  FKeyer.Free;
  inherited Destroy;
end;

procedure TMorseAudioProducer.PrepareMessage(const Text: string);
var
  EncodedMessage: string;
begin
  if HasPendingBlocks then
    raise EMorseAudioProducer.Create(
      'Cannot replace a Morse message while producer blocks remain pending.');
  EncodedMessage := FKeyer.Encode(Text);
  if EncodedMessage = '' then
    FEnvelope := nil
  else
    FEnvelope := FKeyer.BuildEnvelope(EncodedMessage);
  FFrameCursor := 0;
end;

procedure TMorseAudioProducer.CancelMessage;
begin
  FEnvelope := nil;
  FFrameCursor := 0;
end;

procedure TMorseAudioProducer.Reset;
begin
  CancelMessage;
  FToneRenderer.Reset;
  FSubmittedFrames := 0;
end;

function TMorseAudioProducer.GetHasPendingBlocks: Boolean;
begin
  Result := FFrameCursor < Length(FEnvelope);
end;

function TMorseAudioProducer.GetPendingBlocks: Integer;
begin
  Result := (Length(FEnvelope) - FFrameCursor) div FRing.BlockFrames;
end;

function TMorseAudioProducer.TryProduceNextBlock: Boolean;
begin
  Result := False;
  if not HasPendingBlocks then
    Exit;
  if FRing.AvailableToWrite = 0 then
    Exit;

  Move(FEnvelope[FFrameCursor], FEnvelopeBlock[0],
    FRing.BlockFrames * SizeOf(Single));
  FToneRenderer.RenderEnvelope(FEnvelopeBlock, FRenderedBlock);
  if not FPcmProducer.TrySubmit(FRenderedBlock) then
    raise EMorseAudioProducer.Create(
      'PCM ring became full while the single producer owned a writable slot.');

  Inc(FFrameCursor, FRing.BlockFrames);
  Inc(FSubmittedFrames, FRing.BlockFrames);
  Result := True;
end;

end.
