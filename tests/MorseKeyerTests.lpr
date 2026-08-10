program MorseKeyerTests;

{$mode delphi}{$H+}

uses
  SysUtils,
  Math,
  MorseKeyer;

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

procedure TestEncoding;
var
  Keyer: TMorseKeyer;
begin
  Keyer := TMorseKeyer.Create;
  try
    Check(Keyer.Encode('cq') = '-.-. --.-~', 'CQ encoding');
    Check(Keyer.Encode('A B') = '.-  -...~', 'word-space encoding');
    Check(Keyer.Encode('@') = '', 'unsupported character is omitted');
  finally
    Keyer.Free;
  end;
end;

procedure TestCqEnvelope;
var
  Keyer: TMorseKeyer;
  Envelope: TSingleSampleBlock;
begin
  Keyer := TMorseKeyer.Create(20, 11025, 512);
  try
    Envelope := Keyer.RenderMessage('CQ');
    CheckEquals(19347, Keyer.TrueEnvelopeFrames, 'CQ true envelope size');
    CheckEquals(19456, Length(Envelope), 'CQ block-padded envelope size');
    Check(Envelope[0] > 0, 'envelope begins with shaped attack');
    Check(Envelope[0] < 0.01, 'envelope attack is not a click');
    Check(Abs(Envelope[Length(Envelope) - 1]) < 0.000001,
      'block padding remains silent');
  finally
    Keyer.Free;
  end;
end;

procedure TestInvalidTimingIsRejected;
var
  Keyer: TMorseKeyer;
  DidRaise: Boolean;
begin
  Keyer := TMorseKeyer.Create;
  try
    DidRaise := False;
    try
      Keyer.Wpm := 0;
    except
      on EArgumentOutOfRangeException do
        DidRaise := True;
    end;
    Check(DidRaise, 'zero WPM rejected');

    Keyer.RiseTimeSeconds := 0.2;
    DidRaise := False;
    try
      Keyer.RenderMessage('E');
    except
      on EArgumentOutOfRangeException do
        DidRaise := True;
    end;
    Check(DidRaise, 'impossible rise time rejected');
  finally
    Keyer.Free;
  end;
end;

begin
  try
    TestEncoding;
    TestCqEnvelope;
    TestInvalidTimingIsRejected;
    WriteLn('Morse keyer tests passed.');
  except
    on Error: Exception do
    begin
      WriteLn(StdErr, 'Morse keyer tests failed: ', Error.Message);
      Halt(1);
    end;
  end;
end.
