program LegacyPcmProducerTests;

{$mode delphi}{$H+}

uses
  SysUtils,
  LegacyPcmProducer,
  PcmRing;

type
  TLegacyBlock4 = array[0..3] of Single;
  TPcmBlock4 = array[0..3] of SmallInt;

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

procedure CheckBlock(const Expected, Actual: TPcmBlock4;
  const MessageText: string);
var
  Index: Integer;
begin
  for Index := 0 to High(Expected) do
    CheckEquals(Expected[Index], Actual[Index],
      Format('%s at sample %d', [MessageText, Index]));
end;

procedure TestLegacySampleConversion;
begin
  CheckEquals(-32767, LegacySampleToPcm16(-50000), 'negative clip');
  CheckEquals(-2, LegacySampleToPcm16(-1.6), 'negative rounding');
  CheckEquals(0, LegacySampleToPcm16(0), 'silence');
  CheckEquals(2, LegacySampleToPcm16(1.6), 'positive rounding');
  CheckEquals(32767, LegacySampleToPcm16(50000), 'positive clip');
end;

procedure TestProducerConvertsAndQueuesBlock;
var
  Ring: TPcmSpscRing;
  Producer: TLegacyPcmProducer;
  InputBlock: TLegacyBlock4;
  ExpectedBlock: TPcmBlock4;
  OutputBlock: TPcmBlock4;
begin
  InputBlock[0] := -50000;
  InputBlock[1] := -1.6;
  InputBlock[2] := 1.6;
  InputBlock[3] := 50000;
  ExpectedBlock[0] := -32767;
  ExpectedBlock[1] := -2;
  ExpectedBlock[2] := 2;
  ExpectedBlock[3] := 32767;

  Ring := TPcmSpscRing.Create(4, 2);
  Producer := TLegacyPcmProducer.Create(Ring);
  try
    CheckEquals(4, Producer.BlockFrames, 'producer block size');
    Check(Producer.TrySubmit(InputBlock), 'producer queues converted block');
    OutputBlock[0] := 0;
    OutputBlock[1] := 0;
    OutputBlock[2] := 0;
    OutputBlock[3] := 0;
    Check(Ring.TryRead(OutputBlock), 'consumer receives converted block');
    CheckBlock(ExpectedBlock, OutputBlock, 'legacy sample conversion');
  finally
    Producer.Free;
    Ring.Free;
  end;
end;

procedure TestProducerRejectsWrongBlockSize;
var
  Ring: TPcmSpscRing;
  Producer: TLegacyPcmProducer;
  WrongSize: array[0..2] of Single;
  DidRaise: Boolean;
begin
  WrongSize[0] := 0;
  WrongSize[1] := 0;
  WrongSize[2] := 0;
  Ring := TPcmSpscRing.Create(4, 2);
  Producer := TLegacyPcmProducer.Create(Ring);
  try
    DidRaise := False;
    try
      Producer.TrySubmit(WrongSize);
    except
      on EArgumentException do
        DidRaise := True;
    end;
    Check(DidRaise, 'wrong producer block size is rejected');
  finally
    Producer.Free;
    Ring.Free;
  end;
end;

begin
  try
    TestLegacySampleConversion;
    TestProducerConvertsAndQueuesBlock;
    TestProducerRejectsWrongBlockSize;
    WriteLn('Legacy PCM producer tests passed.');
  except
    on Error: Exception do
    begin
      WriteLn(StdErr, 'Legacy PCM producer tests failed: ', Error.Message);
      Halt(1);
    end;
  end;
end.
