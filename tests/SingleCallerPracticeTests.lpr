program SingleCallerPracticeTests;

{$mode delphi}{$H+}

uses
  SysUtils,
  QsoLog,
  SingleCallerPractice;

procedure Check(const Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure TestCompleteExchange;
var
  Practice: TSingleCallerPractice;
  ReplyText: string;
  Qso: TQso;
begin
  Practice := TSingleCallerPractice.Create('k1abc', 7);
  try
    Check(Practice.Start = 'DE K1ABC K1ABC', 'caller sends its call');
    Check(Practice.State = scsAwaitingExchange, 'caller awaits exchange');

    Check(Practice.ReceiveOperatorText('CQ TEST', ReplyText, Qso),
      'caller responds to an invalid exchange');
    Check(ReplyText = 'AGN', 'invalid exchange requests repeat');
    Check(Practice.State = scsAwaitingExchange, 'repeat preserves exchange state');

    Check(Practice.ReceiveOperatorText('k1abc 599007', ReplyText, Qso),
      'caller accepts a sent exchange');
    Check(ReplyText = 'R 599007', 'caller acknowledges exchange');
    Check(Practice.State = scsAwaitingSignoff, 'caller awaits signoff');
    Check(Qso.TrueCall = '', 'no QSO before signoff');

    Check(Practice.ReceiveOperatorText('TNX TU', ReplyText, Qso),
      'caller accepts signoff');
    Check(ReplyText = 'TU K1ABC', 'caller completes QSO');
    Check(Practice.State = scsComplete, 'caller completes once');
    Check((Qso.Call = 'K1ABC') and (Qso.TrueCall = 'K1ABC'),
      'completed QSO identifies the database caller');
    Check((Qso.Rst = 599) and (Qso.TrueRst = 599) and
      (Qso.Nr = 7) and (Qso.TrueNr = 7), 'completed QSO exchange');
    Check(not Practice.ReceiveOperatorText('TU', ReplyText, Qso),
      'completed caller does not log another QSO');
  finally
    Practice.Free;
  end;
end;

begin
  try
    TestCompleteExchange;
    WriteLn('Single caller practice tests passed.');
  except
    on Error: Exception do
    begin
      WriteLn(StdErr, 'Single caller practice tests failed: ', Error.Message);
      Halt(1);
    end;
  end;
end.
