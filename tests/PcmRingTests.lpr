program PcmRingTests;

{$mode delphi}{$H+}

uses
  SysUtils,
  PcmRing;

type
  TBlock4 = array[0..3] of SmallInt;

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

procedure CheckBlock(const Expected, Actual: TBlock4; const MessageText: string);
var
  Index: Integer;
begin
  for Index := 0 to High(Expected) do
    CheckEquals(Expected[Index], Actual[Index],
      Format('%s at sample %d', [MessageText, Index]));
end;

procedure TestCapacityAndOrdering;
var
  Ring: TPcmSpscRing;
  FirstBlock: TBlock4;
  SecondBlock: TBlock4;
  ThirdBlock: TBlock4;
  OutputBlock: TBlock4;
begin
  FirstBlock[0] := 1;
  FirstBlock[1] := 2;
  FirstBlock[2] := 3;
  FirstBlock[3] := 4;
  SecondBlock[0] := 5;
  SecondBlock[1] := 6;
  SecondBlock[2] := 7;
  SecondBlock[3] := 8;
  ThirdBlock[0] := 9;
  ThirdBlock[1] := 10;
  ThirdBlock[2] := 11;
  ThirdBlock[3] := 12;

  Ring := TPcmSpscRing.Create(4, 2);
  try
    CheckEquals(4, Ring.BlockFrames, 'block size');
    CheckEquals(2, Ring.Capacity, 'logical capacity');
    CheckEquals(0, Ring.AvailableToRead, 'initial readable slots');
    CheckEquals(2, Ring.AvailableToWrite, 'initial writable slots');
    Check(Ring.TryWrite(FirstBlock), 'first block accepted');
    Check(Ring.TryWrite(SecondBlock), 'second block accepted');
    Check(not Ring.TryWrite(ThirdBlock), 'full ring rejects producer');
    CheckEquals(2, Ring.AvailableToRead, 'full readable slots');
    CheckEquals(0, Ring.AvailableToWrite, 'full writable slots');

    Check(Ring.TryRead(OutputBlock), 'first block consumed');
    CheckBlock(FirstBlock, OutputBlock, 'first block ordering');
    Check(Ring.TryWrite(ThirdBlock), 'released slot reused');
    Check(Ring.TryRead(OutputBlock), 'second block consumed');
    CheckBlock(SecondBlock, OutputBlock, 'second block ordering');
    Check(Ring.TryRead(OutputBlock), 'wrapped block consumed');
    CheckBlock(ThirdBlock, OutputBlock, 'wrapped block ordering');
    Check(not Ring.TryRead(OutputBlock), 'empty ring reports no data');
  finally
    Ring.Free;
  end;
end;

procedure TestUnderrunSilenceAndReset;
var
  Ring: TPcmSpscRing;
  InputBlock: TBlock4;
  OutputBlock: TBlock4;
begin
  InputBlock[0] := -1;
  InputBlock[1] := -2;
  InputBlock[2] := -3;
  InputBlock[3] := -4;
  OutputBlock[0] := 99;
  OutputBlock[1] := 99;
  OutputBlock[2] := 99;
  OutputBlock[3] := 99;

  Ring := TPcmSpscRing.Create(4, 2);
  try
    Ring.ReadOrSilence(OutputBlock);
    CheckEquals(0, OutputBlock[0], 'underrun silence first sample');
    CheckEquals(0, OutputBlock[3], 'underrun silence last sample');
    CheckEquals(1, Ring.UnderrunCount, 'underrun count');

    Check(Ring.TryWrite(InputBlock), 'input accepted before reset');
    Ring.Reset;
    CheckEquals(0, Ring.AvailableToRead, 'reset clears pending samples');
    CheckEquals(2, Ring.AvailableToWrite, 'reset frees all slots');
    CheckEquals(0, Ring.UnderrunCount, 'reset clears underrun count');
  finally
    Ring.Free;
  end;
end;

procedure TestRepeatedWrap;
var
  Ring: TPcmSpscRing;
  InputBlock: TBlock4;
  OutputBlock: TBlock4;
  Iteration: Integer;
begin
  Ring := TPcmSpscRing.Create(4, 2);
  try
    for Iteration := 1 to 32 do
    begin
      InputBlock[0] := Iteration;
      InputBlock[1] := Iteration + 1;
      InputBlock[2] := Iteration + 2;
      InputBlock[3] := Iteration + 3;
      Check(Ring.TryWrite(InputBlock), 'wrapped producer write');
      Check(Ring.TryRead(OutputBlock), 'wrapped consumer read');
      CheckBlock(InputBlock, OutputBlock, 'repeated wrap ordering');
    end;
  finally
    Ring.Free;
  end;
end;

begin
  try
    TestCapacityAndOrdering;
    TestUnderrunSilenceAndReset;
    TestRepeatedWrap;
    WriteLn('PCM ring tests passed.');
  except
    on Error: Exception do
    begin
      WriteLn(StdErr, 'PCM ring tests failed: ', Error.Message);
      Halt(1);
    end;
  end;
end.
