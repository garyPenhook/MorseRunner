program PortAudioOutputTests;

{$mode delphi}{$H+}

uses
  SysUtils,
  ContestSettings,
  ContestSession,
  PcmRing,
  PortAudioApi,
  PortAudioOutput;

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

procedure TestPortAudioLibraryMetadata;
begin
  Check(Pa_GetVersion > 0, 'PortAudio version is available without initialization');
  Check(Pa_GetVersionText <> nil, 'PortAudio version text is available');
end;

procedure TestCallbackReadsRing;
var
  Ring: TPcmSpscRing;
  Output: TPortAudioOutput;
  InputBlock: TBlock4;
  OutputBlock: TBlock4;
begin
  InputBlock[0] := -100;
  InputBlock[1] := -50;
  InputBlock[2] := 50;
  InputBlock[3] := 100;

  Ring := TPcmSpscRing.Create(4, 2);
  Output := TPortAudioOutput.Create(Ring);
  try
    Check(Ring.TryWrite(InputBlock), 'ring accepts callback input');
    Output.FillCallbackBuffer(@OutputBlock[0], 4);
    CheckBlock(InputBlock, OutputBlock, 'callback copies queued PCM');
    CheckEquals(4, Output.PlayedFrames, 'callback reports played frames');
    CheckEquals(4, Output.TakePlayedFrames, 'controller drains played frames');
    CheckEquals(0, Output.TakePlayedFrames, 'drained frames are not repeated');

    OutputBlock[0] := 1;
    OutputBlock[1] := 1;
    OutputBlock[2] := 1;
    OutputBlock[3] := 1;
    Output.FillCallbackBuffer(@OutputBlock[0], 4);
    CheckEquals(0, OutputBlock[0], 'callback underrun emits silence');
    CheckEquals(0, OutputBlock[3], 'callback underrun clears full block');
    CheckEquals(1, Ring.UnderrunCount, 'callback underrun tracked');
    CheckEquals(8, Output.PlayedFrames, 'underrun silence still advances playback');
    CheckEquals(4, Output.TakePlayedFrames, 'underrun frames are reported once');
  finally
    Output.Free;
    Ring.Free;
  end;
end;

procedure TestControllerAppliesPlayedFramesToSession;
var
  Settings: TContestSettings;
  Session: TContestSession;
  Ring: TPcmSpscRing;
  Output: TPortAudioOutput;
  InputBlock: TBlock4;
  OutputBlock: TBlock4;
begin
  InputBlock[0] := 1;
  InputBlock[1] := 1;
  InputBlock[2] := 1;
  InputBlock[3] := 1;
  Settings := DefaultContestSettings;
  Settings.Audio.SampleRate := 4;
  Session := TContestSession.Create(Settings);
  Ring := TPcmSpscRing.Create(4, 2);
  Output := TPortAudioOutput.Create(Ring);
  try
    Session.Start(rmPileup);
    Check(Ring.TryWrite(InputBlock), 'clock test input queued');
    Output.FillCallbackBuffer(@OutputBlock[0], 4);
    Session.ConsumeFrames(Output.TakePlayedFrames);
    CheckEquals(4, Session.ConsumedFrames,
      'controller advances session only from callback-reported frames');
  finally
    Output.Free;
    Ring.Free;
    Session.Free;
  end;
end;

procedure TestCallbackRejectsUnexpectedFrameSize;
var
  Ring: TPcmSpscRing;
  Output: TPortAudioOutput;
  OutputBlock: TBlock4;
begin
  OutputBlock[0] := 1;
  OutputBlock[1] := 1;
  OutputBlock[2] := 1;
  OutputBlock[3] := 1;
  Ring := TPcmSpscRing.Create(4, 2);
  Output := TPortAudioOutput.Create(Ring);
  try
    Output.FillCallbackBuffer(@OutputBlock[0], 3);
    CheckEquals(0, OutputBlock[0], 'mismatched callback clears output');
    CheckEquals(0, OutputBlock[2], 'mismatched callback clears requested output');
    CheckEquals(1, Output.CallbackFormatErrors,
      'mismatched callback is recorded');
  finally
    Output.Free;
    Ring.Free;
  end;
end;

begin
  try
    TestPortAudioLibraryMetadata;
    TestCallbackReadsRing;
    TestCallbackRejectsUnexpectedFrameSize;
    TestControllerAppliesPlayedFramesToSession;
    WriteLn('PortAudio output tests passed.');
  except
    on Error: Exception do
    begin
      WriteLn(StdErr, 'PortAudio output tests failed: ', Error.Message);
      Halt(1);
    end;
  end;
end.
