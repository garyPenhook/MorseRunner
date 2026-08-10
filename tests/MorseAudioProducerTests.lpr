program MorseAudioProducerTests;

{$mode delphi}{$H+}

uses
  SysUtils,
  MorseAudioProducer,
  PcmRing;

type
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

procedure TestProducerResumesWhenRingHasSpace;
var
  Ring: TPcmSpscRing;
  Producer: TMorseAudioProducer;
  OutputBlock: TPcmBlock4;
begin
  Ring := TPcmSpscRing.Create(4, 2);
  Producer := TMorseAudioProducer.Create(Ring, 60, 800, 100, 32767);
  try
    Producer.PrepareMessage('E');
    CheckEquals(15, Producer.PendingBlocks, 'E message padded blocks');

    Check(Producer.TryProduceNextBlock, 'first block submitted');
    Check(Producer.TryProduceNextBlock, 'second block submitted');
    Check(not Producer.TryProduceNextBlock, 'full ring pauses producer');
    CheckEquals(13, Producer.PendingBlocks, 'paused blocks remain pending');
    CheckEquals(8, Producer.SubmittedFrames, 'submitted frame count');

    OutputBlock[0] := 0;
    OutputBlock[1] := 0;
    OutputBlock[2] := 0;
    OutputBlock[3] := 0;
    Check(Ring.TryRead(OutputBlock), 'consumer releases a slot');
    Check(Producer.TryProduceNextBlock, 'producer resumes after consumer read');
    CheckEquals(12, Producer.PendingBlocks, 'resumed producer advances once');
    CheckEquals(12, Producer.SubmittedFrames, 'resumed submitted frame count');
  finally
    Producer.Free;
    Ring.Free;
  end;
end;

procedure TestMessagesAreSerializedAndResettable;
var
  Ring: TPcmSpscRing;
  Producer: TMorseAudioProducer;
  DidRaise: Boolean;
begin
  Ring := TPcmSpscRing.Create(4, 2);
  Producer := TMorseAudioProducer.Create(Ring, 60, 800, 100, 100);
  try
    Producer.PrepareMessage('E');
    DidRaise := False;
    try
      Producer.PrepareMessage('T');
    except
      on EMorseAudioProducer do
        DidRaise := True;
    end;
    Check(DidRaise, 'pending message cannot be replaced');

    Producer.CancelMessage;
    Check(not Producer.HasPendingBlocks, 'cancel clears message');
    Producer.PrepareMessage('@');
    Check(not Producer.HasPendingBlocks, 'unsupported message produces no blocks');

    Producer.Reset;
    CheckEquals(0, Producer.SubmittedFrames, 'reset clears submitted frame count');
  finally
    Producer.Free;
    Ring.Free;
  end;
end;

begin
  try
    TestProducerResumesWhenRingHasSpace;
    TestMessagesAreSerializedAndResettable;
    WriteLn('Morse audio producer tests passed.');
  except
    on Error: Exception do
    begin
      WriteLn(StdErr, 'Morse audio producer tests failed: ', Error.Message);
      Halt(1);
    end;
  end;
end.
