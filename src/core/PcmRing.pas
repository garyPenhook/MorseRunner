unit PcmRing;

{$mode delphi}{$H+}

interface

type
  TSmallIntBlock = array of SmallInt;

  TPcmSpscRing = class
  private
    FBlockFrames: Integer;
    FCapacity: Integer;
    FSlotCount: Integer;
    FSlots: array of TSmallIntBlock;
    FReadIndex: LongInt;
    FWriteIndex: LongInt;
    FUnderrunCount: LongInt;
    function NextIndex(const Index: LongInt): LongInt; inline;
    function AtomicRead(var Value: LongInt): LongInt; inline;
    procedure AtomicWrite(var Target: LongInt; const Value: LongInt); inline;
  public
    constructor Create(const BlockFrames, Capacity: Integer);
    procedure Reset;
    function TryWrite(const Samples: array of SmallInt): Boolean;
    function TryRead(var Samples: array of SmallInt): Boolean;
    procedure ReadOrSilence(var Samples: array of SmallInt);
    function AvailableToRead: Integer;
    function AvailableToWrite: Integer;

    property BlockFrames: Integer read FBlockFrames;
    property Capacity: Integer read FCapacity;
    property UnderrunCount: LongInt read FUnderrunCount;
  end;

implementation

uses
  SysUtils;

constructor TPcmSpscRing.Create(const BlockFrames, Capacity: Integer);
var
  Index: Integer;
begin
  inherited Create;
  if BlockFrames <= 0 then
    raise EArgumentOutOfRangeException.Create('PCM block size must be positive.');
  if Capacity < 2 then
    raise EArgumentOutOfRangeException.Create(
      'PCM ring capacity must contain at least two blocks.');

  FBlockFrames := BlockFrames;
  FCapacity := Capacity;
  FSlotCount := Capacity + 1;
  SetLength(FSlots, FSlotCount);
  for Index := 0 to FSlotCount - 1 do
    SetLength(FSlots[Index], FBlockFrames);
  Reset;
end;

function TPcmSpscRing.NextIndex(const Index: LongInt): LongInt;
begin
  Result := Index + 1;
  if Result = FSlotCount then
    Result := 0;
end;

function TPcmSpscRing.AtomicRead(var Value: LongInt): LongInt;
begin
  Result := InterlockedCompareExchange(Value, 0, 0);
end;

procedure TPcmSpscRing.AtomicWrite(var Target: LongInt; const Value: LongInt);
begin
  InterlockedExchange(Target, Value);
end;

procedure TPcmSpscRing.Reset;
begin
  { Reset is a lifecycle operation. Call it only after producer and consumer
    have both stopped; it intentionally performs no locking. }
  AtomicWrite(FReadIndex, 0);
  AtomicWrite(FWriteIndex, 0);
  AtomicWrite(FUnderrunCount, 0);
end;

function TPcmSpscRing.TryWrite(const Samples: array of SmallInt): Boolean;
var
  WriteIndex: LongInt;
  NextWriteIndex: LongInt;
  ReadIndex: LongInt;
begin
  if Length(Samples) <> FBlockFrames then
    raise EArgumentException.Create('PCM write size does not match ring block size.');

  WriteIndex := FWriteIndex;
  NextWriteIndex := NextIndex(WriteIndex);
  ReadIndex := AtomicRead(FReadIndex);
  Result := NextWriteIndex <> ReadIndex;
  if not Result then
    Exit;

  Move(Samples[0], FSlots[WriteIndex][0], FBlockFrames * SizeOf(SmallInt));
  { Publish only after every sample is in the slot. InterlockedExchange is the
    release boundary observed by the PortAudio callback. }
  AtomicWrite(FWriteIndex, NextWriteIndex);
end;

function TPcmSpscRing.TryRead(var Samples: array of SmallInt): Boolean;
var
  ReadIndex: LongInt;
  WriteIndex: LongInt;
begin
  if Length(Samples) <> FBlockFrames then
    raise EArgumentException.Create('PCM read size does not match ring block size.');

  ReadIndex := FReadIndex;
  WriteIndex := AtomicRead(FWriteIndex);
  Result := ReadIndex <> WriteIndex;
  if not Result then
    Exit;

  Move(FSlots[ReadIndex][0], Samples[0], FBlockFrames * SizeOf(SmallInt));
  { Release the slot only after its data has been copied. }
  AtomicWrite(FReadIndex, NextIndex(ReadIndex));
end;

procedure TPcmSpscRing.ReadOrSilence(var Samples: array of SmallInt);
var
  Index: Integer;
begin
  if TryRead(Samples) then
    Exit;

  for Index := 0 to High(Samples) do
    Samples[Index] := 0;
  InterlockedIncrement(FUnderrunCount);
end;

function TPcmSpscRing.AvailableToRead: Integer;
var
  ReadIndex: LongInt;
  WriteIndex: LongInt;
begin
  ReadIndex := FReadIndex;
  WriteIndex := AtomicRead(FWriteIndex);
  Result := WriteIndex - ReadIndex;
  if Result < 0 then
    Inc(Result, FSlotCount);
end;

function TPcmSpscRing.AvailableToWrite: Integer;
var
  ReadIndex: LongInt;
  WriteIndex: LongInt;
begin
  ReadIndex := AtomicRead(FReadIndex);
  WriteIndex := FWriteIndex;
  Result := ReadIndex - WriteIndex - 1;
  if Result < 0 then
    Inc(Result, FSlotCount);
end;

end.
