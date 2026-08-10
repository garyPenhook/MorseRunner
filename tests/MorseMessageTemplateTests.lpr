program MorseMessageTemplateTests;

{$mode delphi}{$H+}

uses
  SysUtils,
  MorseMessageTemplate;

procedure Check(const Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure TestCqTemplate;
begin
  Check(ExpandMorseMessageTemplate('CQ <my> TEST', 'VE3NEA', '', 599, 1) =
    'CQ VE3NEA TEST', 'CQ call substitution');
end;

procedure TestRepeatedAndMixedPlaceholders;
begin
  Check(ExpandMorseMessageTemplate(
    'DE <my> <my> <his> <#> <#>', 'VE3NEA', 'K1ABC', 599, 7) =
    'DE VE3NEA VE3NEA K1ABC 599007 599007',
    'all placeholders are substituted');
end;

procedure TestInvalidExchangeIsRejected;
var
  DidRaise: Boolean;
begin
  DidRaise := False;
  try
    ExpandMorseMessageTemplate('<#>', 'VE3NEA', '', -1, 1);
  except
    on EArgumentOutOfRangeException do
      DidRaise := True;
  end;
  Check(DidRaise, 'negative RST rejected');
end;

begin
  try
    TestCqTemplate;
    TestRepeatedAndMixedPlaceholders;
    TestInvalidExchangeIsRejected;
    WriteLn('Morse message template tests passed.');
  except
    on Error: Exception do
    begin
      WriteLn(StdErr, 'Morse message template tests failed: ', Error.Message);
      Halt(1);
    end;
  end;
end.
