program PortAudioDeviceSmokeTests;

{$mode delphi}{$H+}

uses
  SysUtils,
  PcmRing,
  PortAudioOutput;

type
  TSilentBlock = array[0..511] of SmallInt;

procedure Check(const Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure TestDefaultOutputDevice;
var
  Ring: TPcmSpscRing;
  Output: TPortAudioOutput;
  SilentBlock: TSilentBlock;
  BlockIndex: Integer;
begin
  FillChar(SilentBlock, SizeOf(SilentBlock), 0);
  Ring := TPcmSpscRing.Create(512, 4);
  Output := TPortAudioOutput.Create(Ring);
  try
    for BlockIndex := 1 to Ring.Capacity do
      Check(Ring.TryWrite(SilentBlock), 'prefill accepts silent block');

    Output.Open(11025);
    Output.Start;
    Sleep(350);
    Output.Stop;

    Check(Output.PlayedFrames > 0,
      'default device callback reports at least one playback block');
    Check(Output.CallbackFormatErrors = 0,
      'default device honored the requested callback block size');
  finally
    Output.Free;
    Ring.Free;
  end;
end;

begin
  try
    TestDefaultOutputDevice;
    WriteLn('PortAudio device smoke test passed.');
  except
    on Error: Exception do
    begin
      WriteLn(StdErr, 'PortAudio device smoke test failed: ', Error.Message);
      Halt(1);
    end;
  end;
end.
