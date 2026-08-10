program MorseToneRendererTests;

{$mode delphi}{$H+}

uses
  SysUtils,
  MorseToneRenderer;

type
  TSampleBlock4 = array[0..3] of Single;

procedure Check(const Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure CheckNear(const Expected, Actual, Tolerance: Single;
  const MessageText: string);
begin
  Check(Abs(Expected - Actual) <= Tolerance,
    Format('%s: expected %.6f, got %.6f', [MessageText, Expected, Actual]));
end;

procedure TestLegacyCarrierQuantization;
var
  Renderer: TMorseToneRenderer;
begin
  Renderer := TMorseToneRenderer.Create(11025, 600, 100);
  try
    CheckNear(612.5, Renderer.ActualCarrierHz, 0.001,
      'legacy carrier quantization');
  finally
    Renderer.Free;
  end;
end;

procedure TestEnvelopeRenderingAndPhaseContinuity;
var
  Renderer: TMorseToneRenderer;
  Envelope: TSampleBlock4;
  FirstOutput: TSampleBlock4;
  SecondOutput: TSampleBlock4;
begin
  Envelope[0] := 1;
  Envelope[1] := 1;
  Envelope[2] := 1;
  Envelope[3] := 1;

  Renderer := TMorseToneRenderer.Create(11025, 600, 100);
  try
    FirstOutput[0] := 0;
    FirstOutput[1] := 0;
    FirstOutput[2] := 0;
    FirstOutput[3] := 0;
    Renderer.RenderEnvelope(Envelope, FirstOutput);
    CheckNear(100, FirstOutput[0], 0.001, 'carrier begins at zero phase');
    CheckNear(100 * Cos(2 * Pi / 18), FirstOutput[1], 0.001,
      'second carrier sample');
    CheckNear(100 * Cos(6 * Pi / 18), FirstOutput[3], 0.001,
      'fourth carrier sample');

    SecondOutput[0] := 0;
    SecondOutput[1] := 0;
    SecondOutput[2] := 0;
    SecondOutput[3] := 0;
    Renderer.RenderEnvelope(Envelope, SecondOutput);
    CheckNear(100 * Cos(8 * Pi / 18), SecondOutput[0], 0.001,
      'phase continues across blocks');
  finally
    Renderer.Free;
  end;
end;

procedure TestInvalidParametersAndLengths;
var
  Renderer: TMorseToneRenderer;
  InputBlock: TSampleBlock4;
  ShortOutput: array[0..2] of Single;
  DidRaise: Boolean;
begin
  Renderer := TMorseToneRenderer.Create;
  try
    DidRaise := False;
    try
      Renderer.RequestedCarrierHz := 6000;
    except
      on EArgumentOutOfRangeException do
        DidRaise := True;
    end;
    Check(DidRaise, 'carrier above Nyquist rejected');

    DidRaise := False;
    try
      InputBlock[0] := 0;
      InputBlock[1] := 0;
      InputBlock[2] := 0;
      InputBlock[3] := 0;
      ShortOutput[0] := 0;
      ShortOutput[1] := 0;
      ShortOutput[2] := 0;
      Renderer.RenderEnvelope(InputBlock, ShortOutput);
    except
      on EArgumentException do
        DidRaise := True;
    end;
    Check(DidRaise, 'mismatched output size rejected');
  finally
    Renderer.Free;
  end;
end;

begin
  try
    TestLegacyCarrierQuantization;
    TestEnvelopeRenderingAndPhaseContinuity;
    TestInvalidParametersAndLengths;
    WriteLn('Morse tone renderer tests passed.');
  except
    on Error: Exception do
    begin
      WriteLn(StdErr, 'Morse tone renderer tests failed: ', Error.Message);
      Halt(1);
    end;
  end;
end.
